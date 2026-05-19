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
from scipy.ndimage import binary_erosion, binary_dilation


def dewatermark(im: Image.Image, *, alpha_thresh: int = 100) -> Image.Image:
    """Return a copy with both examside watermark styles removed.

    Two distinct watermark families on examside's CDN:

    1) Modern (post-2014 figures): "ExamGOAL.COM" tile encoded as a low-alpha
       overlay at the same hue as the figure ink. Stripped by setting any
       pixel with `alpha < alpha_thresh` to fully transparent.

    2) Legacy (AIEEE / pre-2014 figures): "ExamSIDE.com" stamp baked flat into
       the PNG at full opacity as a large cyan band (RGB ~ 184,232,248).
       Stripped by recoloring any cyan-leaning pixel (R notably less than both
       G and B, with G and B both >= 200) to white. Real figure ink in these
       images is grayscale (R=G=B), so this threshold is safe.

    Both passes are applied to every image — they're mutually exclusive in
    practice but harmless when one doesn't apply.
    """
    rgba = im.convert("RGBA")
    arr = np.asarray(rgba).copy()

    # Pass 1: strip low-alpha overlay watermark.
    a = arr[..., 3]
    arr[a < alpha_thresh, 3] = 0
    af = arr[..., 3:4].astype(np.float32) / 255.0
    rgb = arr[..., :3].astype(np.float32)
    composed = (rgb * af + 255 * (1 - af)).astype(np.uint8)

    # Pass 2: strip the flat "ExamSIDE.com" cyan band (AIEEE / pre-2014).
    #
    # Watermark glyphs are THICK filled letters; light-blue gridlines are
    # 1-2 px strokes. They overlap in color space when antialiased, so colour
    # alone can't distinguish them. Erosion can — eroding by 2 px erases
    # anything thinner than ~5 px, which kills gridlines but barely dents
    # the watermark interior. Dilating the result back recovers the watermark
    # shape, but the dilation only ever propagates within the original cyan
    # mask, so it can never bleed into adjacent black text.
    r = composed[..., 0].astype(int)
    g = composed[..., 1].astype(int)
    b = composed[..., 2].astype(int)
    cyan_loose = (
        (g >= 170) & (b >= 170)
        & ((g - r) >= 15)
        & (np.abs(b - g) <= 35)
    )
    if cyan_loose.any():
        # Erode (kills thin gridlines), dilate back (restores watermark interior).
        seed = binary_erosion(cyan_loose, iterations=2)
        # Dilate seed only as far as the original cyan_loose mask allows,
        # so the restoration can never expand into non-cyan figure ink.
        watermark = binary_dilation(seed, iterations=3, mask=cyan_loose)
        composed[watermark] = [255, 255, 255]
    return Image.fromarray(composed, mode="RGB")


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
