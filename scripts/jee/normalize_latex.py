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

## Ordering requirement

Run `repair_dollars.py` after this pass, always. `_wrap_text_region` works on one
text region at a time, so a token it wraps at a region edge lands next to the
delimiter of the neighbouring math block. `_fuse_across_boundaries` cleans up the
runs that are still recognisable as one expression, but on input that was already
mangled upstream (bare `\\mathrm{X}` next to a stray `$`, truth-table cells with
loose `Z_{1}`) the wrap is ambiguous and can still leave an odd delimiter count.
`repair_dollars.py` is the outcome-guarded backstop for exactly that residue.

NOT idempotent on already-normalized text, despite what an earlier version of
this docstring claimed. Wrapping is not a fixed point when the input already
contains partial wrapping — ~138 fields change again on a second pass. Treat this
as a one-shot migration over fresh scrape output, not a repeatable cleanup, and
rely on the `no new swallowed-prose spans` gate in test/tex_render_test.dart to
catch a bad run.
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

# Chemical-formula / sub-sup token. Matches sequences like `C_{2}H_{5}`,
# `H_{2}O`, `(C_{2}H_{5})_{2}NH`, `x^{2}`, `Mg^{2+}`, `\mathrm{NH}_{2}`.
# Requires at least one `_{...}` or `^{...}` group so that pure English words
# never match. Allows optional alphabetic / parenthesised letters before, in
# between, and after the brace groups.
_SUBSUP_TOKEN = re.compile(
    r"(?:[A-Za-z()])?"                                  # optional starter
    r"[A-Za-z()0-9]*"                                   # body
    r"(?:[_^]\{[^{}]*\}[A-Za-z()0-9+\-]*)+"             # one or more sub/sup groups + tail
)


def _wrap_text_region(s: str) -> str:
    """Wrap each LaTeX-shaped token found in a non-math text region in $...$.

    Two token families:
      1. `\\command{...}` — flutter_math_fork won't render unless wrapped.
      2. `X_{n}` / `X^{n}` — subscript/superscript sequences (chemical
         formulas, exponents). Same problem.

    Adjacent wrapped tokens get merged into a single $...$ block to keep the
    visual layout tight.
    """
    if "\\" not in s and "_{" not in s and "^{" not in s:
        return s
    # Collect all match ranges (command + subsup) and merge overlaps.
    matches: list[tuple[int, int]] = []
    for m in _CMD_PATTERN.finditer(s):
        matches.append((m.start(), m.end()))
    for m in _SUBSUP_TOKEN.finditer(s):
        # Reject pure-empty matches and ones that are JUST letters with no
        # brace-group (the regex requires `[_^]\{`, but safety belt).
        if m.end() > m.start() and ("_{" in m.group(0) or "^{" in m.group(0)):
            matches.append((m.start(), m.end()))
    if not matches:
        return s
    matches.sort()
    # Merge overlapping / abutting ranges.
    merged: list[tuple[int, int]] = []
    for start, end in matches:
        if merged and start <= merged[-1][1]:
            merged[-1] = (merged[-1][0], max(merged[-1][1], end))
        else:
            merged.append((start, end))
    # Rebuild string with each range wrapped.
    pieces: list[str] = []
    cursor = 0
    for start, end in merged:
        if start > cursor:
            pieces.append(s[cursor:start])
        pieces.append("$" + s[start:end] + "$")
        cursor = end
    if cursor < len(s):
        pieces.append(s[cursor:])
    out = "".join(pieces)
    # Merge adjacent `$..$ $..$` blocks (separated only by whitespace).
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
# Match `_{...}` or `^{...}` groups where the braces contain `$` characters
# (examside source bug: e.g. `10^{$$-$$12}`). The `$` markers inside the group
# are spurious — strip them so the sub/sup parses as one math expression.
_SUBSUP_WITH_DOLLAR = re.compile(r"([_^])\{([^{}]*\$[^{}]*)\}")


def _strip_dollars_in_subsup(s: str) -> str:
    def fix(m: re.Match) -> str:
        cleaned = m.group(2).replace("$", "")
        return f"{m.group(1)}{{{cleaned}}}"
    prev = None
    cur = s
    # Run until fixed point (rarely more than 1 pass).
    while prev != cur:
        prev = cur
        cur = _SUBSUP_WITH_DOLLAR.sub(fix, cur)
    return cur


def _fuse_across_boundaries(s: str) -> str:
    """Merge a wrapped token that abuts the math block next to it.

    `_wrap_text_region` runs on each text region in isolation, so a token at the
    very start (or end) of a region abuts the `$$` of the neighbouring math
    block: `"$$\\omega$$" + "$_{r}$"` -> `"$$\\omega$$$_{r}$"`. Those are one
    expression, so fuse them into a single block instead of leaving a stray run
    of delimiters behind.

    Without this the run survives to the output, and wherever it makes the
    effective delimiter count odd the widget opens a span that swallows the prose
    up to the next `$$` — see scripts/jee/repair_dollars.py.
    """
    prev = None
    while prev != s:
        prev = s
        # `$$A$$` `$B$` -> `$$AB$$`   (and the `$A$` `$$B$$` mirror image)
        s = re.sub(r"\$\$([^$]*)\$\$\$([^$]*)\$(?!\$)", r"$$\1\2$$", s)
        s = re.sub(r"(?<!\$)\$([^$]*)\$\$\$([^$]*)\$\$", r"$$\1\2$$", s)
        # `$A$` `$B$` written as `$A$$B$` -> `$AB$`
        s = re.sub(r"(?<!\$)\$([^$]*)\$\$([^$]*)\$(?!\$)", r"$$\1\2$$", s)
    return s


def normalize(s: str | None) -> str:
    if not s:
        return s or ""
    # examside occasionally fences display math with `$$$...$$$` (3+ dollars).
    # KaTeX expects `$$...$$` — collapse any run of 3+ `$` to exactly 2.
    s = _TRIPLE_DOLLAR.sub("$$", s)
    # Pull spurious `$` chars out of `_{...}` / `^{...}` groups — these are
    # source-data artifacts (e.g. `10^{$$-$$12}` from examside HTML conversion)
    # that would otherwise split the sub/sup across math/text boundaries and
    # leak raw `^{12}` into the rendered text.
    s = _strip_dollars_in_subsup(s)
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
    out = "".join(parts)
    # Wrapping happens per text region, so delimiter runs can only appear now, at
    # the seams. Clean them here — collapsing at the top of the pass (above) runs
    # before any wrapping and therefore never sees them. This is also what makes
    # the pass genuinely idempotent.
    out = _fuse_across_boundaries(out)
    return _TRIPLE_DOLLAR.sub("$$", out)


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
