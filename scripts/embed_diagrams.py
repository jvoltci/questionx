#!/usr/bin/env python3
"""Reusable diagram-embed pipeline.

Reads scripts/diagram_sources.json (a map of question_id -> source_image_url),
downloads each image, base64-encodes it inside a minimal SVG <image> wrapper,
and writes back into assets/neet.json's question_svg field for each Q.

Run from project root:
    python3 scripts/embed_diagrams.py

The diagram_sources.json file accumulates across sessions, so re-running is safe
(only Qs whose question_svg is currently null are processed). To re-download or
overwrite, set FORCE=1.

JSON shape:
    {
      "AIPMT_2005_Phy_2": {
        "image_url": "https://cdn.tardigrade.in/.../q.jpg",
        "source_page": "https://tardigrade.in/question/..."
      },
      ...
    }
"""
import base64
import json
import os
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
DATA = ROOT / "assets" / "neet.json"
SOURCES = ROOT / "scripts" / "diagram_sources.json"
CACHE_DIR = Path("/tmp/qx_diagrams")
CACHE_DIR.mkdir(parents=True, exist_ok=True)

FORCE = os.environ.get("FORCE") == "1"


def detect_mime(blob: bytes) -> str:
    if blob.startswith(b"\x89PNG"):
        return "image/png"
    if blob.startswith(b"\xff\xd8\xff"):
        return "image/jpeg"
    if blob.startswith(b"GIF8"):
        return "image/gif"
    if blob.startswith(b"<svg") or blob.lstrip().startswith(b"<svg"):
        return "image/svg+xml"
    return "image/png"  # default — most NEET diagram reproductions are PNG


def detect_size(blob: bytes, mime: str) -> tuple[int, int]:
    """Quick width/height detection for the wrapper viewBox."""
    if mime == "image/png" and len(blob) >= 24:
        import struct
        w, h = struct.unpack(">II", blob[16:24])
        return int(w), int(h)
    if mime == "image/jpeg":
        # Walk JPEG segments to find SOFx
        i = 2
        while i < len(blob) - 8:
            if blob[i] != 0xFF:
                i += 1
                continue
            marker = blob[i + 1]
            if 0xC0 <= marker <= 0xCF and marker not in (0xC4, 0xC8, 0xCC):
                h = (blob[i + 5] << 8) | blob[i + 6]
                w = (blob[i + 7] << 8) | blob[i + 8]
                return w, h
            seg_len = (blob[i + 2] << 8) | blob[i + 3]
            i += 2 + seg_len
    return 400, 240  # fallback


def fetch(url: str, qid: str) -> bytes:
    cache = CACHE_DIR / f"{qid}{Path(url).suffix or '.bin'}"
    if cache.exists() and not FORCE:
        return cache.read_bytes()
    r = subprocess.run(
        [
            "curl", "-fsSL",
            "--retry", "2",
            "--max-time", "20",
            "-A", "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15",
            "-o", str(cache),
            url,
        ],
        check=False, capture_output=True,
    )
    if r.returncode != 0:
        raise RuntimeError(f"curl failed for {qid}: {r.stderr.decode(errors='replace')}")
    return cache.read_bytes()


def wrap_as_svg(blob: bytes) -> str:
    mime = detect_mime(blob)
    if mime == "image/svg+xml":
        # Already SVG — pass through unchanged
        return blob.decode("utf-8", errors="replace")
    w, h = detect_size(blob, mime)
    b64 = base64.b64encode(blob).decode("ascii")
    return (
        '<svg xmlns="http://www.w3.org/2000/svg" '
        'xmlns:xlink="http://www.w3.org/1999/xlink" '
        f'viewBox="0 0 {w} {h}" preserveAspectRatio="xMidYMid meet">'
        f'<image width="{w}" height="{h}" '
        f'xlink:href="data:{mime};base64,{b64}"/>'
        "</svg>"
    )


def main():
    if not SOURCES.exists():
        print(f"Create {SOURCES.relative_to(ROOT)} with qid->image_url mappings.")
        sys.exit(1)

    sources = json.loads(SOURCES.read_text())
    data = json.loads(DATA.read_text())
    by_id = {q["id"]: q for q in data}

    processed = skipped = failed = 0
    failures = []
    for qid, meta in sources.items():
        q = by_id.get(qid)
        if not q:
            failures.append((qid, "not in dataset"))
            failed += 1
            continue
        if q.get("question_svg") and not FORCE:
            skipped += 1
            continue
        url = meta.get("image_url") if isinstance(meta, dict) else meta
        if not url:
            failures.append((qid, "no image_url in source"))
            failed += 1
            continue
        try:
            blob = fetch(url, qid)
            q["question_svg"] = wrap_as_svg(blob)
            processed += 1
        except Exception as e:
            failures.append((qid, str(e)))
            failed += 1

    DATA.write_text(json.dumps(data, indent=2, ensure_ascii=False))
    print(f"Processed: {processed}   Skipped (already had svg): {skipped}   Failed: {failed}")
    for qid, err in failures:
        print(f"  FAIL {qid}: {err}")


if __name__ == "__main__":
    main()
