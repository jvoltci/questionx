"""Normalize question/option/solution text so the TexText widget renders all
LaTeX cleanly.

Two failure modes observed in the wild:

  A. LaTeX commands appear OUTSIDE `$...$` delimiters. E.g. a question stem
     begins `\text { Match ... }` with no math delimiters around it. The
     widget treats the whole string as plain text, so the user sees the raw
     backslash command.

  B. Unbalanced `$` delimiters (odd count). The widget greedy-matches `$..$`
     so one unmatched `$` swallows everything after it into a math block that
     never closes, falling back to a red error render.

The fixes:

  - In text regions (between `$...$` / `$$...$$` math blocks), wrap each
    bare backslash command (with optional trailing `{...}` groups) in `$...$`
    so the renderer treats it as inline math.
  - If a string has an odd number of standalone `$`, strip the last lone `$`.

Idempotent: running the pass twice is a no-op since wrapped commands
already sit inside `$...$`.
"""
from __future__ import annotations

import json
import re
from pathlib import Path

REPO = Path(__file__).resolve().parents[2]
ASSETS = REPO / "assets"

# Match `$$...$$` and `$...$` math blocks (non-greedy).
_MATH_BLOCK = re.compile(r"\$\$.+?\$\$|\$.+?\$", re.DOTALL)

# A backslash command + optional brace groups, e.g. `\text{Match the LIST}`,
# `\mathrm{H}_2`, `\Rightarrow`, `\leq`. We greedily consume up to two trailing
# brace groups (covers `\frac{a}{b}` and `\xrightarrow[sub]{sup}` style with
# optional bracket arg). Bracket args are picked up too.
_CMD_PATTERN = re.compile(
    r"\\[a-zA-Z]+"           # command name
    r"(?:\s*\[[^\[\]]*\])?"  # optional [..] arg
    r"(?:\s*\{[^{}]*\}){0,2}" # 0-2 {..} args
)


def _wrap_text_region(s: str) -> str:
    """Wrap each LaTeX command found in a non-math text region in $...$.

    Adjacent commands get merged into a single $...$ block to avoid
    visual gaps from the wrapper widget."""
    if "\\" not in s:
        return s
    pieces: list[str] = []
    cursor = 0
    for m in _CMD_PATTERN.finditer(s):
        if m.start() > cursor:
            pieces.append(s[cursor:m.start()])
        pieces.append("$" + m.group(0) + "$")
        cursor = m.end()
    if cursor < len(s):
        pieces.append(s[cursor:])
    out = "".join(pieces)
    # Merge adjacent `$...$$...$` blocks separated only by whitespace into
    # one block. KaTeX renders the joined form better.
    out = re.sub(r"\$(\s*)\$", r"\1", out)
    return out


def _drop_lone_dollar(s: str) -> str:
    """If the string has an odd number of `$` after pairing `$$` first, drop
    the final lone `$`."""
    # Count `$$` blocks. The remaining `$` should pair as `$..$`.
    s_no_dd = re.sub(r"\$\$.+?\$\$", "", s, flags=re.DOTALL)
    s_no_d = re.sub(r"\$.+?\$", "", s_no_dd, flags=re.DOTALL)
    leftover = s_no_d.count("$")
    if leftover == 0:
        return s
    # Find the trailing orphan and drop it.
    # Simplest: from the right, remove `$` characters until the count works.
    out = s
    for _ in range(leftover):
        idx = out.rfind("$")
        if idx < 0:
            break
        out = out[:idx] + out[idx + 1 :]
    return out


_TRIPLE_DOLLAR = re.compile(r"\${3,}")


def normalize(s: str | None) -> str:
    if not s:
        return s or ""
    # examside occasionally fences display math with `$$$...$$$` (3+ dollars).
    # KaTeX expects `$$...$$` — collapse any run of 3+ `$` to exactly 2.
    s = _TRIPLE_DOLLAR.sub("$$", s)
    # Fix orphan `$` first so it doesn't confuse the math-block split.
    s = _drop_lone_dollar(s)
    parts: list[str] = []
    cursor = 0
    for m in _MATH_BLOCK.finditer(s):
        if m.start() > cursor:
            parts.append(_wrap_text_region(s[cursor : m.start()]))
        parts.append(m.group(0))
        cursor = m.end()
    if cursor < len(s):
        parts.append(_wrap_text_region(s[cursor:]))
    return "".join(parts)


def process(path: Path) -> dict:
    print(f"\n--- {path.name} ---")
    d = json.loads(path.read_text())
    changes = 0
    fields_changed = {"question_latex": 0, "options": 0, "solution": 0}
    for q in d:
        before_q = q.get("question_latex") or ""
        after_q = normalize(before_q)
        if after_q != before_q:
            q["question_latex"] = after_q
            fields_changed["question_latex"] += 1
            changes += 1
        opts = q.get("options") or []
        new_opts = [normalize(o) for o in opts]
        if new_opts != opts:
            q["options"] = new_opts
            fields_changed["options"] += 1
            changes += 1
        before_s = q.get("solution") or ""
        after_s = normalize(before_s)
        if after_s != before_s:
            q["solution"] = after_s
            fields_changed["solution"] += 1
            changes += 1

    path.write_text(json.dumps(d, ensure_ascii=False, indent=2))
    print(f"  records changed: {changes}")
    for k, v in fields_changed.items():
        print(f"    {k}: {v}")
    return fields_changed


def main() -> None:
    process(ASSETS / "neet.json")
    process(ASSETS / "jee.json")


if __name__ == "__main__":
    main()
