"""Download all figures listed in image_manifest.json into a flat output dir,
and emit a sidecar JSON that maps qid -> filename so jee.json's `question_svg`
field can be populated.

Inputs:
  scripts/jee/out/full/image_manifest.json

Outputs:
  scripts/jee/out/full/figures/<id>[_N].png|.jpg
  scripts/jee/out/full/figure_map.json  -- {qid: "id.png"} (first image only)

Behavior:
  - Multi-figure questions get _2, _3, ... suffixes (first image is the
    primary "question_svg"; secondaries are kept on disk but not yet linked).
  - Skips files that already exist on disk (resumable).
  - Validates each download is a real image (magic bytes) before keeping it.
  - Concurrency: 8 workers. Throttling per worker via small sleep.
"""
from __future__ import annotations

import argparse
import json
import sys
import time
import urllib.request
from concurrent.futures import ThreadPoolExecutor, as_completed
from pathlib import Path

UA = (
    "Mozilla/5.0 (Macintosh; Intel Mac OS X 14_0) AppleWebKit/537.36 "
    "(KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36"
)

# Magic bytes for the image formats we expect.
_MAGIC = {
    b"\x89PNG\r\n\x1a\n": "png",
    b"\xff\xd8\xff": "jpg",
    b"GIF87a": "gif",
    b"GIF89a": "gif",
    b"RIFF": "webp",  # actually RIFF...WEBP, good enough as a sniff
}


def sniff(data: bytes) -> str | None:
    for sig, ext in _MAGIC.items():
        if data.startswith(sig):
            return ext
    return None


def download_one(url: str, dest: Path, timeout: int = 30) -> tuple[bool, str]:
    if dest.exists() and dest.stat().st_size > 0:
        return True, "skip-existing"
    try:
        req = urllib.request.Request(url, headers={"User-Agent": UA})
        with urllib.request.urlopen(req, timeout=timeout) as resp:
            data = resp.read()
    except Exception as e:
        return False, f"http-fail:{e}"
    if not data:
        return False, "empty"
    ext = sniff(data[:16])
    if not ext:
        return False, f"not-image (first bytes {data[:8]!r})"
    dest.parent.mkdir(parents=True, exist_ok=True)
    dest.write_bytes(data)
    return True, ext


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--manifest", default="scripts/jee/out/full/image_manifest.json")
    ap.add_argument("--out", default="scripts/jee/out/full/figures")
    ap.add_argument("--map", default="scripts/jee/out/full/figure_map.json")
    ap.add_argument("--workers", type=int, default=8)
    ap.add_argument("--limit", type=int, default=0, help="stop after N downloads (0=all)")
    args = ap.parse_args()

    manifest = json.load(open(args.manifest))
    if args.limit:
        manifest = manifest[: args.limit]
    out_dir = Path(args.out)
    out_dir.mkdir(parents=True, exist_ok=True)
    print(f"Downloading {len(manifest)} figures with {args.workers} workers -> {out_dir}")

    fig_map: dict[str, str] = {}
    failures: list[dict] = []
    started = time.time()
    done = 0

    def task(entry):
        url = entry["url"]
        fname = entry["filename"]
        ok, info = download_one(url, out_dir / fname)
        return entry, ok, info

    with ThreadPoolExecutor(max_workers=args.workers) as ex:
        futs = [ex.submit(task, e) for e in manifest]
        for fut in as_completed(futs):
            entry, ok, info = fut.result()
            done += 1
            if not ok:
                failures.append({"entry": entry, "info": info})
            else:
                # Only first image per qid populates the map (primary diagram).
                qid = entry["qid"]
                if qid not in fig_map:
                    fig_map[qid] = entry["filename"]
            if done % 200 == 0:
                rate = done / max(1, time.time() - started)
                print(f"  {done}/{len(manifest)} ({rate:.1f}/s) "
                      f"failures={len(failures)}")

    elapsed = time.time() - started
    print()
    print(f"Done. {done} attempted in {elapsed:.1f}s ({done/max(1,elapsed):.1f}/s)")
    print(f"Mapped qids: {len(fig_map)}")
    print(f"Failures: {len(failures)}")
    if failures[:5]:
        print("First failures:")
        for f in failures[:5]:
            print(f"  {f['info']}  url={f['entry']['url']}")

    Path(args.map).write_text(json.dumps(fig_map, indent=2))
    if failures:
        fail_path = Path(args.map).with_name("download_failures.json")
        fail_path.write_text(json.dumps(failures, indent=2))
        print(f"Wrote failures -> {fail_path}")


if __name__ == "__main__":
    main()
