"""
Candidate B v2: Static embeddings via model2vec's potion family.

Key fix vs v1: use the model's own (BPE) tokenizer, not a word-level regex.
Subword tokenization is what gives static embeddings their generalization —
'photosynthesis' splits into 'photo' + 'synthesis' etc and each subword's
embedding contributes.

Pipeline:
  1. Load a potion-base-{2M|4M|8M} static model (pre-distilled by minishlab).
  2. Encode chunks via model.encode() (mean-pool of subword vectors).
  3. For each Q in holdout:
       q_vec   = encode(question_latex)
       ctx     = mean(top-k chunks by cosine with q_vec)
       picked  = argmax over options of cos(encode(opt ⊕ q), ctx)

Inference uses only the model's vocab + embedding table; portable to Dart.
Size = vocab_bytes + (vocab × dim × int8) + chunk_count × dim × int8.
"""

import argparse
import json
from collections import defaultdict
from pathlib import Path

import numpy as np
from model2vec import StaticModel

HERE = Path(__file__).resolve().parent
EVAL_DIR = HERE.parent / "eval"
RESULTS_DIR = HERE.parent / "results"
RESULTS_DIR.mkdir(exist_ok=True)


def size_estimate_bytes(model: StaticModel, n_chunks: int) -> int:
    vocab = model.tokenizer.get_vocab()
    vocab_bytes = sum(len(t) + 2 for t in vocab)  # term + uint16 id
    dim = model.embedding.shape[1]
    emb_bytes_int8 = model.embedding.shape[0] * dim  # 1 byte/value @ int8
    chunks_bytes_int8 = n_chunks * dim
    return vocab_bytes + emb_bytes_int8 + chunks_bytes_int8


def evaluate(model: StaticModel, chunks: list[str], holdout: list[dict],
             k_retrieve: int = 3, opt_mode: str = "qopt") -> dict:
    print("encoding chunks...")
    chunk_vecs = model.encode(chunks).astype(np.float32)
    norms = np.linalg.norm(chunk_vecs, axis=1, keepdims=True)
    chunk_vecs = chunk_vecs / np.where(norms > 0, norms, 1)
    print(f"  chunk vectors: {chunk_vecs.shape}")

    correct = 0
    correct_by_subject = defaultdict(lambda: [0, 0])
    correct_by_bucket = defaultdict(lambda: [0, 0])
    per_q = []

    for q in holdout:
        q_text = q["question_latex"]
        q_vec = model.encode([q_text])[0].astype(np.float32)
        n = np.linalg.norm(q_vec)
        if n > 0:
            q_vec = q_vec / n

        sims = chunk_vecs @ q_vec
        top = np.argpartition(-sims, min(k_retrieve, len(sims)-1))[:k_retrieve]
        ctx_vec = chunk_vecs[top].mean(axis=0)
        cn = np.linalg.norm(ctx_vec)
        if cn > 0:
            ctx_vec = ctx_vec / cn

        # score each option
        if opt_mode == "qopt":
            # encode (q + option) jointly — what we think the right answer looks like in context
            opt_texts = [f"{q_text} {opt}" for opt in q["options"]]
        else:
            opt_texts = list(q["options"])
        opt_vecs = model.encode(opt_texts).astype(np.float32)
        on = np.linalg.norm(opt_vecs, axis=1, keepdims=True)
        opt_vecs = opt_vecs / np.where(on > 0, on, 1)
        option_scores = (opt_vecs @ ctx_vec).tolist()

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

        per_q.append({
            "id": q["id"], "subject": subj, "year": year, "gold": gold,
            "pred": pred_letter, "correct": is_correct,
            "option_scores": [float(s) for s in option_scores],
            "retrieved": [int(t) for t in top],
        })

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
    ap.add_argument("--model", default="minishlab/potion-base-2M",
                    help="potion-base-{2M,4M,8M} or full path")
    ap.add_argument("--max-chunks", type=int, default=0)
    ap.add_argument("--k", type=int, default=3)
    ap.add_argument("--opt-mode", default="qopt", choices=["qopt", "opt"],
                    help="qopt: encode (q ⊕ option). opt: encode option alone.")
    ap.add_argument("--tier-label", default="auto")
    args = ap.parse_args()

    print(f"loading {args.model}...")
    model = StaticModel.from_pretrained(args.model)
    dim = model.embedding.shape[1]
    print(f"  vocab: {len(model.tokenizer.get_vocab())}, dim: {dim}")

    chunks = json.loads(Path(args.chunks).read_text())["chunks"]
    if args.max_chunks and len(chunks) > args.max_chunks:
        chunks = chunks[:args.max_chunks]
    print(f"chunks: {len(chunks)}")

    size_b = size_estimate_bytes(model, len(chunks))
    tier_label = args.tier_label
    if tier_label == "auto":
        tier_label = f"{size_b/1024/1024:.1f}MB"
    print(f"size (int8 estimate): {size_b/1024/1024:.2f} MB")

    holdout = json.loads((EVAL_DIR / "holdout_500.json").read_text())
    out = evaluate(model, chunks, holdout, k_retrieve=args.k, opt_mode=args.opt_mode)
    print(f"\n*** {args.model} {tier_label} (opt-mode={args.opt_mode}) "
          f"top-1: {out['top1']*100:.1f}%  (n={out['n']}) ***\n")
    for s, st in out["by_subject"].items():
        print(f"  {s:12} {st['correct']:3d}/{st['total']:3d}  {st['acc']*100:5.1f}%")
    for b, st in out["by_bucket"].items():
        print(f"  {b:18} {st['correct']:3d}/{st['total']:3d}  {st['acc']*100:5.1f}%")

    model_short = args.model.split("/")[-1]
    result_path = RESULTS_DIR / f"static_{model_short}_{tier_label}_{args.opt_mode}.json"
    result_path.write_text(json.dumps({
        "candidate": "B_static_embed",
        "model": args.model,
        "tier": tier_label,
        "dim": int(dim),
        "n_chunks": len(chunks),
        "opt_mode": args.opt_mode,
        "k_retrieve": args.k,
        "size_bytes_int8": size_b,
        **{k: v for k, v in out.items() if k != "per_q"},
        "per_q_path": str((result_path.with_suffix("")).name + "__per_q.json"),
    }, indent=2))
    per_q_path = RESULTS_DIR / f"{result_path.stem}__per_q.json"
    per_q_path.write_text(json.dumps(out["per_q"], indent=2))
    print(f"\nresults: {result_path}")


if __name__ == "__main__":
    main()
