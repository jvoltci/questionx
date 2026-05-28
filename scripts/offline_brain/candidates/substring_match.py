"""
Sanity check: pure substring matching as the cheapest possible scorer.

For each Q:
  - retrieve top-k chunks (BM25 by question text)
  - for each option, count: how many of its key terms appear in retrieved chunks?
  - rare-term-weighted

This catches Biology Qs where the right answer is literally written in NCERT
("the cell wall is composed of cellulose"). It will fail on math/derivation.

If THIS doesn't beat the embedding ceiling, retrieval-as-MCQ-answerer is dead
regardless of architecture.
"""

import json
import math
import re
from collections import Counter, defaultdict
from pathlib import Path

import numpy as np

HERE = Path(__file__).resolve().parent
EVAL_DIR = HERE.parent / "eval"
RESULTS_DIR = HERE.parent / "results"

import sys
sys.path.insert(0, str(HERE))
from tfidf import BM25Index, tokenize  # noqa: E402


def main() -> None:
    chunks = json.loads((HERE.parent / "ncert" / "chunks.json").read_text())["chunks"]
    holdout = json.loads((EVAL_DIR / "holdout_500.json").read_text())

    index = BM25Index().fit(chunks, vocab_cap=60_000)
    print(f"vocab: {len(index.vocab)}, chunks: {len(chunks)}")

    # Doc-frequency-weighted: rare terms count more.
    # df[t] = how many chunks contain t
    df = Counter()
    for c in chunks:
        df.update(set(tokenize(c)))
    n_chunks = len(chunks)
    idf = {t: math.log(n_chunks / (1 + n)) for t, n in df.items()}

    correct = 0
    by_subject = defaultdict(lambda: [0, 0])
    by_bucket = defaultdict(lambda: [0, 0])

    for q in holdout:
        q_toks = tokenize(q["question_latex"])
        top = index.topk(q_toks, 5)
        ctx_text = " ".join(chunks[c] for c in top).lower()

        scores = []
        for opt in q["options"]:
            o_toks = tokenize(opt)
            # weighted substring count: each option token's idf if it appears in ctx
            score = 0.0
            for t in o_toks:
                if t in ctx_text and len(t) >= 3:
                    score += idf.get(t, 0)
            # normalize by # of distinct option tokens, so longer options aren't favored
            n_uniq = max(len(set(o_toks)), 1)
            scores.append(score / n_uniq)

        pred_idx = int(np.argmax(scores)) if max(scores) > 0 else 0
        pred_letter = "ABCD"[pred_idx]
        is_correct = pred_letter == q["answer_key"]

        subj = q["subject"]; year = q["year"]
        bucket = ("ntaA_2015_2019" if year <= 2019
                  else "ntaB_2020_2022" if year <= 2022
                  else "ntaC_2023_2025")
        by_subject[subj][1] += 1
        by_bucket[bucket][1] += 1
        if is_correct:
            correct += 1
            by_subject[subj][0] += 1
            by_bucket[bucket][0] += 1

    top1 = correct / len(holdout)
    print(f"\n*** Substring-match (rare-term weighted) top-1: {top1*100:.1f}%  (n={len(holdout)}) ***\n")
    for s, st in by_subject.items():
        print(f"  {s:12} {st[0]:3d}/{st[1]:3d}  {st[0]/st[1]*100:5.1f}%")
    for b, st in by_bucket.items():
        print(f"  {b:18} {st[0]:3d}/{st[1]:3d}  {st[0]/st[1]*100:5.1f}%")

    (RESULTS_DIR / "substring_match.json").write_text(json.dumps({
        "candidate": "substring_match_baseline",
        "top1": top1,
        "n": len(holdout),
        "by_subject": {k: {"correct": v[0], "total": v[1], "acc": v[0]/v[1]} for k, v in by_subject.items()},
        "by_bucket": {k: {"correct": v[0], "total": v[1], "acc": v[0]/v[1]} for k, v in by_bucket.items()},
    }, indent=2))


if __name__ == "__main__":
    main()
