"""Repair pass over assets/jee.json and assets/neet.json.

Two purposes:

1) Strip residual HTML/MathML tags left over from the scraper's html_to_text
   conversion. The original conversion handled common tags but missed the
   MathML family (<mrow>, <mi>, <mn>, etc.) that examside uses inside
   "match-the-list" questions, plus some stray <br> in NEET data.

2) Drop records that have FATAL render issues — empty question text with no
   diagram, MCQ with empty/duplicate/wrong-count options, MCQ with no
   answer_key, etc. These are records the user couldn't meaningfully answer
   regardless of how well we render them.

Output overwrites assets/<file>.json with a backup at
   assets/<file>.json.backup.cleanup
and writes a cleanup_report.json summarising what was changed.
"""
from __future__ import annotations

import json
import re
from collections import Counter
from pathlib import Path

REPO = Path(__file__).resolve().parents[2]
ASSETS = REPO / "assets"

# Remove any residual HTML/MathML tags. Conservative — only strips tags, not
# their text content. After this pass, no `<...>` substring should remain in
# rendered fields.
_TAG_RE = re.compile(r"<[a-zA-Z!/][^>]*>")
# Collapse 3+ blank lines that result from tag-stripping.
_BLANK_RE = re.compile(r"\n{3,}")
# Collapse leftover whitespace runs (but preserve single newlines).
_WS_RE = re.compile(r"[ \t]{2,}")


def strip_tags(s: str | None) -> str:
    if not s:
        return s or ""
    out = _TAG_RE.sub("", s)
    out = _BLANK_RE.sub("\n\n", out)
    out = _WS_RE.sub(" ", out)
    return out.strip()


_MATH_BLOCK_RE = re.compile(r"\$\$.+?\$\$|\$.+?\$", re.DOTALL)
_LATEX_LEAK_RE = re.compile(
    r"\\[a-zA-Z]+|_\{[^{}]*\}|\^\{[^{}]*\}"
)


def _has_latex_leak(s: str | None) -> bool:
    """True if `s` contains LaTeX-shaped tokens OUTSIDE `$...$` delimiters
    (i.e., raw `\\frac`, `_{...}`, `^{...}` that would render as plain text)."""
    if not s:
        return False
    return bool(_LATEX_LEAK_RE.search(_MATH_BLOCK_RE.sub("", s)))


def is_fatal(q: dict) -> str | None:
    """Return a short reason if the record should be dropped, else None."""
    qt = q.get("question_type", "mcq")
    qtxt = (q.get("question_latex") or "").strip()
    has_diagram = bool(q.get("question_svg"))
    opts = q.get("options") or []
    ans = (q.get("answer_key") or "").strip()
    sol = (q.get("solution") or "").strip()

    if not qtxt and not has_diagram:
        return "empty_question_and_no_diagram"
    if not sol:
        # Trust rule: don't ship a question without a worked solution.
        return "missing_solution"
    # Render rule: drop any record whose displayed text contains raw LaTeX
    # tokens outside `$...$` (e.g. `\frac`, `^{2}`, `_{0}`). These render as
    # plain text in the app and make it look broken.
    if _has_latex_leak(qtxt):
        return "latex_leak_in_question"
    if _has_latex_leak(sol):
        return "latex_leak_in_solution"
    for o in opts:
        if _has_latex_leak(o):
            return "latex_leak_in_options"
    if qt == "mcq":
        if len(opts) != 4:
            return f"options_count_{len(opts)}"
        if any(not (o or "").strip() for o in opts):
            return "empty_option"
        if len(set(opts)) < 4:
            return "duplicate_options"
        if not ans:
            return "no_answer_key"
        if ans not in ("A", "B", "C", "D") and "," not in ans:
            return "answer_key_not_letter"
    elif qt == "integer":
        if not ans:
            return "integer_no_answer"
    return None


def clean_record(q: dict) -> dict:
    """Strip residual tags from text fields in place; return updated record."""
    out = dict(q)
    out["question_latex"] = strip_tags(q.get("question_latex"))
    out["solution"] = strip_tags(q.get("solution"))
    opts = q.get("options") or []
    out["options"] = [strip_tags(o) for o in opts]
    return out


def process(file_label: str, path: Path, drop_fatals: bool, report: dict) -> None:
    print(f"\n--- {file_label} ({path.name}) ---")
    raw = json.loads(path.read_text())
    print(f"  in:  {len(raw)} records")

    # Backup once per run.
    backup = path.with_suffix(path.suffix + ".backup.cleanup")
    if not backup.exists():
        backup.write_text(path.read_text())
        print(f"  backup -> {backup.name}")

    cleaned = [clean_record(q) for q in raw]
    reasons: Counter[str] = Counter()
    kept = []
    for q in cleaned:
        reason = is_fatal(q)
        if reason and drop_fatals:
            reasons[reason] += 1
            continue
        kept.append(q)

    print(f"  out: {len(kept)} records  (-{len(raw) - len(kept)})")
    if reasons:
        for k, v in reasons.most_common():
            print(f"      dropped {v:5} for {k}")
    path.write_text(json.dumps(kept, ensure_ascii=False, indent=2))
    report[file_label] = {
        "input_count": len(raw),
        "output_count": len(kept),
        "dropped_reasons": dict(reasons),
    }


def main() -> None:
    report: dict = {}
    # Both files: tag-strip + drop any record with a fatal render-blocking
    # issue. NEET loses ~2 records (out of 5056); JEE loses ~1720 records
    # (mostly old IIT-JEE subjective questions miscategorized as MCQ).
    process("NEET", ASSETS / "neet.json", drop_fatals=True, report=report)
    process("JEE",  ASSETS / "jee.json",  drop_fatals=True, report=report)

    (REPO / "scripts" / "jee" / "out" / "full" / "cleanup_report.json").write_text(
        json.dumps(report, indent=2)
    )
    print("\nWrote cleanup_report.json")


if __name__ == "__main__":
    main()
