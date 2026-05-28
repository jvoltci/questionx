"""
Candidate B: Static embeddings (model2vec-style).

Approach:
  1. Use a pretrained static distilled model (minishlab/M2V_base_output) to
     get one vector per vocabulary token. No transformer at inference time.
  2. Build a syllabus-essential vocabulary from NCERT chunks + corpus-side Qs
     (top-N by frequency, capped at --vocab).
  3. For each chunk: encode = mean of token vectors. Store int8-quantized.
  4. For each eval Q: encode Q + each option similarly; pick option whose
     vector (concat with Q) has highest cosine with mean(top-k retrieved chunks).

Inference is pure lookup + dot product — directly portable to Dart.

Size budget for 2.0MB tier:
  vocab (8000) × dim (256) × int8 = 2.0 MB
  + chunk index = vocab×dim minus, chunks stored as int8 mean vectors (small)
"""

import argparse
import json
import re
from collections import Counter
from pathlib import Path

import numpy as np

HERE = Path(__file__).resolve().parent
EVAL_DIR = HERE.parent / "eval"
RESULTS_DIR = HERE.parent / "results"
RESULTS_DIR.mkdir(exist_ok=True)

WORD_RE = re.compile(r"[a-z0-9]+")
LATEX_CMD_RE = re.compile(r"\\[a-zA-Z]+")
LATEX_DELIM_RE = re.compile(r"[\\${}^_]")


def tokenize(text: str) -> list[str]:
    if not text:
        return []
    text = LATEX_CMD_RE.sub(" ", text)
    text = LATEX_DELIM_RE.sub(" ", text)
    text = text.lower()
    return [t for t in WORD_RE.findall(text) if len(t) > 1]


def build_vocab(chunks: list[str], corpus_qs: list[dict], cap: int) -> list[str]:
    """Frequency-rank tokens, drop singletons, return top-cap."""
    df = Counter()
    for c in chunks:
        df.update(set(tokenize(c)))
    for q in corpus_qs:
        toks = set(tokenize(q.get("question_latex", "")))
        for o in q.get("options", []):
            toks.update(tokenize(o))
        df.update(toks)
    return [t for t, c in df.most_common(cap) if c >= 2]


def load_static_model(model_path: str | None) -> tuple[dict[str, int], np.ndarray]:
    """Load a model2vec static model. If unavailable, fall back to random init
    (the random fallback is only for smoke-testing pipeline plumbing — not for
    real eval numbers)."""
    if model_path:
        try:
            from model2vec import StaticModel  # type: ignore
            sm = StaticModel.from_pretrained(model_path)
            embeddings = sm.embedding
            tokenizer = sm.tokenizer
            vocab = tokenizer.get_vocab() if hasattr(tokenizer, "get_vocab") else {}
            return vocab, np.asarray(embeddings, dtype=np.float32)
        except Exception as e:
            print(f"  warn: model2vec load failed ({e}); using random init")
    # random fallback — clearly flagged
    rng = np.random.default_rng(0)
    dim = 256
    print("  !! random-init embeddings — for plumbing test only !!")
    return {}, rng.standard_normal((30000, dim), dtype=np.float32)


def embed_text(tokens: list[str], vocab_idx: dict[str, int], emb: np.ndarray) -> np.ndarray:
    """Mean-pool token vectors. Missing tokens skipped."""
    vecs = [emb[vocab_idx[t]] for t in tokens if t in vocab_idx]
    if not vecs:
        return np.zeros(emb.shape[1], dtype=np.float32)
    v = np.mean(vecs, axis=0)
    n = np.linalg.norm(v)
    return v / n if n > 0 else v


