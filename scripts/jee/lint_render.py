"""Hard lint: after normalize+cleanup, no record should have LaTeX-shaped
content sitting OUTSIDE `$...$` delimiters. This script enumerates every
remaining offender across question_latex, options, and solution.

If this script reports zero offenders, the dataset is safe to ship as far
as plain-text-leak-of-LaTeX is concerned. Render errors caused by KaTeX
not supporting a specific command are a separate problem (rare; only ~10
records have those).
"""
from __future__ import annotations

import json
import re
from collections import Counter
from pathlib import Path

REPO = Path(__file__).resolve().parents[2]
ASSETS = REPO / "assets"

MATH_BLOCK = re.compile(r"\$\$.+?\$\$|\$.+?\$", re.DOTALL)
# Catch any LaTeX-shaped token outside math:
#   - backslash command:           `\frac`, `\mathrm`, `\Rightarrow`
#   - subscript / superscript:     `_{...}`, `^{...}`
#   - LaTeX environment markers:   `\begin{...}`, `\end{...}` (special case of \cmd)
LATEX_LEAK = re.compile(
    r"\\[a-zA-Z]+|"           # \command
    r"_\{[^{}]*\}|"           # _{...}
    r"\^\{[^{}]*\}"           # ^{...}
)


def leaks(s: str) -> list[str]:
    if not s:
        return []
    stripped = MATH_BLOCK.sub("", s)
    return LATEX_LEAK.findall(stripped)


def audit(path: Path) -> tuple[int, int]:
    print(f"\n--- {path.name} ---")
    d = json.loads(path.read_text())
    by_field: Counter[str] = Counter()
    sample_ids: dict[str, list[str]] = {}
    bad_ids: set[str] = set()
    for q in d:
        qid = q["id"]
        for field, value in (
            ("question_latex", q.get("question_latex") or ""),
            ("solution", q.get("solution") or ""),
        ):
            for tok in leaks(value):
                by_field[f"{field}:{tok[:15]}"] += 1
                sample_ids.setdefault(field, []).append(qid)
                bad_ids.add(qid)
        for opt in q.get("options") or []:
            for tok in leaks(opt):
                by_field[f"options:{tok[:15]}"] += 1
                sample_ids.setdefault("options", []).append(qid)
                bad_ids.add(qid)

    if not by_field:
        print("  CLEAN.  No LaTeX leakage in any record.")
        return len(d), 0

    print(f"  Records with leakage: {len(bad_ids)} / {len(d)} ({100*len(bad_ids)/len(d):.2f}%)")
    print("  Top leak tokens by (field:token):")
    for k, v in by_field.most_common(15):
        print(f"    {k:40} {v}")
    print("  Sample offending IDs:")
    for field, ids in sample_ids.items():
        print(f"    {field}: {ids[:5]}")
    return len(d), len(bad_ids)


def main() -> None:
    total = 0
    bad = 0
    for name in ("neet.json", "jee.json"):
        n, b = audit(ASSETS / name)
        total += n
        bad += b
    print(f"\n=== SUMMARY ===")
    print(f"  total records: {total}")
    print(f"  records with leaks: {bad}  ({100*bad/total:.2f}%)")


if __name__ == "__main__":
    main()
