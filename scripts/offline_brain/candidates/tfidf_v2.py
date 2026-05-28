"""
Candidate A v2: TF-IDF with per-option retrieval scoring.

Instead of retrieving with Q alone and overlap-scoring options against the
shared retrieved context, we retrieve once per (Q + option) and score by the
top-chunk's BM25 score for that combined query. The intuition: the correct
option ⊕ Q will surface a chunk that contains all of: the question's topic
+ the answer term + supporting context. Wrong options will surface less
coherent chunks.

This is still pure-Dart-portable (BM25 lookup only).
"""

import argparse
import json
import re
from collections import Counter, defaultdict
from pathlib import Path

import numpy as np

HERE = Path(__file__).resolve().parent
EVAL_DIR = HERE.parent / "eval"
RESULTS_DIR = HERE.parent / "results"
RESULTS_DIR.mkdir(exist_ok=True)

# Reuse tokenizer + BM25Index from tfidf.py
import sys
sys.path.insert(0, str(HERE))
from tfidf import BM25Index, tokenize  # noqa: E402


def evaluate_per_option(index: BM25Index, holdout: list[dict], k: int = 3) -> dict:
    correct = 0
    correct_by_subject = defaultdict(lambda: [0, 0])
    correct_by_bucket = defaultdict(lambda: [0, 0])
    per_q = []

    for q in holdout:
        q_toks = tokenize(q["question_latex"])
        option_scores = []
        per_opt_chunks = []
        for opt in q["options"]:
            o_toks = tokenize(opt)
            joint = q_toks + o_toks
            top = index.topk(joint, k)
            # score = sum of top-k BM25 (rewards a chunk that fits the combo)
            top_scores = [index.score(joint, ci) for ci in top]
            top_scores.sort(reverse=True)
            score = float(sum(top_scores[:k]))
            option_scores.append(score)
            per_opt_chunks.append([int(c) for c in top])

        if max(option_scores) == 0.0:
            pred_idx = 0  # fallback A
        else:
            pred_idx = int(np.argmax(option_scores))

        pred_letter = "ABCD"[pred_idx]
        gold = q["answer_key"]
        is_correct = pred_letter == gold

        subj = q["subject"]; year = q["year"]
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
            "option_scores": option_scores,
            "per_option_chunks": per_opt_chunks,
        })

    return {
        "top1": correct / len(holdout),
        "n": len(holdout),
        "by_subject": {k_: {"correct": v[0], "total": v[1], "acc": v[0]/v[1] if v[1] else 0.0}
                       for k_, v in correct_by_subject.items()},
        "by_bucket": {k_: {"correct": v[0], "total": v[1], "acc": v[0]/v[1] if v[1] else 0.0}
                      for k_, v in correct_by_bucket.items()},
        "per_q": per_q,
    }


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--chunks", default=str(HERE.parent / "ncert" / "chunks.json"))
    ap.add_argument("--vocab", type=int, default=12_000)
    ap.add_argument("--max-chunks", type=int, default=0)
    ap.add_argument("--k", type=int, default=3)
    ap.add_argument("--tier-label", default="2.0MB_v2")
    args = ap.parse_args()

    chunks_data = json.loads(Path(args.chunks).read_text())
    chunks = chunks_data["chunks"]
    if args.max_chunks and len(chunks) > args.max_chunks:
        chunks = chunks[:args.max_chunks]
    print(f"chunks: {len(chunks)}")

    index = BM25Index().fit(chunks, vocab_cap=args.vocab)
    print(f"vocab: {len(index.vocab)}, size est: {index.serialized_size_estimate()/1024:.1f} KB")

    holdout = json.loads((EVAL_DIR / "holdout_500.json").read_text())
    out = evaluate_per_option(index, holdout, k=args.k)
    print(f"\n*** TF-IDF v2 (per-option retrieval) top-1: {out['top1']*100:.1f}%  (n={out['n']}) ***\n")
    for s, st in out["by_subject"].items():
        print(f"  {s:12} {st['correct']:3d}/{st['total']:3d}  {st['acc']*100:5.1f}%")
    for b, st in out["by_bucket"].items():
        print(f"  {b:18} {st['correct']:3d}/{st['total']:3d}  {st['acc']*100:5.1f}%")

    result_path = RESULTS_DIR / f"tfidf_v2_{args.tier_label}.json"
    result_path.write_text(json.dumps({
        "candidate": "A_tfidf_per_option",
        "tier": args.tier_label,
        "vocab_cap": args.vocab,
        "n_chunks": len(chunks),
        "k_retrieve": args.k,
        "size_estimate_bytes": index.serialized_size_estimate(),
        **{k: v for k, v in out.items() if k != "per_q"},
        "per_q_path": str((RESULTS_DIR / f"tfidf_v2_{args.tier_label}__per_q.json").relative_to(HERE.parent)),
    }, indent=2))
    (RESULTS_DIR / f"tfidf_v2_{args.tier_label}__per_q.json").write_text(json.dumps(out["per_q"], indent=2))
    print(f"\nresults: {result_path}")


if __name__ == "__main__":
    main()
