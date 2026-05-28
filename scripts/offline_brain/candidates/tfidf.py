"""
Candidate A: TF-IDF / BM25 over NCERT chunks (or any chunk corpus).

Pipeline:
  1. Build vocabulary from chunks (limited to top-k by document frequency).
  2. Build BM25 index over chunks.
  3. For each eval Q: score each of 4 options by BM25(option ⊕ question, chunks),
     pick argmax.

Size is controlled by:
  - vocab cap (--vocab)
  - chunk count cap (--chunks)
  - whether chunk text is stored (zstd-compressed) or only term postings

For the 2.0 MB tier: 12k vocab + 1500 chunks @ 600 chars zstd ≈ 2 MB.
"""

import argparse
import json
import math
import re
from collections import Counter, defaultdict
from pathlib import Path

import numpy as np

HERE = Path(__file__).resolve().parent
EVAL_DIR = HERE.parent / "eval"
RESULTS_DIR = HERE.parent / "results"
RESULTS_DIR.mkdir(exist_ok=True)

WORD_RE = re.compile(r"[a-z0-9]+")

# LaTeX command stripper — keep math content tokens but drop \frac, \alpha, etc.
LATEX_CMD_RE = re.compile(r"\\[a-zA-Z]+")
LATEX_DELIM_RE = re.compile(r"[\\${}^_]")


def tokenize(text: str) -> list[str]:
    """Lowercase, strip latex commands, word-tokenize, drop singletons."""
    if not text:
        return []
    text = LATEX_CMD_RE.sub(" ", text)
    text = LATEX_DELIM_RE.sub(" ", text)
    text = text.lower()
    return [t for t in WORD_RE.findall(text) if len(t) > 1]


class BM25Index:
    """Compact BM25. Vocab is capped; out-of-vocab terms dropped at query time."""

    def __init__(self, k1: float = 1.5, b: float = 0.75):
        self.k1 = k1
        self.b = b
        self.vocab: dict[str, int] = {}
        self.idf: np.ndarray = np.zeros(0, dtype=np.float32)
        self.doc_freqs: list[dict[int, int]] = []  # tid -> tf for each doc
        self.doc_lens: np.ndarray = np.zeros(0, dtype=np.float32)
        self.avg_dl: float = 0.0
        self.chunks: list[str] = []

    def fit(self, chunks: list[str], vocab_cap: int) -> "BM25Index":
        self.chunks = list(chunks)
        tokenized = [tokenize(c) for c in chunks]
        # global doc frequency
        df = Counter()
        for toks in tokenized:
            df.update(set(toks))
        # drop trivial frequency tokens
        kept = [(t, c) for t, c in df.most_common() if c >= 2]
        kept = kept[:vocab_cap]
        self.vocab = {t: i for i, (t, _) in enumerate(kept)}
        N = len(chunks)
        n_t = np.zeros(len(self.vocab), dtype=np.int32)
        self.doc_freqs = []
        dls = np.zeros(N, dtype=np.float32)
        for i, toks in enumerate(tokenized):
            tf: dict[int, int] = defaultdict(int)
            for t in toks:
                tid = self.vocab.get(t)
                if tid is not None:
                    tf[tid] += 1
            dls[i] = sum(tf.values()) or 1
            for tid in tf:
                n_t[tid] += 1
            self.doc_freqs.append(dict(tf))
        self.doc_lens = dls
        self.avg_dl = float(dls.mean())
        # BM25 IDF
        self.idf = np.log((N - n_t + 0.5) / (n_t + 0.5) + 1.0).astype(np.float32)
        return self

    def score(self, query_tokens: list[str], doc_idx: int) -> float:
        tf = self.doc_freqs[doc_idx]
        dl = self.doc_lens[doc_idx]
        norm = 1 - self.b + self.b * dl / self.avg_dl
        s = 0.0
        for t in query_tokens:
            tid = self.vocab.get(t)
            if tid is None:
                continue
            f = tf.get(tid, 0)
            if f == 0:
                continue
            s += float(self.idf[tid]) * (f * (self.k1 + 1)) / (f + self.k1 * norm)
        return s

    def topk(self, query_tokens: list[str], k: int) -> list[int]:
        scores = np.array([self.score(query_tokens, i) for i in range(len(self.chunks))], dtype=np.float32)
        if k >= len(scores):
            return list(np.argsort(-scores))
        return list(np.argpartition(-scores, k)[:k])

    def serialized_size_estimate(self) -> int:
        """Rough byte count of the on-disk form (vocab + idf + postings + chunks)."""
        vocab_bytes = sum(len(t) + 4 for t in self.vocab)  # term + uint32 id
        idf_bytes = self.idf.nbytes
        # postings: per doc, n_unique_terms * (tid:uint16 + tf:uint8) = 3 bytes
        postings_bytes = sum(len(df) * 3 for df in self.doc_freqs)
        doclen_bytes = self.doc_lens.nbytes
        # chunks: stored as utf-8, ~0.5x zstd
        chunk_bytes = int(sum(len(c.encode("utf-8")) for c in self.chunks) * 0.5)
        return vocab_bytes + idf_bytes + postings_bytes + doclen_bytes + chunk_bytes


def load_chunks(chunks_path: Path) -> list[str]:
    return json.loads(chunks_path.read_text())["chunks"]


