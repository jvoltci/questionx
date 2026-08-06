"""Apply verified fixes to questions reported by users.

Every entry was checked against an external source AND cross-checked by
recomputing the answer against the stored answer_key/solution. Sources and the
independent check are recorded per question. Nothing is inferred.

Run:  python3 scripts/jee/fix_reported.py --apply
Then: dart run tool/encrypt_assets.dart
"""
from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

REPO = Path(__file__).resolve().parents[2]
ASSETS = REPO / "assets"

# (bank, id, {field: new_value}, why)
FIXES = [
    (
        "neet",
        "NEET_2024_Zoo_184",
        {
            "question_latex": (
                "Match List I with List II\n"
                "List I\n"
                "A. Non-medicated IUD\n"
                "B. Copper releasing IUD\n"
                "C. Hormone releasing IUD\n"
                "D. Implants\n"
                "List II\n"
                "I. Multiload 375\n"
                "II. Progestogens\n"
                "III. Lippes loop\n"
                "IV. LNG-20\n"
                "Choose the correct answer from the options given below :"
            ),
            "options": [
                "A-III, B-I, C-II, D-IV",
                "A-I, B-III, C-IV, D-II",
                "A-IV, B-I, C-II, D-III",
                "A-III, B-I, C-IV, D-II",
            ],
            "answer_key": "D",
            "solution": (
                "Non-medicated IUD — Lippes loop, an inert plastic device that "
                "releases nothing.\n\n"
                "Copper releasing IUD — Multiload 375, which carries copper wire "
                "that releases Cu ions.\n\n"
                "Hormone releasing IUD — LNG-20, which releases levonorgestrel "
                "into the uterus.\n\n"
                "Implants — Progestogens, implanted under the skin.\n\n"
                "Hence A-III, B-I, C-IV, D-II."
            ),
        },
        # Reported: "Question text typo / unclear". The record was not merely
        # unclear -- it was fabricated. It carried an LLM's own deliberation as
        # question text ("(Note: 'Parabolic' is typo in options? No, likely
        # 'Vaults' ... Let's check options)"), invented a fourth List I entry
        # "Parabolic IUD", dropped the real one (Implants), listed Progestasert
        # instead of LNG-20/Progestogens, and offered only 3-pair options so the
        # official answer was not among them.
        # Verified: testbook.com quotes all four options verbatim with option 4
        # correct; shaalaa.com and neetprep list the same List I/List II pairs.
        # Check: NCERT -- Lippes loop is the non-medicated IUD, Multiload 375 the
        # copper-releasing one, LNG-20 the hormone-releasing one, progestogens
        # the implant. So A-III, B-I, C-IV, D-II = option 4 = "D".
        "fabricated record: LLM deliberation as question text, wrong list, "
        "answer not among the options",
    ),
    (
        "jee",
        "JEE_Main_2022_Jun30_S1_Chem_17",
        {
            "options": [
                "O > S > Se > Te",
                "O < S < Se < Te",
                "O < S > Se > Te",
                "O < S > Se < Te",
            ],
        },
        # Reported: "Option text typo". Options C and D read "O Se > Te" and
        # "O Se < Te" -- each missing a term. Cause is the scrape's HTML tag
        # stripper: in "O < S > Se > Te" the substring "< S >" looks like a tag
        # and was removed, leaving exactly "O  Se > Te".
        # Verified: examside/byjus give the four options as
        # O > S > Se > Te / O < S < Se < Te / O < S > Se > Te / O < S > Se < Te
        # with C correct -- matching the stored answer_key.
        # Check: magnitudes of negative electron gain enthalpy are
        # S 200 > Se 195 > Te 190 > O 141 kJ/mol, i.e. O < S > Se > Te.
        "options C and D lost a term to the scrape's HTML tag stripper",
    ),
    (
        "jee",
        "JEE_Main_2024_Apr04_S2_Chem_22",
        {
            "question_latex": (
                "Given below are two statements :\n\n"
                "Statement I : The correct order of first ionization enthalpy "
                "values of $$\\mathrm{Li}, \\mathrm{Na}, \\mathrm{F}$$ and "
                "$$\\mathrm{Cl}$$ is $$\\mathrm{Na} < \\mathrm{Li} < "
                "\\mathrm{Cl} < \\mathrm{F}$$.\n\n"
                "Statement II : The correct order of negative electron gain "
                "enthalpy values of $$\\mathrm{Li}, \\mathrm{Na}, \\mathrm{F}$$ "
                "and $$\\mathrm{Cl}$$ is $$\\mathrm{Na} < \\mathrm{Li} < "
                "\\mathrm{F} < \\mathrm{Cl}$$.\n\n"
                "In the light of the above statements, choose the correct "
                "answer from the options given below :"
            ),
        },
        # Reported: "Question text typo / unclear". Both comparison chains were
        # deleted by the same HTML tag stripper -- everything from the first `<`
        # onward vanished, so Statement I ended at "is Na" and ran straight into
        # "Statement II".
        # Verified: the ALLEN answer-key PDF for 04/04/2024 evening and other
        # papers give Statement I as Na < Li < Cl < F and Statement II as
        # Na < Li < F < Cl, both true.
        # Check: first IE (kJ/mol) Na 496 < Li 520 < Cl 1251 < F 1681. Negative
        # electron gain enthalpy magnitudes Na 53 < Li 60 < F 328 < Cl 349. Both
        # statements hold -> "Both ... are true" = stored answer_key "D".
        "both comparison chains deleted by the scrape's HTML tag stripper",
    ),
]


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--apply", action="store_true")
    args = ap.parse_args()

    by_bank: dict[str, list] = {}
    for bank, qid, fields, why in FIXES:
        by_bank.setdefault(bank, []).append((qid, fields, why))

    for bank, items in by_bank.items():
        path = ASSETS / f"{bank}.json"
        data = json.loads(path.read_text())
        index = {q["id"]: q for q in data}
        for qid, fields, why in items:
            q = index.get(qid)
            if q is None:
                sys.exit(f"{qid} not found in {bank}.json")
            for field, value in fields.items():
                q[field] = value
            # An MCQ's key must name one of its options.
            key = q.get("answer_key")
            opts = q.get("options") or []
            if opts and key and len(key) == 1 and key.isalpha():
                idx = ord(key.upper()) - 65
                if not 0 <= idx < len(opts):
                    sys.exit(f"{qid}: answer_key {key!r} outside {len(opts)} options")
            print(f"  [{'apply' if args.apply else 'dry'}] {qid}: {why}")
        if args.apply:
            path.write_text(json.dumps(data, ensure_ascii=False, indent=2))
            print(f"  wrote {path}")

    print("\ndry run OK" if not args.apply else "\nnext: dart run tool/encrypt_assets.dart")


if __name__ == "__main__":
    main()
