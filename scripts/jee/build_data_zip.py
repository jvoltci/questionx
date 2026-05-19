"""Assemble the OTA `data.zip` artifact for the v1.1.0+6 release.

Layout (matches SyncService._downloadAndSync expectations):
    neet.json                  -- 3.9 MB, copied from assets/neet.json
    jee.json                   -- 8.2 MB, copied from assets/jee.json
    diagrams/<qid>.jpg|.png    -- 159 NEET (from v4.1) + 1674 JEE (this release)

Inputs:
    /tmp/v41_release/data.zip  -- existing v4.1 release (NEET diagrams source)
    assets/neet.json           -- fresh NEET JSON
    assets/jee.json            -- fresh JEE JSON (just assembled)
    scripts/jee/out/full/diagrams_jee/  -- 1674 JEE figures named <qid>.png

Output:
    scripts/jee/out/release/data.zip
"""
from __future__ import annotations

import zipfile
from pathlib import Path

REPO = Path(__file__).resolve().parents[2]
ASSETS = REPO / "assets"
JEE_FIG_DIR = REPO / "scripts" / "jee" / "out" / "full" / "diagrams_jee"
V41_ZIP = Path("/tmp/v41_release/data.zip")
OUT_DIR = REPO / "scripts" / "jee" / "out" / "release"
OUT_ZIP = OUT_DIR / "data.zip"


def main() -> None:
    OUT_DIR.mkdir(parents=True, exist_ok=True)
    if OUT_ZIP.exists():
        OUT_ZIP.unlink()

    neet_count = 0
    jee_count = 0
    json_count = 0

    with zipfile.ZipFile(OUT_ZIP, "w", zipfile.ZIP_DEFLATED, compresslevel=6) as out:
        # 1. JSON datasets at root.
        for fname in ("neet.json", "jee.json"):
            src = ASSETS / fname
            out.write(src, arcname=fname)
            json_count += 1
            size = src.stat().st_size
            print(f"  + {fname} ({size/1024/1024:.2f} MB)")

        # 2. NEET diagrams from v4.1 release zip.
        with zipfile.ZipFile(V41_ZIP, "r") as v41:
            for info in v41.infolist():
                if not info.filename.startswith("diagrams/"):
                    continue
                if info.is_dir():
                    continue
                out.writestr(info.filename, v41.read(info.filename))
                neet_count += 1
        print(f"  + diagrams/ NEET: {neet_count} files")

        # 3. JEE diagrams from local stage.
        for f in sorted(JEE_FIG_DIR.iterdir()):
            if not f.is_file():
                continue
            out.write(f, arcname=f"diagrams/{f.name}")
            jee_count += 1
        print(f"  + diagrams/ JEE:  {jee_count} files")

    size_mb = OUT_ZIP.stat().st_size / 1024 / 1024
    print()
    print(f"Wrote {OUT_ZIP}")
    print(f"  total: {json_count} JSONs + {neet_count + jee_count} diagrams "
          f"({neet_count} NEET + {jee_count} JEE)")
    print(f"  size:  {size_mb:.1f} MB")


if __name__ == "__main__":
    main()
