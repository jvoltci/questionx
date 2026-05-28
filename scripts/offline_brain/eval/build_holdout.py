"""
Build a deterministic 500-Q held-out eval split from assets/neet.json.

Constraints (locked in Phase A plan, 2026-05-29):
- Source: NEET 2015-2025 only (NTA-era, trusted answer keys).
- AIPMT 2005-2014 stays in the corpus side, never in eval.
- Stratified by (subject, year_bucket). 'General Knowledge' excluded.
- Deterministic — fixed seed; same input → same split forever.

Outputs:
  scripts/offline_brain/eval/holdout_500.json   - eval set (untouchable)
  scripts/offline_brain/eval/corpus_side.json   - everything else (3356)
  scripts/offline_brain/eval/split_manifest.json - stratification stats
"""

import json
import random
from collections import Counter, defaultdict
from pathlib import Path

HERE = Path(__file__).resolve().parent
REPO_ROOT = HERE.parents[2]
NEET_JSON = REPO_ROOT / "assets" / "neet.json"

SEED = 1729  # never change
TARGET_HOLDOUT = 500

YEAR_BUCKETS = {
    "ntaA_2015_2019": range(2015, 2020),
    "ntaB_2020_2022": range(2020, 2023),
    "ntaC_2023_2025": range(2023, 2026),
}

# Stratification targets: subject distribution from plan §2.
# Bio is ~50% of corpus, so 250/500. Phy and Chem ~equal.
SUBJECT_QUOTA = {"Physics": 125, "Chemistry": 125, "Biology": 250}


def bucket_for(year: int) -> str | None:
    for name, rng in YEAR_BUCKETS.items():
        if year in rng:
            return name
    return None


def is_eligible(q: dict) -> bool:
    """NTA-era NEET only; the exam name 'NEET' covers 2015+."""
    if q.get("exam") != "NEET":
        return False
    year = q.get("year")
    if not isinstance(year, int) or year < 2015 or year > 2025:
        return False
    if q.get("subject") not in SUBJECT_QUOTA:
        return False
    # require answer_key, options, question_latex — else useless for eval
    if not q.get("answer_key") or q["answer_key"] not in {"A", "B", "C", "D"}:
        return False
    if not isinstance(q.get("options"), list) or len(q["options"]) != 4:
        return False
    if not q.get("question_latex"):
        return False
    return True


def stratified_sample(eligible: list[dict], quota: dict[str, int], seed: int) -> list[dict]:
    """Per-subject random sample, spreading roughly evenly across year buckets."""
    rng = random.Random(seed)
    by_subject_bucket: dict[tuple[str, str], list[dict]] = defaultdict(list)
    for q in eligible:
        b = bucket_for(q["year"])
        if b is None:
            continue
        by_subject_bucket[(q["subject"], b)].append(q)

    picked: list[dict] = []
    for subject, n_total in quota.items():
        buckets = list(YEAR_BUCKETS.keys())
        per_bucket = n_total // len(buckets)
        remainder = n_total - per_bucket * len(buckets)
        for i, b in enumerate(buckets):
            take = per_bucket + (1 if i < remainder else 0)
            pool = by_subject_bucket[(subject, b)]
            if len(pool) < take:
                # not enough in this bucket; borrow from neighbors after main pass
                picked.extend(pool)
                continue
            picked.extend(rng.sample(pool, take))

    # if we fell short due to thin buckets, top up randomly from eligible-not-picked
    picked_ids = {q["id"] for q in picked}
    if len(picked) < TARGET_HOLDOUT:
        remainder_pool = [q for q in eligible if q["id"] not in picked_ids]
        rng.shuffle(remainder_pool)
        picked.extend(remainder_pool[: TARGET_HOLDOUT - len(picked)])
    elif len(picked) > TARGET_HOLDOUT:
        picked = rng.sample(picked, TARGET_HOLDOUT)

    picked.sort(key=lambda q: q["id"])
    return picked


def main() -> None:
    all_q = json.loads(NEET_JSON.read_text())
    print(f"loaded {len(all_q)} questions from {NEET_JSON.name}")

    eligible = [q for q in all_q if is_eligible(q)]
    print(f"eligible (NEET 2015-2025, Phy/Chem/Bio, 4-opt, AK in ABCD): {len(eligible)}")

    holdout = stratified_sample(eligible, SUBJECT_QUOTA, SEED)
    holdout_ids = {q["id"] for q in holdout}
    corpus_side = [q for q in all_q if q["id"] not in holdout_ids]

    # stats
    h_subj = Counter(q["subject"] for q in holdout)
    h_year = Counter(q["year"] for q in holdout)
    h_bucket = Counter(bucket_for(q["year"]) for q in holdout)
    c_subj = Counter(q["subject"] for q in corpus_side)

    manifest = {
        "seed": SEED,
        "source_file": str(NEET_JSON.relative_to(REPO_ROOT)),
        "source_question_count": len(all_q),
        "eligible_count": len(eligible),
        "holdout_count": len(holdout),
        "corpus_side_count": len(corpus_side),
        "holdout_by_subject": dict(h_subj),
        "holdout_by_year": dict(sorted(h_year.items())),
        "holdout_by_bucket": dict(h_bucket),
        "corpus_side_by_subject": dict(c_subj),
        "constraints": {
            "exam": "NEET",
            "year_range": "2015-2025 inclusive",
            "subjects": list(SUBJECT_QUOTA.keys()),
            "required_keys": ["answer_key in ABCD", "len(options)==4", "question_latex truthy"],
        },
    }

    (HERE / "holdout_500.json").write_text(json.dumps(holdout, indent=2))
    (HERE / "corpus_side.json").write_text(json.dumps(corpus_side, indent=2))
    (HERE / "split_manifest.json").write_text(json.dumps(manifest, indent=2))

    print(f"\nholdout written: {len(holdout)} Qs")
    print(f"  by subject: {dict(h_subj)}")
    print(f"  by bucket:  {dict(h_bucket)}")
    print(f"corpus_side: {len(corpus_side)} Qs")
    print(f"\nmanifest: {HERE / 'split_manifest.json'}")


if __name__ == "__main__":
    main()
