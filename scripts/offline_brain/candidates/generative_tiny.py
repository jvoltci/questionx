"""
Day-4 extension: generative tiny LM ceiling test.

User overrode the day-3 KILL with: "run a generative tiny LM to see if it
materially exceeds 33%. If yes, BUILD-with-bigger-budget. If no, KILL."

Approach: zero-shot logprob scoring on the next-token slot.
  Prompt:  "Question: <q>\nA) <a>\nB) <b>\nC) <c>\nD) <d>\nAnswer:"
  Compare logprob of " A", " B", " C", " D" — pick max.

This is the standard MCQ eval for autoregressive LMs. No fine-tuning.

Default model: SmolLM2-135M (~270 MB fp16 — already 135× over the 2 MB
hypothesis budget, used here purely as a ceiling diagnostic).
"""

import argparse
import json
from collections import defaultdict
from pathlib import Path

import numpy as np
import torch
from transformers import AutoModelForCausalLM, AutoTokenizer

HERE = Path(__file__).resolve().parent
EVAL_DIR = HERE.parent / "eval"
RESULTS_DIR = HERE.parent / "results"
RESULTS_DIR.mkdir(exist_ok=True)


def build_prompt(q: dict) -> str:
    o = q["options"]
    return (
        f"Question: {q['question_latex']}\n"
        f"A) {o[0]}\n"
        f"B) {o[1]}\n"
        f"C) {o[2]}\n"
        f"D) {o[3]}\n"
        f"Answer:"
    )


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--model", default="HuggingFaceTB/SmolLM2-135M")
    ap.add_argument("--limit", type=int, default=0, help="cap eval Qs (smoke test)")
    ap.add_argument("--device", default="mps" if torch.backends.mps.is_available() else "cpu")
    ap.add_argument("--dtype", default="float16")
    ap.add_argument("--tier-label", default="ceiling_generative")
    args = ap.parse_args()

    print(f"loading {args.model} on {args.device} ({args.dtype})...")
    tok = AutoTokenizer.from_pretrained(args.model)
    dtype = {"float16": torch.float16, "float32": torch.float32, "bfloat16": torch.bfloat16}[args.dtype]
    model = AutoModelForCausalLM.from_pretrained(args.model, torch_dtype=dtype)
    model = model.to(args.device).eval()
    n_params = sum(p.numel() for p in model.parameters())
    print(f"  params: {n_params/1e6:.1f}M  est size fp16: {n_params*2/1024/1024:.1f} MB")

    # The token IDs for " A", " B", " C", " D" (leading space matches Answer:_X form)
    letter_ids = []
    for L in ["A", "B", "C", "D"]:
        ids_space = tok.encode(f" {L}", add_special_tokens=False)
        ids_nospace = tok.encode(L, add_special_tokens=False)
        # use the single-token id when possible; prefer the leading-space variant
        if len(ids_space) == 1:
            letter_ids.append(ids_space[0])
        elif len(ids_nospace) == 1:
            letter_ids.append(ids_nospace[0])
        else:
            # fallback: use the first token of the space variant
            letter_ids.append(ids_space[0])
    print(f"  letter token ids (A/B/C/D): {letter_ids}")

    holdout = json.loads((EVAL_DIR / "holdout_500.json").read_text())
    if args.limit:
        holdout = holdout[: args.limit]
    print(f"eval set: {len(holdout)} Qs")

    correct = 0
    by_subject = defaultdict(lambda: [0, 0])
    by_bucket = defaultdict(lambda: [0, 0])
    per_q = []

    with torch.no_grad():
        for i, q in enumerate(holdout):
            prompt = build_prompt(q)
            ids = tok(prompt, return_tensors="pt").to(args.device)
            logits = model(**ids).logits[0, -1]  # last-token logits
            letter_logits = logits[letter_ids].float().cpu().numpy()
            probs = np.exp(letter_logits - letter_logits.max())
            probs = probs / probs.sum()

            pred_idx = int(np.argmax(letter_logits))
            pred_letter = "ABCD"[pred_idx]
            gold = q["answer_key"]
            is_correct = pred_letter == gold

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

            per_q.append({
                "id": q["id"], "subject": subj, "year": year, "gold": gold,
                "pred": pred_letter, "correct": is_correct,
                "letter_probs": probs.tolist(),
            })

            if (i + 1) % 50 == 0:
                running = correct / (i + 1)
                print(f"  [{i+1:4d}/{len(holdout)}] running top-1: {running*100:.1f}%")

    top1 = correct / len(holdout)
    print(f"\n*** {args.model} (generative, logprob-pick) top-1: {top1*100:.1f}%  (n={len(holdout)}) ***\n")
    for s, st in by_subject.items():
        print(f"  {s:12} {st[0]:3d}/{st[1]:3d}  {st[0]/st[1]*100:5.1f}%")
    for b, st in by_bucket.items():
        print(f"  {b:18} {st[0]:3d}/{st[1]:3d}  {st[0]/st[1]*100:5.1f}%")

    short = args.model.split("/")[-1]
    result_path = RESULTS_DIR / f"generative_{short}_{args.tier_label}.json"
    result_path.write_text(json.dumps({
        "candidate": "D_generative_LM_ceiling",
        "model": args.model,
        "n_params_millions": n_params / 1e6,
        "fp16_size_mb": n_params * 2 / 1024 / 1024,
        "device": args.device,
        "dtype": args.dtype,
        "tier": args.tier_label,
        "top1": top1,
        "n": len(holdout),
        "by_subject": {k: {"correct": v[0], "total": v[1], "acc": v[0]/v[1] if v[1] else 0.0} for k, v in by_subject.items()},
        "by_bucket":  {k: {"correct": v[0], "total": v[1], "acc": v[0]/v[1] if v[1] else 0.0} for k, v in by_bucket.items()},
    }, indent=2))
    (RESULTS_DIR / f"generative_{short}_{args.tier_label}__per_q.json").write_text(json.dumps(per_q, indent=2))
    print(f"\nresults: {result_path}")


if __name__ == "__main__":
    main()
