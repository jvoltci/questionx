"""Suppress the diagonal red "ExamGOAL.COM" watermark from examgoal.net figures.

The watermark is a semi-transparent red tile printed over the figure. In RGB
space the watermark pixels have notably more red than green/blue (R - max(G,B)
is large), while genuine figure ink is grayscale (R ≈ G ≈ B) or only mildly
red. We detect "red-leaning" pixels and lift them toward white.

Usage:
    python3 scripts/jee/dewatermark.py SRC_DIR DEST_DIR [--limit N] [--compare COMP_DIR]

If --compare is given, also writes side-by-side before/after PNGs there for
visual review.
"""
from __future__ import annotations

import argparse
from pathlib import Path

from PIL import Image
import numpy as np


def dewatermark(im: Image.Image, *, alpha_thresh: int = 100) -> Image.Image:
    """Return a copy composited over white with low-alpha pixels stripped.

    Examgoal stamps the "ExamGOAL.COM" watermark as the SAME blue ink as the
    figure content, just with much lower alpha (typically 8-77). Real figure
    ink sits at alpha >= 132. We zero out anything below `alpha_thresh`, then
    composite over a white background so the result is a clean RGB image
    suitable for embedding back into the app's diagrams/ dir.
    """
    rgba = im.convert("RGBA")
    arr = np.asarray(rgba).copy()
    a = arr[..., 3]
    # Strip the watermark band: anything below the alpha threshold becomes fully
    # transparent. This preserves anti-aliased figure edges (alpha 132-247) while
    # removing the faint watermark tile (alpha 8-77).
    arr[a < alpha_thresh, 3] = 0
    # Composite over white.
    af = arr[..., 3:4].astype(np.float32) / 255.0
    rgb = arr[..., :3].astype(np.float32)
    out = (rgb * af + 255 * (1 - af)).astype(np.uint8)
    return Image.fromarray(out, mode="RGB")


def make_compare(orig: Image.Image, cleaned: Image.Image) -> Image.Image:
    """Stack before-above-after into a single PNG for review."""
    orig_rgba = orig.convert("RGBA")
    cleaned_rgba = cleaned.convert("RGBA")
    w = max(orig_rgba.width, cleaned_rgba.width)
    h = orig_rgba.height + cleaned_rgba.height + 10
    out = Image.new("RGBA", (w, h), (255, 255, 255, 255))
    out.paste(orig_rgba, (0, 0), orig_rgba)
    out.paste(cleaned_rgba, (0, orig_rgba.height + 10), cleaned_rgba)
    return out


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("src", type=Path)
    ap.add_argument("dest", type=Path)
    ap.add_argument("--limit", type=int, default=0, help="stop after N files")
    ap.add_argument("--compare", type=Path, default=None,
                    help="write side-by-side before/after PNGs here")
    ap.add_argument("--alpha-thresh", type=int, default=100,
                    help="Pixels with alpha below this become transparent then "
                         "composited away. 100 catches the examgoal watermark "
                         "band (alpha 8-77) without touching real figure ink "
                         "(alpha 132+).")
    args = ap.parse_args()

    args.dest.mkdir(parents=True, exist_ok=True)
    if args.compare:
        args.compare.mkdir(parents=True, exist_ok=True)

    files = sorted([p for p in args.src.iterdir() if p.is_file()])
    if args.limit:
        files = files[: args.limit]

    n = 0
    for src in files:
        try:
            with Image.open(src) as im:
                cleaned = dewatermark(im, alpha_thresh=args.alpha_thresh)
                out_path = args.dest / src.name
                if src.suffix.lower() in (".jpg", ".jpeg"):
                    cleaned.save(out_path, "JPEG", quality=92)
                else:
                    # Re-encode as PNG (no longer needs alpha channel).
                    cleaned.save(out_path, "PNG", optimize=True)
                if args.compare:
                    cmp = make_compare(im, cleaned)
                    cmp.save(args.compare / f"{src.stem}_compare.png", "PNG",
                             optimize=True)
        except Exception as e:
            print(f"  ! {src.name}: {e}")
            continue
        n += 1
        if n % 200 == 0:
            print(f"  {n}/{len(files)}")
    print(f"Done. Cleaned {n} files -> {args.dest}")


if __name__ == "__main__":
    main()
