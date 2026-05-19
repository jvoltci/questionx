"""Assemble final `assets/jee.json` from the scraped questions and figure map.

Input:
  scripts/jee/out/full/questions.json   # raw scrape (with _image_urls etc.)
  scripts/jee/out/full/figure_map.json  # {qid: primary-filename}

Output:
  assets/jee.json   # NEET-schema records, internal `_` fields stripped, `question_svg`
                    # populated for Qs whose primary figure downloaded.

We also rename the primary figure on disk to `<id>.<ext>` (matching NEET convention)
and emit `scripts/jee/out/full/diagrams_jee/` as the canonical staging dir to merge
into `assets/diagrams.zip`.
"""
from __future__ import annotations

import json
import shutil
from pathlib import Path

ROOT = Path(__file__).resolve().parent
OUT = ROOT / "out" / "full"
FIG_DIR = OUT / "figures"
STAGE = OUT / "diagrams_jee"

INTERNAL_FIELDS = {"_image_urls", "_source_qid", "_paper_title"}


def main() -> None:
    questions = json.load(open(OUT / "questions.json"))
    figure_map = json.load(open(OUT / "figure_map.json"))
    STAGE.mkdir(parents=True, exist_ok=True)

    out_records = []
    figures_kept = 0
    for q in questions:
        clean = {k: v for k, v in q.items() if k not in INTERNAL_FIELDS}
        qid = q["id"]
        primary = figure_map.get(qid)
        if primary:
            src = FIG_DIR / primary
            if src.exists():
                # Canonicalize filename to <id>.<ext> mirroring NEET convention.
                ext = primary.rsplit(".", 1)[-1].lower()
                canonical = f"{qid}.{ext}"
                dest = STAGE / canonical
                if not dest.exists():
                    shutil.copy2(src, dest)
                clean["question_svg"] = canonical
                figures_kept += 1
        out_records.append(clean)

    # Write final jee.json into assets/.
    target = ROOT.parent.parent / "assets" / "jee.json"
    target.write_text(json.dumps(out_records, ensure_ascii=False, indent=2))
    print(f"Wrote {target} -- {len(out_records)} records")
    print(f"Figures linked (question_svg): {figures_kept}")
    print(f"Figures staged for zip: {len(list(STAGE.glob('*')))}")
    size_mb = target.stat().st_size / 1024 / 1024
    print(f"jee.json size: {size_mb:.1f} MB")


if __name__ == "__main__":
    main()
