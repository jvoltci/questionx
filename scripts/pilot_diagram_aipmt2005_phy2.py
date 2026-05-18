#!/usr/bin/env python3
"""Pilot: replace question_svg for AIPMT_2005_Phy_2 with the OFFICIAL
published circuit diagram, sourced from tardigrade.in (trusted reproduction).

The PNG is base64-embedded inside a minimal SVG <image> wrapper so the
existing `SvgPicture.string(q.questionSvg)` rendering path in
quiz_screen / review_screen / detail_screen works unchanged.

Run from project root:  python3 scripts/pilot_diagram_aipmt2005_phy2.py
"""
import base64
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
DATA = ROOT / "assets" / "neet.json"
IMG = Path("/tmp/qx_diagrams/aipmt2005_phy2.jpg")  # PNG content despite ext
QID = "AIPMT_2005_Phy_2"


def main():
    if not IMG.exists():
        raise SystemExit(f"Image not found at {IMG}. Download it first.")
    raw = IMG.read_bytes()
    # The file is PNG bytes despite the .jpg name (verified via `file`)
    b64 = base64.b64encode(raw).decode("ascii")
    # Original PNG dimensions: 257 x 175
    svg = (
        '<svg xmlns="http://www.w3.org/2000/svg" '
        'xmlns:xlink="http://www.w3.org/1999/xlink" '
        'viewBox="0 0 257 175" preserveAspectRatio="xMidYMid meet">'
        f'<image width="257" height="175" '
        f'xlink:href="data:image/png;base64,{b64}"/>'
        "</svg>"
    )

    data = json.loads(DATA.read_text())
    found = False
    for q in data:
        if q.get("id") == QID:
            q["question_svg"] = svg
            found = True
            break
    if not found:
        raise SystemExit(f"Question {QID} not found in dataset")

    DATA.write_text(json.dumps(data, indent=2, ensure_ascii=False))
    print(f"Embedded {len(raw):,} bytes of PNG ({len(b64):,} base64 chars) "
          f"into question_svg of {QID}.")
    print(f"Total SVG length: {len(svg):,} chars.")


if __name__ == "__main__":
    main()
