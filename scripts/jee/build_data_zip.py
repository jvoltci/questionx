"""Assemble the OTA `data.zip` artifact for a GitHub release.

Layout (matches SyncService._downloadAndSync / _downloadDiagramsOnly):

    neet.json.enc              -- encrypted NEET bank, copied from assets/
    jee.json.enc               -- encrypted JEE bank, copied from assets/
    diagrams/<qid>.jpg|png|...  -- every figure both banks reference

Diagrams are deliberately NOT bundled in the APK (see pubspec.yaml); the app
pulls them from this artifact on first launch, so a figure missing here renders
as "Error loading diagram" in the app.

## Why this script asserts coverage

v1.7.3 and v1.7.4 shipped with **zero NEET diagrams** — all 143 NEET questions
with a figure showed "Error loading diagram". The previous version of this
script sourced them from a hard-coded `/tmp/v41_release/data.zip`. When /tmp was
cleared, that loop simply iterated over nothing, printed "NEET: 0 files", and
the release went out JEE-only. Nothing failed.

So: diagrams now come from the previous release (fetched by tag, cached), and
the build **fails** unless every filename referenced by either bank is present
in the output. A silent zero is no longer possible.

Usage:
    python3 scripts/jee/build_data_zip.py                  # base on latest release
    python3 scripts/jee/build_data_zip.py --base v1.6.0    # base on a specific tag
    python3 scripts/jee/build_data_zip.py --extra-figures DIR

Output:
    scripts/jee/out/release/data.zip
"""
from __future__ import annotations

import argparse
import json
import subprocess
import sys
import zipfile
from pathlib import Path

REPO = Path(__file__).resolve().parents[2]
ASSETS = REPO / "assets"
OUT_DIR = REPO / "scripts" / "jee" / "out" / "release"
OUT_ZIP = OUT_DIR / "data.zip"
CACHE = OUT_DIR / "base"

REPO_SLUG = "jvoltci/questionx"
BANKS = ("neet.json.enc", "jee.json.enc")
IMAGE_SUFFIXES = {".jpg", ".jpeg", ".png", ".webp", ".gif"}


def referenced_filenames() -> dict[str, set[str]]:
    """Every diagram filename the plaintext banks point at, per bank.

    Reads the plaintext `assets/*.json` (gitignored local source) because the
    encrypted banks cannot be introspected from Python.
    """
    out: dict[str, set[str]] = {}
    for bank in ("neet", "jee"):
        path = ASSETS / f"{bank}.json"
        if not path.exists():
            sys.exit(f"missing {path} — needed to verify diagram coverage")
        refs: set[str] = set()
        for q in json.loads(path.read_text()):
            for field in ("question_svg", "solution_svg"):
                v = q.get(field)
                # Legacy inline `<svg>...</svg>` blobs are rendered from the
                # record itself and need no file.
                if v and not v.strip().startswith("<"):
                    refs.add(v)
        out[bank] = refs
    return out


def fetch_base(tag: str | None) -> Path:
    """Download a previous release's data.zip to use as the diagram source."""
    CACHE.mkdir(parents=True, exist_ok=True)
    label = tag or "latest"
    dest = CACHE / f"data-{label}.zip"
    if dest.exists():
        print(f"  base: {dest} (cached)")
        return dest
    ref = ["--repo", REPO_SLUG, "--pattern", "data.zip", "--dir", str(CACHE)]
    cmd = ["gh", "release", "download"] + ([tag] if tag else []) + ref
    print(f"  base: downloading data.zip from {label} …")
    subprocess.run(cmd, check=True)
    (CACHE / "data.zip").rename(dest)
    return dest


def family(name: str) -> str:
    return "JEE" if name.startswith("JEE") else "NEET"


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--base", help="release tag to take diagrams from (default: latest)")
    ap.add_argument("--extra-figures", type=Path,
                    help="directory of newly generated figures to add/override")
    args = ap.parse_args()

    needed = referenced_filenames()
    all_needed = needed["neet"] | needed["jee"]
    print(f"banks reference {len(all_needed)} diagrams "
          f"({len(needed['neet'])} NEET + {len(needed['jee'])} JEE)")

    base_zip = fetch_base(args.base)
    OUT_DIR.mkdir(parents=True, exist_ok=True)
    OUT_ZIP.unlink(missing_ok=True)

    written: set[str] = set()
    counts = {"JEE": 0, "NEET": 0}

    with zipfile.ZipFile(OUT_ZIP, "w", zipfile.ZIP_DEFLATED, compresslevel=6) as out:
        for bank in BANKS:
            src = ASSETS / bank
            if not src.exists():
                sys.exit(f"missing {src} — run `dart run tool/encrypt_assets.dart`")
            out.write(src, arcname=bank)
            print(f"  + {bank} ({src.stat().st_size / 1e6:.2f} MB)")

        # Newly generated figures win over the base release.
        if args.extra_figures:
            for f in sorted(args.extra_figures.iterdir()):
                if not f.is_file() or f.suffix.lower() not in IMAGE_SUFFIXES:
                    continue
                out.write(f, arcname=f"diagrams/{f.name}")
                written.add(f.name)
                counts[family(f.name)] += 1
            print(f"  + diagrams/ new: {len(written)} files")

        with zipfile.ZipFile(base_zip) as base:
            for info in base.infolist():
                if info.is_dir() or not info.filename.startswith("diagrams/"):
                    continue
                name = info.filename.split("/", 1)[1]
                if not name or name in written:
                    continue
                out.writestr(info.filename, base.read(info.filename))
                written.add(name)
                counts[family(name)] += 1

    print(f"  + diagrams/ total: {counts['JEE']} JEE + {counts['NEET']} NEET "
          f"= {sum(counts.values())}")

    # The guard. A missing figure is a broken question in the shipped app, so
    # this is fatal, not a warning.
    missing = sorted(all_needed - written)
    if missing:
        OUT_ZIP.unlink(missing_ok=True)
        print(f"\nFAIL: {len(missing)} referenced diagram(s) absent from data.zip:",
              file=sys.stderr)
        for m in missing[:20]:
            print(f"    {m}", file=sys.stderr)
        if len(missing) > 20:
            print(f"    … and {len(missing) - 20} more", file=sys.stderr)
        sys.exit(f"\nrefusing to write a data.zip that breaks {len(missing)} questions")

    print(f"\nWrote {OUT_ZIP}  ({OUT_ZIP.stat().st_size / 1e6:.1f} MB)")
    print(f"  every one of the {len(all_needed)} referenced diagrams is present")


if __name__ == "__main__":
    main()