def evaluate(
    chunks: list[str],
    chunk_vecs: np.ndarray,
    vocab_idx: dict[str, int],
    emb: np.ndarray,
    holdout: list[dict],
    k_retrieve: int = 3,
) -> dict:
    from collections import defaultdict
    correct = 0
    correct_by_subject = defaultdict(lambda: [0, 0])
    correct_by_bucket = defaultdict(lambda: [0, 0])
    per_q = []

    for q in holdout:
        q_toks = tokenize(q["question_latex"])
        q_vec = embed_text(q_toks, vocab_idx, emb)
        sims = chunk_vecs @ q_vec
        top = np.argpartition(-sims, min(k_retrieve, len(sims)-1))[:k_retrieve]
        ctx_vec = chunk_vecs[top].mean(axis=0)
        ctx_norm = np.linalg.norm(ctx_vec)
        if ctx_norm > 0:
            ctx_vec = ctx_vec / ctx_norm

        option_scores = []
        for opt in q["options"]:
            o_toks = tokenize(opt) + q_toks
            o_vec = embed_text(o_toks, vocab_idx, emb)
            option_scores.append(float(o_vec @ ctx_vec))

        pred_idx = int(np.argmax(option_scores))
        pred_letter = "ABCD"[pred_idx]
        gold = q["answer_key"]
        is_correct = pred_letter == gold

        subj = q["subject"]
        year = q["year"]
        bucket = ("ntaA_2015_2019" if year <= 2019
                  else "ntaB_2020_2022" if year <= 2022
                  else "ntaC_2023_2025")
        correct_by_subject[subj][1] += 1
        correct_by_bucket[bucket][1] += 1
        if is_correct:
            correct += 1
            correct_by_subject[subj][0] += 1
            correct_by_bucket[bucket][0] += 1

        per_q.append({"id": q["id"], "subject": subj, "year": year,
                      "gold": gold, "pred": pred_letter, "correct": is_correct,
                      "option_scores": option_scores, "retrieved": [int(t) for t in top]})

    return {
        "top1": correct / len(holdout),
        "n": len(holdout),
        "by_subject": {k: {"correct": v[0], "total": v[1], "acc": v[0]/v[1] if v[1] else 0.0}
                       for k, v in correct_by_subject.items()},
        "by_bucket": {k: {"correct": v[0], "total": v[1], "acc": v[0]/v[1] if v[1] else 0.0}
                      for k, v in correct_by_bucket.items()},
        "per_q": per_q,
    }


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--chunks", default=str(HERE.parent / "ncert" / "chunks.json"))
    ap.add_argument("--model", default="minishlab/M2V_base_output",
                    help="model2vec checkpoint name or local path")
    ap.add_argument("--vocab", type=int, default=8_000)
    ap.add_argument("--dim", type=int, default=256)
    ap.add_argument("--tier-label", default="2.0MB")
    args = ap.parse_args()

    chunks_data = json.loads(Path(args.chunks).read_text())
    chunks = chunks_data["chunks"]
    print(f"chunks: {len(chunks)}")

    corpus_side = json.loads((EVAL_DIR / "corpus_side.json").read_text())
    holdout = json.loads((EVAL_DIR / "holdout_500.json").read_text())

    # Build syllabus-essential vocab
    syllabus_vocab = build_vocab(chunks, corpus_side, cap=args.vocab)
    print(f"syllabus vocab: {len(syllabus_vocab)}")

    # Load static model
    model_vocab, full_emb = load_static_model(args.model)

    # Map syllabus vocab -> embedding rows
    vocab_idx: dict[str, int] = {}
    emb_rows: list[np.ndarray] = []
    hit = 0
    for tok in syllabus_vocab:
        if tok in model_vocab:
            vocab_idx[tok] = len(emb_rows)
            emb_rows.append(full_emb[model_vocab[tok]])
            hit += 1
    print(f"model vocab hit: {hit}/{len(syllabus_vocab)} ({100*hit/max(len(syllabus_vocab),1):.1f}%)")

    if not emb_rows:
        print("!! zero model-vocab hits — falling back to hashed init")
        rng = np.random.default_rng(0)
        for tok in syllabus_vocab:
            vocab_idx[tok] = len(emb_rows)
            emb_rows.append(rng.standard_normal(args.dim, dtype=np.float32))

    emb = np.stack(emb_rows, axis=0)
    if emb.shape[1] > args.dim:
        emb = emb[:, :args.dim]
    # L2 normalize rows
    norms = np.linalg.norm(emb, axis=1, keepdims=True)
    norms = np.where(norms > 0, norms, 1)
    emb = emb / norms

    # Encode chunks
    chunk_vecs = []
    for c in chunks:
        chunk_vecs.append(embed_text(tokenize(c), vocab_idx, emb))
    chunk_vecs = np.stack(chunk_vecs, axis=0).astype(np.float32)
    # L2 norm chunks
    cn = np.linalg.norm(chunk_vecs, axis=1, keepdims=True)
    cn = np.where(cn > 0, cn, 1)
    chunk_vecs = chunk_vecs / cn

    # Size estimate (int8)
    vocab_bytes = sum(len(t) + 2 for t in vocab_idx)  # term + uint16 id
    emb_bytes = emb.shape[0] * emb.shape[1]  # int8
    chunks_bytes = chunk_vecs.shape[0] * chunk_vecs.shape[1]  # int8
    total = vocab_bytes + emb_bytes + chunks_bytes
    print(f"size (int8): vocab {vocab_bytes/1024:.0f}KB + emb {emb_bytes/1024:.0f}KB"
          f" + chunks {chunks_bytes/1024:.0f}KB = {total/1024/1024:.2f} MB")

    out = evaluate(chunks, chunk_vecs, vocab_idx, emb, holdout)
    print(f"\n*** top-1: {out['top1']*100:.1f}%  (n={out['n']}) ***\n")
    print("by subject:")
    for s, st in out["by_subject"].items():
        print(f"  {s:12} {st['correct']:3d}/{st['total']:3d}  {st['acc']*100:5.1f}%")

    result_path = RESULTS_DIR / f"static_embed_{args.tier_label}.json"
    result_path.write_text(json.dumps({
        "candidate": "B_static_embed",
        "tier": args.tier_label,
        "vocab_cap": args.vocab,
        "dim": int(emb.shape[1]),
        "n_chunks": len(chunks),
        "model_vocab_hit_rate": hit / max(len(syllabus_vocab), 1),
        "size_bytes_int8": total,
        **{k: v for k, v in out.items() if k != "per_q"},
        "per_q_path": str((RESULTS_DIR / f"static_embed_{args.tier_label}__per_q.json").relative_to(HERE.parent)),
    }, indent=2))
    (RESULTS_DIR / f"static_embed_{args.tier_label}__per_q.json").write_text(json.dumps(out["per_q"], indent=2))
    print(f"\nresults: {result_path}")


if __name__ == "__main__":
    main()