def evaluate(index: BM25Index, holdout: list[dict], k_retrieve: int = 3) -> dict:
    """For each Q, score each option by BM25(option ⊕ Q, retrieved-top-k merged)."""
    correct = 0
    correct_by_subject = defaultdict(lambda: [0, 0])  # [correct, total]
    correct_by_bucket = defaultdict(lambda: [0, 0])
    per_q = []

    for q in holdout:
        q_toks = tokenize(q["question_latex"])
        # retrieve top-k by Q alone — that's the index lookup
        top = index.topk(q_toks, k_retrieve)
        # merge tokenized chunks as the "context"
        ctx_toks = []
        for ci in top:
            ctx_toks.extend(tokenize(index.chunks[ci]))
        # For each option, score = BM25 of (option_tokens ⊕ q_toks) against a
        # virtual "merged" doc — implemented as a simple weighted overlap.
        # We use a pseudo-doc index: build per-option tokens, score by counting
        # how many option tokens appear in the merged ctx vs not.
        ctx_set = set(ctx_toks)
        option_scores = []
        for opt in q["options"]:
            o_toks = tokenize(opt)
            if not o_toks:
                option_scores.append(0.0)
                continue
            # weight: rare ctx terms count more. Use the index's IDF for ctx tokens.
            hits = 0.0
            for t in o_toks:
                tid = index.vocab.get(t)
                if tid is not None and t in ctx_set:
                    hits += float(index.idf[tid])
            # length-normalize so long options don't dominate
            option_scores.append(hits / max(len(o_toks), 1))

        # tie-break: if all-zero (option vocab disjoint from ctx), pick by Q overlap
        if max(option_scores) == 0.0:
            for i, opt in enumerate(q["options"]):
                o_toks = tokenize(opt)
                inter = set(o_toks) & set(q_toks)
                option_scores[i] = float(len(inter))
            if max(option_scores) == 0.0:
                # still zero — pick A (alphabetical default)
                pred_idx = 0
            else:
                pred_idx = int(np.argmax(option_scores))
        else:
            pred_idx = int(np.argmax(option_scores))

        pred_letter = "ABCD"[pred_idx]
        gold = q["answer_key"]
        is_correct = pred_letter == gold

        subj = q["subject"]
        year = q["year"]
        bucket = (
            "ntaA_2015_2019" if year <= 2019
            else "ntaB_2020_2022" if year <= 2022
            else "ntaC_2023_2025"
        )

        correct_by_subject[subj][1] += 1
        correct_by_bucket[bucket][1] += 1
        if is_correct:
            correct += 1
            correct_by_subject[subj][0] += 1
            correct_by_bucket[bucket][0] += 1

        per_q.append({
            "id": q["id"],
            "subject": subj,
            "year": year,
            "gold": gold,
            "pred": pred_letter,
            "correct": is_correct,
            "option_scores": option_scores,
            "retrieved_chunks": [int(t) for t in top],
        })

    return {
        "top1": correct / len(holdout),
        "n": len(holdout),
        "by_subject": {k: {"correct": v[0], "total": v[1], "acc": v[0] / v[1] if v[1] else 0.0}
                       for k, v in correct_by_subject.items()},
        "by_bucket": {k: {"correct": v[0], "total": v[1], "acc": v[0] / v[1] if v[1] else 0.0}
                      for k, v in correct_by_bucket.items()},
        "per_q": per_q,
    }


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--chunks", default=str(HERE.parent / "ncert" / "chunks.json"))
    ap.add_argument("--vocab", type=int, default=12_000, help="vocab cap")
    ap.add_argument("--max-chunks", type=int, default=0, help="cap chunks (0=all)")
    ap.add_argument("--tier-label", default="2.0MB")
    args = ap.parse_args()

    chunks = load_chunks(Path(args.chunks))
    if args.max_chunks and len(chunks) > args.max_chunks:
        # take a stratified sample if we have a subject tag — else first N
        chunks = chunks[:args.max_chunks]
    print(f"chunks: {len(chunks)}")

    index = BM25Index().fit(chunks, vocab_cap=args.vocab)
    print(f"vocab: {len(index.vocab)}")
    print(f"size estimate: {index.serialized_size_estimate() / 1024:.1f} KB")

    holdout = json.loads((EVAL_DIR / "holdout_500.json").read_text())
    print(f"eval set: {len(holdout)} Qs")

    out = evaluate(index, holdout)
    print(f"\n*** top-1: {out['top1']*100:.1f}%  (n={out['n']}) ***\n")
    print("by subject:")
    for s, st in out["by_subject"].items():
        print(f"  {s:12} {st['correct']:3d}/{st['total']:3d}  {st['acc']*100:5.1f}%")
    print("by year-bucket:")
    for b, st in out["by_bucket"].items():
        print(f"  {b:18} {st['correct']:3d}/{st['total']:3d}  {st['acc']*100:5.1f}%")

    result_path = RESULTS_DIR / f"tfidf_{args.tier_label}.json"
    result_path.write_text(json.dumps({
        "candidate": "A_tfidf",
        "tier": args.tier_label,
        "vocab_cap": args.vocab,
        "n_chunks": len(chunks),
        "size_estimate_bytes": index.serialized_size_estimate(),
        **{k: v for k, v in out.items() if k != "per_q"},
        "per_q_path": str((RESULTS_DIR / f"tfidf_{args.tier_label}__per_q.json").relative_to(HERE.parent)),
    }, indent=2))
    (RESULTS_DIR / f"tfidf_{args.tier_label}__per_q.json").write_text(json.dumps(out["per_q"], indent=2))
    print(f"\nresults: {result_path}")


if __name__ == "__main__":
    main()
