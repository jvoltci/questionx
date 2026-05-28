"""
Parse downloaded NCERT PDFs into paragraph-level chunks.

Heuristics:
- Strip headers/footers (lines with "Reprint", "Rationalised", page numbers, etc.).
- Split on blank lines into paragraphs; merge tiny paragraphs into the previous.
- Drop paragraphs < 80 chars (likely figure captions, equation labels).
- Drop paragraphs > 1500 chars (split further by sentence).

Output: scripts/offline_brain/ncert/chunks.json
  { "chunks": ["...","..."],
    "meta":   [{"source": "kebo101", "subject": "Biology", "class": 11, "ord": 7}, ...] }
"""

import json
import re
from collections import Counter
from pathlib import Path

import pypdf

HERE = Path(__file__).resolve().parent
PDF_DIR = HERE / "pdfs"
OUT = HERE / "chunks.json"

# Lines we always drop
HEADER_FOOTER_RE = re.compile(
    r"^(reprint\s*\d{4}|rationalised\s*\d{4}|©\s*NCERT|"
    r"\d{1,3}\s*$|"           # page numbers
    r"Biology|Physics|Chemistry|Botany|Zoology|"
    r"Chapter\s+\d+|Unit\s+\d+)$",
    re.IGNORECASE,
)
# Pattern to detect line numbers/figures/tables we keep but lightly normalize
WHITESPACE_RE = re.compile(r"\s+")


def infer_subject_class(filename: str) -> tuple[str, int]:
    """e.g. 'class11_biology__kebo101.pdf' -> ('Biology', 11)"""
    parts = filename.split("__")[0]
    cls = 11 if "class11" in parts else 12
    if "biology" in parts:
        subj = "Biology"
    elif "physics" in parts:
        subj = "Physics"
    elif "chemistry" in parts:
        subj = "Chemistry"
    else:
        subj = "Unknown"
    return subj, cls


def extract_text(pdf_path: Path) -> str:
    try:
        reader = pypdf.PdfReader(str(pdf_path))
    except Exception as e:
        print(f"  ! parse fail {pdf_path.name}: {e}")
        return ""
    texts = []
    for page in reader.pages:
        try:
            texts.append(page.extract_text() or "")
        except Exception:
            continue
    return "\n".join(texts)


def clean_line(line: str) -> str:
    line = line.strip()
    if not line:
        return ""
    if HEADER_FOOTER_RE.match(line):
        return ""
    return line


def chunk_text(raw: str) -> list[str]:
    """Split on blank lines, drop short/long outliers, merge tiny ones."""
    # normalize newlines and tabs
    paras = re.split(r"\n\s*\n", raw)
    out = []
    buf = ""
    for p in paras:
        # rejoin within paragraph; keep sentence structure
        lines = [clean_line(l) for l in p.split("\n")]
        lines = [l for l in lines if l]
        if not lines:
            continue
        joined = " ".join(lines)
        joined = WHITESPACE_RE.sub(" ", joined).strip()
        if len(joined) < 50:
            buf = (buf + " " + joined).strip()
            continue
        if buf:
            joined = (buf + " " + joined).strip()
            buf = ""
        if len(joined) > 1500:
            # split on sentence boundaries
            sentences = re.split(r"(?<=[.?!])\s+(?=[A-Z])", joined)
            cur = ""
            for s in sentences:
                if len(cur) + len(s) < 1200:
                    cur = (cur + " " + s).strip()
                else:
                    if len(cur) > 80:
                        out.append(cur)
                    cur = s
            if cur and len(cur) > 80:
                out.append(cur)
        else:
            if len(joined) >= 80:
                out.append(joined)
    if buf and len(buf) >= 80:
        out.append(buf)
    return out


def main() -> None:
    pdfs = sorted(PDF_DIR.glob("*.pdf"))
    if not pdfs:
        print(f"no PDFs in {PDF_DIR}. run download_ncert.sh first.")
        return
    print(f"parsing {len(pdfs)} PDFs...")

    chunks: list[str] = []
    meta: list[dict] = []
    by_subject = Counter()

    for pdf in pdfs:
        subject, cls = infer_subject_class(pdf.name)
        raw = extract_text(pdf)
        if not raw:
            continue
        file_chunks = chunk_text(raw)
        for i, c in enumerate(file_chunks):
            chunks.append(c)
            meta.append({
                "source": pdf.stem.split("__")[-1],
                "subject": subject,
                "class": cls,
                "ord": i,
            })
            by_subject[subject] += 1
        print(f"  {pdf.name:50} → {len(file_chunks)} chunks")

    avg_len = sum(len(c) for c in chunks) / max(len(chunks), 1)
    print(f"\ntotal chunks: {len(chunks)}")
    print(f"by subject:   {dict(by_subject)}")
    print(f"avg chunk len: {avg_len:.0f} chars")

    OUT.write_text(json.dumps({"chunks": chunks, "meta": meta}, ensure_ascii=False, indent=None))
    print(f"\nwrote {OUT} ({OUT.stat().st_size / 1024 / 1024:.1f} MB)")


if __name__ == "__main__":
    main()
