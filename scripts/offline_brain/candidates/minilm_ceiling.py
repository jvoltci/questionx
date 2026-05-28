"""
Candidate C: SOTA-on-device-class sentence transformer (MiniLM-L6).

Purpose: establish the CEILING. Not constrained to 2MB. Not portable to Dart.
We run the full uncapped model. If THIS doesn't hit 85% on the 500-Q holdout,
no smaller version will — kill the hypothesis.

If it does hit 85%, then quantization/distillation budget conversation begins.
"""

import argparse
import json
from collections import defaultdict
from pathlib import Path

import numpy as np
from sentence_transformers import SentenceTransformer

HERE = Path(__file__).resolve().parent
EVAL_DIR = HERE.parent / "eval"
RESULTS_DIR = HERE.parent / "results"
RESULTS_DIR.mkdir(exist_ok=True)


def evaluate(model: SentenceTransformer, chunks: list[str], holdout: list[dict],
             k_retrieve: int = 3, opt_mode: str = "qopt") -> dict:
    print(f"encoding {len(chunks)} chunks...")
    chunk_vecs = np.asarray(
        model.encode(chunks, batch_size=64, show_progress_bar=True,
                     normalize_embeddings=True),
        dtype=np.float32,
    )
    print(f"  chunk vectors: {chunk_vecs.shape}")

    # batch-encode all Qs and options for speed
    q_texts = [q["question_latex"] for q in holdout]
    print("encoding questions...")
    q_vecs = np.asarray(
        model.encode(q_texts, batch_size=64, show_progress_bar=True,
                     normalize_embeddings=True),
        dtype=np.float32,
    )

    print("encoding options...")
    opt_texts: list[str] = []
    for q in holdout:
        for opt in q["options"]:
            opt_texts.append(f"{q['question_latex']} {opt}" if opt_mode == "qopt" else opt)
    opt_vecs = np.asarray(
        model.encode(opt_texts, batch_size=128, show_progress_bar=True,
                     normalize_embeddings=True),
        dtype=np.float32,
    )

    correct = 0
    correct_by_subject = defaultdict(lambda: [0, 0])
    correct_by_bucket = defaultdict(lambda: [0, 0])
    per_q = []

    for i, q in enumerate(holdout):
        q_vec = q_vecs[i]
        sims = chunk_vecs @ q_vec
        top = np.argpartition(-sims, min(k_retrieve, len(sims)-1))[:k_retrieve]
        ctx_vec = chunk_vecs[top].mean(axis=0)
        cn = np.linalg.norm(ctx_vec)
        if cn > 0:
            ctx_vec = ctx_vec / cn

        o = opt_vecs[i * 4 : i * 4 + 4]
        option_scores = (o @ ctx_vec).tolist()
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
    ap.add_argument("--model", default="sentence-transformers/all-MiniLM-L6-v2")
    ap.add_argument("--k", type=int, default=3)
    ap.add_argument("--opt-mode", default="qopt", choices=["qopt", "opt"])
    ap.add_argument("--tier-label", default="ceiling")
    ap.add_argument("--limit", type=int, default=0, help="only eval first N holdout Qs (smoke test)")
    args = ap.parse_args()

    print(f"loading {args.model}...")
    model = SentenceTransformer(args.model)
    print(f"  embedding dim: {model.get_sentence_embedding_dimension()}")

    chunks = json.loads(Path(args.chunks).read_text())["chunks"]
    print(f"chunks: {len(chunks)}")

    holdout = json.loads((EVAL_DIR / "holdout_500.json").read_text())
    if args.limit:
        holdout = holdout[: args.limit]
    print(f"eval set: {len(holdout)} Qs")

    out = evaluate(model, chunks, holdout, k_retrieve=args.k, opt_mode=args.opt_mode)
    print(f"\n*** {args.model} {args.tier_label} (opt-mode={args.opt_mode}) "
          f"top-1: {out['top1']*100:.1f}%  (n={out['n']}) ***\n")
    for s, st in out["by_subject"].items():
        print(f"  {s:12} {st['correct']:3d}/{st['total']:3d}  {st['acc']*100:5.1f}%")
    for b, st in out["by_bucket"].items():
        print(f"  {b:18} {st['correct']:3d}/{st['total']:3d}  {st['acc']*100:5.1f}%")

    result_path = RESULTS_DIR / f"minilm_{args.tier_label}_{args.opt_mode}.json"
    result_path.write_text(json.dumps({
        "candidate": "C_MiniLM_ceiling",
        "model": args.model,
        "tier": args.tier_label,
        "n_chunks": len(chunks),
        "opt_mode": args.opt_mode,
        "k_retrieve": args.k,
        **{k: v for k, v in out.items() if k != "per_q"},
    }, indent=2))
    (result_path.with_suffix("")).with_name(result_path.stem + "__per_q.json").write_text(
        json.dumps(out["per_q"], indent=2))
    print(f"\nresults: {result_path}")


if __name__ == "__main__":
    main()
