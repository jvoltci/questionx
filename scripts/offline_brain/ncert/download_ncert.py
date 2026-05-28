"""
Download NCERT Class 11 + 12 PDFs for Physics, Chemistry, Biology.

Source: ncert.nic.in/textbook/pdf/<code>.pdf

Book codes used by NCERT:
  Class 11 Physics  : keph1{01..15}  + keph2{01..08}
  Class 11 Chemistry: kech1{01..09}  + kech2{01..05}
  Class 11 Biology  : kebo1{01..22}
  Class 12 Physics  : leph1{01..08}  + leph2{01..07}
  Class 12 Chemistry: lech1{01..05}  + lech2{01..10}  (post-2023 NCERT trim)
  Class 12 Biology  : lebo1{01..13}

The chapter count overestimates a bit; 404s are skipped silently. Final inventory
written to ncert/manifest.json so downstream parser knows what landed.
"""

import json
import time
import urllib.error
import urllib.request
from pathlib import Path

HERE = Path(__file__).resolve().parent
PDF_DIR = HERE / "pdfs"
PDF_DIR.mkdir(exist_ok=True)

BASE = "https://ncert.nic.in/textbook/pdf/{code}.pdf"

UA = "Mozilla/5.0 (compatible; questionx-offline-brain/0.1; +noncommercial-eval)"

# Conservative ceiling — overshoots actual chapter counts; 404s skipped.
PLAN = {
    "class11_physics_p1":   [f"keph1{n:02d}" for n in range(1, 16)],
    "class11_physics_p2":   [f"keph2{n:02d}" for n in range(1, 10)],
    "class11_chemistry_p1": [f"kech1{n:02d}" for n in range(1, 10)],
    "class11_chemistry_p2": [f"kech2{n:02d}" for n in range(1, 7)],
    "class11_biology":      [f"kebo1{n:02d}" for n in range(1, 23)],
    "class12_physics_p1":   [f"leph1{n:02d}" for n in range(1, 9)],
    "class12_physics_p2":   [f"leph2{n:02d}" for n in range(1, 9)],
    "class12_chemistry_p1": [f"lech1{n:02d}" for n in range(1, 6)],
    "class12_chemistry_p2": [f"lech2{n:02d}" for n in range(1, 11)],
    "class12_biology":      [f"lebo1{n:02d}" for n in range(1, 14)],
}


def fetch(code: str) -> bytes | None:
    url = BASE.format(code=code)
    req = urllib.request.Request(url, headers={"User-Agent": UA})
    try:
        with urllib.request.urlopen(req, timeout=30) as r:
            data = r.read()
            if len(data) < 10_000 or not data[:4] == b"%PDF":
                return None
            return data
    except (urllib.error.HTTPError, urllib.error.URLError, TimeoutError):
        return None


def main() -> None:
    manifest = []
    total_ok = 0
    total_attempted = 0
    for book, codes in PLAN.items():
        for code in codes:
            total_attempted += 1
            out_path = PDF_DIR / f"{book}__{code}.pdf"
            if out_path.exists() and out_path.stat().st_size > 10_000:
                manifest.append({"book": book, "code": code, "path": str(out_path.name), "bytes": out_path.stat().st_size, "cached": True})
                total_ok += 1
                continue
            data = fetch(code)
            if data is None:
                print(f"  miss   {book}/{code}")
                time.sleep(0.4)
                continue
            out_path.write_bytes(data)
            manifest.append({"book": book, "code": code, "path": str(out_path.name), "bytes": len(data), "cached": False})
            total_ok += 1
            print(f"  ok     {book}/{code} ({len(data)//1024} KB)")
            time.sleep(0.6)  # polite rate

    (HERE / "manifest.json").write_text(json.dumps(manifest, indent=2))
    print(f"\ndone: {total_ok}/{total_attempted} PDFs landed")
    print(f"manifest: {HERE / 'manifest.json'}")


if __name__ == "__main__":
    main()
