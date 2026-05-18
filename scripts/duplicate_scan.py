#!/usr/bin/env python3
"""Cross-year duplicate-question scan for assets/neet.json.

Fingerprint each question by a normalized form of question_latex.
Cluster fingerprints; report clusters with >1 member.
Read-only: writes scripts/duplicate_scan_report.json. No dataset mutation.
"""

import json
import re
import sys
from collections import defaultdict
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
DATA = ROOT / "assets" / "neet.json"
OUT = ROOT / "scripts" / "duplicate_scan_report.json"


def normalize(text: str) -> str:
    if not text:
        return ""
    s = text.lower()
    # Strip common LaTeX wrappers / delimiters
    s = re.sub(r"\$+", " ", s)
    s = re.sub(r"\\\(|\\\)|\\\[|\\\]", " ", s)
    s = re.sub(r"\\(text|mathrm|mathbf|mathit|mathsf|mathtt|operatorname)\{([^{}]*)\}", r"\2", s)
    s = re.sub(r"\\[a-zA-Z]+\*?", " ", s)        # any remaining \command
    s = re.sub(r"[{}]", " ", s)
    s = re.sub(r"\\\\", " ", s)
    s = re.sub(r"~", " ", s)
    # Unify punctuation/whitespace
    s = re.sub(r"[‐-―\-]", "-", s)     # dashes
    s = re.sub(r"[^a-z0-9\s\-\+\=/\.\^]", " ", s)
    s = re.sub(r"\s+", " ", s).strip()
    return s


def fingerprint(q: dict) -> str:
    stem = normalize(q.get("question_latex", ""))
    opts = q.get("options") or {}
    # options can be dict {A:..,B:..,C:..,D:..} or list — normalize and SORT
    # so that option-reordering between papers still collides
    if isinstance(opts, dict):
        opt_texts = [opts.get(k, "") for k in sorted(opts.keys())]
    elif isinstance(opts, list):
        opt_texts = list(opts)
    else:
        opt_texts = []
    norm_opts = sorted(normalize(str(o)) for o in opt_texts if o)
    # filter empties
    norm_opts = [o for o in norm_opts if o]
    return stem + " || " + " | ".join(norm_opts)


def main():
    data = json.loads(DATA.read_text())
    buckets: dict[str, list[dict]] = defaultdict(list)
    skipped_empty = 0

    for q in data:
        fp = fingerprint(q)
        if len(fp) < 30:        # too short to fingerprint meaningfully
            skipped_empty += 1
            continue
        buckets[fp].append(q)

    clusters = [items for items in buckets.values() if len(items) > 1]
    clusters.sort(key=lambda c: -len(c))

    cross_year_clusters = []
    same_year_clusters = []
    for c in clusters:
        years = {(q.get("exam"), q.get("year")) for q in c}
        entry = {
            "size": len(c),
            "exam_years": sorted({f"{q.get('exam')} {q.get('year')}" for q in c}),
            "subject": c[0].get("subject"),
            "members": [
                {
                    "id": q.get("id"),
                    "exam": q.get("exam"),
                    "year": q.get("year"),
                    "qno": q.get("question_number"),
                    "subject": q.get("subject"),
                    "topic": q.get("topic"),
                    "answer_key": q.get("answer_key"),
                    "question_preview": (q.get("question_latex") or "")[:200],
                }
                for q in c
            ],
        }
        if len(years) > 1:
            cross_year_clusters.append(entry)
        else:
            same_year_clusters.append(entry)

    by_subject = defaultdict(int)
    for entry in cross_year_clusters:
        by_subject[entry["subject"]] += entry["size"] - 1  # extra copies

    report = {
        "total_questions": len(data),
        "fingerprinted": len(data) - skipped_empty,
        "skipped_short_fingerprint": skipped_empty,
        "unique_fingerprints": len(buckets),
        "duplicate_clusters_total": len(clusters),
        "cross_year_clusters": len(cross_year_clusters),
        "same_year_clusters": len(same_year_clusters),
        "extra_copies_by_subject": dict(by_subject),
        "cross_year_clusters_detail": cross_year_clusters,
        "same_year_clusters_detail": same_year_clusters,
    }

    OUT.write_text(json.dumps(report, indent=2, ensure_ascii=False))

    print(f"Total Qs:                 {report['total_questions']}")
    print(f"Fingerprinted:            {report['fingerprinted']}")
    print(f"Skipped (short):          {report['skipped_short_fingerprint']}")
    print(f"Unique fingerprints:      {report['unique_fingerprints']}")
    print(f"Duplicate clusters:       {report['duplicate_clusters_total']}")
    print(f"  cross-year clusters:    {report['cross_year_clusters']}")
    print(f"  same-year clusters:     {report['same_year_clusters']}")
    print(f"Extra copies by subject:  {report['extra_copies_by_subject']}")
    print(f"Report:                   {OUT.relative_to(ROOT)}")


if __name__ == "__main__":
    main()
