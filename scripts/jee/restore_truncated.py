"""Restore question text that an upstream scrape bug deleted.

The examside scrape dropped everything after a bare `<`, cutting statements
mid-comparison. That content is absent from `assets/*.json.backup.cleanup` too,
so it is upstream and cannot be recovered by any render-time pass — unlike the
malformed-LaTeX defects, which are handled in `lib/widgets/tex_normalize.dart`.

Each entry below was verified against an external source AND cross-checked
against the stored `answer_key`/`solution` before being written here. Sources and
the independent check are recorded per question. Nothing is inferred.

Run:  python3 scripts/jee/restore_truncated.py --apply
Then: dart run tool/encrypt_assets.dart
"""
from __future__ import annotations

import argparse
import json
import re
from pathlib import Path

REPO = Path(__file__).resolve().parents[2]
ASSETS = REPO / "assets"

# id -> (field, exact_old, new, why)
FIXES: list[tuple[str, str, str, str, str]] = [
    (
        "JEE_Main_2026_Apr02_S1_Chem_4",
        "question_latex",
        "Given below are two statements : Statement (I): The correct sequence of bond lengths in the following species is : $\\ce{O2^{+}} Statement (II): The correct sequence of number of unpaired electrons in the following species is :\n$$\\ce{O2}$ > $\\ce${$O2^{+}$} > $\\ce${$O2^{-}$} > $\\ce${$O2^{2-}$}\nIn the light of the above statements, choose the correct answer from the options given below :",
        "Given below are two statements :\n\nStatement (I) : The correct sequence of bond lengths in the following species is :\n\n$$\\mathrm{O}_2^{+} < \\mathrm{O}_2 < \\mathrm{O}_2^{-} < \\mathrm{O}_2^{2-}$$\n\nStatement (II) : The correct sequence of number of unpaired electrons in the following species is :\n\n$$\\mathrm{O}_2 > \\mathrm{O}_2^{+} > \\mathrm{O}_2^{-} > \\mathrm{O}_2^{2-}$$\n\nIn the light of the above statements, choose the correct answer from the options given below :",
        # Statement (I) was lost after `\ce{O2^{+}}`. competishun.com quotes both
        # statements verbatim and gives answer C.
        # Independent check: bond length ~ 1/bond order; O2+ 2.5, O2 2.0, O2- 1.5,
        # O2(2-) 1.0 -> Statement I true. Unpaired e-: 1, 2, 1, 0 -> O2+ > O2- is
        # false -> Statement II false. => C, which is the stored answer_key.
        # `\ce` (mhchem) is not in flutter_math's KaTeX subset and rendered via the
        # plain-text fallback, so both statements are written with \mathrm instead.
        "statement (I) sequence deleted after a bare `<`",
    ),
    (
        "JEE_Main_2026_Apr06_S2_Math_15",
        "question_latex",
        "Let $f(x)=\\left\\{\\begin{array}{ll}x^3+8 ; & xThen the number of points, where the function $g $\\circ$ f$ is discontinuous, is $\\_\\_\\_\\_ .",
        "Let $$f(x)=\\left\\{\\begin{array}{ll}x^3+8 ; & x<0 \\\\ x^2-4 ; & x \\ge 0\\end{array}\\right.$$ and $$g(x)=\\left\\{\\begin{array}{ll}(x-8)^{1/3} ; & x<0 \\\\ (x+4)^{1/2} ; & x \\ge 0\\end{array}\\right.$$\n\nThen the number of points, where the function $$g \\circ f$$ is discontinuous, is ____________.",
        # Both piecewise definitions were lost at the first `<`. Recovered from the
        # April 6 Shift 2 paper, and corroborated by this record's OWN stored
        # solution, which already contains `f(x)=x^3+8`, `f(x)=x^2-4` for x>=0 and
        # `g(y)=(y-8)^{1/3}`.
        # Independent check: g(f(x)) = x for x<-2; (x^3+12)^{1/2} on [-2,0);
        # (x^2-12)^{1/3} on [0,2); x for x>=2. Jumps at x=-2 (-2 vs 2), x=0
        # (2*sqrt3 vs -12^{1/3}) and x=2 (-2 vs 2) => 3, the stored answer_key.
        "both piecewise definitions of f and g deleted at the first `<`",
    ),
    (
        "JEE_Main_2024_Jan31_S1_Math_24",
        "question_latex",
        "For $$0 (I) If $$$\\alpha \\in$(-1,0)$$, then $$b$$ cannot be the geometric mean of $a$ and $$c$$\n\n(II) If $$$\\alpha \\in$(0,1)$$, then $$b$$ may be the geometric mean of $$a$$ and $$c",
        "For $$0 < c < b < a$$, let $$(a+b-2c)x^2 + (b+c-2a)x + (c+a-2b) = 0$$ be a quadratic equation with $$\\alpha \\ne 1$$ as one of its roots. Consider the following statements :\n\n(I) If $$\\alpha \\in (-1,0)$$, then $$b$$ cannot be the geometric mean of $$a$$ and $$c$$\n\n(II) If $$\\alpha \\in (0,1)$$, then $$b$$ may be the geometric mean of $$a$$ and $$c$$",
        # The whole stem after `For 0` was lost. Confirmed by two independent
        # sources: the ExamSIDE URL slug for this exact question reads
        # `for-0--c--b--a-let-ab-2-c-x2bc-2-a-xc...`, and askfilo.com quotes the
        # stem with `alpha != 1 as one of its roots`.
        # Independent check: the stored solution already derives
        # f(x)=(a+b-2c)x^2+(b+c-2a)x+(c+a-2b) with f(1)=0, so the roots are 1 and
        # alpha -- consistent with `alpha != 1`. Both sources give "Both (I) and
        # (II) are true", the stored answer_key B.
        "stem after `For 0` deleted at the `<` in `0 < c < b < a`",
    ),
    (
        "JEE_Adv_2015_P2_Math_16",
        "question_latex",
        "Let $${n_1}$$ and $${n_2}$$ be the number of red and black balls, respectively, in box $${\\rm I}$$. Let $${n_3}$$ and $${n_4}$$ be the number of red and black balls, respectively, in box $${\\rm I}{\\rm I}.$$\nA ball is drawn at random from box $${\\rm I}$$ and transferred to box $${\\rm I}$${$\\rm$ I}.$$ If the probability of drawing a red ball from box $${$\\rm$ I},$$ after this transfer, is $${1 $\\over$ 3},$$ then the correct option(s) with the possible values of $${n_1}$$ and $${n_2} is(are)",
        "Let $$n_1$$ and $$n_2$$ be the number of red and black balls, respectively, in box $$\\mathrm{I}$$. Let $$n_3$$ and $$n_4$$ be the number of red and black balls, respectively, in box $$\\mathrm{II}$$.\n\nA ball is drawn at random from box $$\\mathrm{I}$$ and transferred to box $$\\mathrm{II}$$. If the probability of drawing a red ball from box $$\\mathrm{I}$$, after this transfer, is $$\\frac{1}{3}$$, then the correct option(s) with the possible values of $$n_1$$ and $$n_2$$ is(are)",
        # No text was lost here -- only stray `$` mangling (`$${\rm I}$${$\rm$ I}.$$`,
        # `$${1 $\over$ 3},$$`). Wording confirmed verbatim by cracku.in: "A ball is
        # drawn at random from box I and transferred to box II. If the probability
        # of drawing a red ball from box I, after this transfer, is 1/3".
        # Independent check: P(red from box I after removing one) simplifies to
        # n1/(n1+n2) = 1/3 -> (10,20) and (3,6) qualify, (4,6) and (2,3) do not.
        # That is the stored answer_key C,D.
        "stray `$` mangled `box II`, `box I` and the fraction 1/3",
    ),
    (
        "JEE_Adv_2016_P1_Math_16",
        "question_latex",
        "In a triangle $$\\Delta $$XYZ$$, let $$x, y, z$$ be the lengths of sides opposite to the angles $$X, Y, Z$$ respectively, and $$2s = x + y + z$$.\n\nIf $${{s - x} $\\over$ 4} = {{s - y} $\\over$ 3} = {{s - z} $\\over$ 2}$$ and area of incircle of the triangle $$XYZ$$ is $${{8$\\pi$ } $\\over$ 3}, then",
        "In a triangle $$\\Delta XYZ$$, let $$x, y, z$$ be the lengths of sides opposite to the angles $$X, Y, Z$$ respectively, and $$2s = x + y + z$$.\n\nIf $$\\frac{s-x}{4} = \\frac{s-y}{3} = \\frac{s-z}{2}$$ and area of incircle of the triangle $$XYZ$$ is $$\\frac{8\\pi}{3}$$, then",
        # No text lost -- stray `$` around `\over`/`\pi`, plus `$$\Delta $$XYZ$$`
        # splitting the triangle name and leaving the tail with no closing `$$`.
        # Independent check against the stored solution: s=9k, x=5k, y=6k, z=7k and
        # pi*r^2 = (24/9)pi k^2 = 8pi/3 gives k=1, sides 5,6,7 -- exactly what the
        # stored solution derives, and its answer_key A,C,D.
        "stray `$` around \\over and \\pi; `\\Delta` split from XYZ",
    ),
]


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--apply", action="store_true")
    args = ap.parse_args()

    path = ASSETS / "jee.json"
    raw = path.read_text()
    applied, missing = 0, []

    for qid, field, old, new, why in FIXES:
        # Replace the exact serialized form so formatting is preserved and a stale
        # expectation fails loudly instead of silently matching nothing.
        old_ser = json.dumps(old, ensure_ascii=False)
        new_ser = json.dumps(new, ensure_ascii=False)
        if old_ser not in raw:
            missing.append(qid)
            continue
        if raw.count(old_ser) != 1:
            raise SystemExit(f"{qid}: expected exactly 1 occurrence, got {raw.count(old_ser)}")
        raw = raw.replace(old_ser, new_ser)
        applied += 1
        print(f"  [{'apply' if args.apply else 'dry'}] {qid}: {why}")

    if missing:
        raise SystemExit(f"NOT FOUND (already fixed, or text drifted): {missing}")

    # Sanity: the file must still parse and keep every record.
    data = json.loads(raw)
    assert len(data) == 14786, f"record count changed: {len(data)}"
    by_id = {q["id"]: q for q in data}
    for qid, field, _old, new, _why in FIXES:
        assert by_id[qid][field] == new, f"{qid}: {field} not written"
        assert "$$$" not in by_id[qid][field], f"{qid}: left a stray delimiter run"
        n = by_id[qid][field].count("$")
        assert n % 2 == 0, f"{qid}: odd delimiter count ({n})"

    if args.apply:
        path.write_text(raw)
        print(f"\nwrote {path} ({applied} questions restored)")
        print("next: dart run tool/encrypt_assets.dart")
    else:
        print(f"\ndry run OK ({applied} questions would be restored)")


if __name__ == "__main__":
    main()
