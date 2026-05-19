"""Scrape JEE Main / JEE Advanced questions from examside.com.

Strategy:
  - Iterate (exam, subject, topic) triples. For each, fetch the SvelteKit
    `__data.json` for the topic listing page. That returns all questions for
    the topic grouped by type (MCQ vs Numerical), with full English content,
    options, correct answer(s), and explanations inline.
  - Filter to year ∈ TARGET_YEARS.
  - Dedupe by examside `question_id` (one Q can appear under multiple topics).
  - Convert examside HTML to NEET-schema text (`question_latex` style):
    plain text + inline `$...$` LaTeX + extracted image URLs separated out
    for the diagrams pipeline.
  - Write a flat JSON list compatible with `assets/neet.json` schema.

Usage:
    python3 scripts/jee/scrape_examside.py --stage1   # one topic, smoke test
    python3 scripts/jee/scrape_examside.py --full     # all topics

Output: scripts/jee/out/{stage1,full}/{questions.json, image_manifest.json}
"""
from __future__ import annotations

import argparse
import html
import json
import re
import sys
import time
import urllib.request
from collections import Counter
from pathlib import Path
from typing import Any

from devalue import decode

UA = (
    "Mozilla/5.0 (Macintosh; Intel Mac OS X 14_0) AppleWebKit/537.36 "
    "(KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36"
)
BASE = "https://questions.examside.com"
TARGET_YEARS: set[int] | None = None  # None = accept all years (full archive)
ROOT = Path(__file__).resolve().parent
OUT_DIR = ROOT / "out"

# Topic index endpoints. Sourced from the JEE Main / JEE Advanced landing pages
# in this session's recon (curl confirmed 200 with browser UA).
EXAMS: dict[str, dict[str, list[str]]] = {
    "jee-main": {
        "physics": [
            "alternating-current", "atoms-and-nuclei", "capacitor", "center-of-mass",
            "circular-motion", "communication-systems", "current-electricity",
            "dual-nature-of-radiation", "electromagnetic-induction",
            "electromagnetic-waves", "electronic-devices", "electrostatics",
            "geometrical-optics", "gravitation", "heat-and-thermodynamics",
            "laws-of-motion", "magnetic-properties-of-matter", "magnetics",
            "motion-in-a-plane", "motion-in-a-straight-line", "properties-of-matter",
            "rotational-motion", "simple-harmonic-motion", "units-and-measurements",
            "vector-algebra", "wave-optics", "waves", "work-power-and-energy",
        ],
        "chemistry": [
            "alcohols-phenols-and-ethers", "aldehydes-ketones-and-carboxylic-acids",
            "basics-of-organic-chemistry", "biomolecules",
            "chemical-bonding-and-molecular-structure", "chemical-equilibrium",
            "chemical-kinetics-and-nuclear-chemistry", "chemistry-in-everyday-life",
            "compounds-containing-nitrogen", "coordination-compounds",
            "d-and-f-block-elements", "electrochemistry", "environmental-chemistry",
            "gaseous-state", "haloalkanes-and-haloarenes", "hydrocarbons", "hydrogen",
            "ionic-equilibrium", "isolation-of-elements", "p-block-elements",
            "periodic-table-and-periodicity", "polymers", "practical-organic-chemistry",
            "redox-reactions", "s-block-elements", "salt-analysis", "solid-state",
            "solutions", "some-basic-concepts-of-chemistry", "structure-of-atom",
            "surface-chemistry", "thermodynamics",
        ],
        "mathematics": [
            "3d-geometry", "application-of-derivatives", "area-under-the-curves",
            "binomial-theorem", "circle", "complex-numbers", "definite-integration",
            "differential-equations", "differentiation", "ellipse", "functions",
            "height-and-distance", "hyperbola", "indefinite-integrals",
            "inverse-trigonometric-functions",
            "limits-continuity-and-differentiability", "logarithm",
            "mathematical-induction", "mathematical-reasoning",
            "matrices-and-determinants", "parabola",
            "permutations-and-combinations", "probability", "properties-of-triangle",
            "quadratic-equation-and-inequalities", "sequences-and-series",
            "sets-and-relations", "statistics", "straight-lines-and-pair-of-straight-lines",
            "trigonometric-functions-and-equations", "trigonometric-ratio-and-identites",
            "vector-algebra",
        ],
    },
    "jee-advanced": {
        "physics": [
            "alternating-current", "atoms-and-nuclei", "capacitor", "current-electricity",
            "dual-nature-of-radiation", "electromagnetic-induction",
            "electromagnetic-waves", "electrostatics", "geometrical-optics",
            "gravitation", "heat-and-thermodynamics", "impulse-and-momentum",
            "laws-of-motion", "magnetism", "motion", "motion-in-a-plane",
            "practical-physics", "properties-of-matter", "rotational-motion",
            "simple-harmonic-motion", "units-and-measurements", "wave-optics",
            "waves", "work-power-and-energy",
        ],
        "chemistry": [
            "alcohols-phenols-and-ethers", "aldehydes-ketones-and-carboxylic-acids",
            "basics-of-organic-chemistry", "biomolecules",
            "chemical-bonding-and-molecular-structure", "chemical-equilibrium",
            "chemical-kinetics-and-nuclear-chemistry", "chemistry-in-everyday-life",
            "compounds-containing-nitrogen", "coordination-compounds",
            "d-and-f-block-elements", "electrochemistry", "gaseous-state",
            "haloalkanes-and-haloarenes", "hydrocarbons", "hydrogen",
            "ionic-equilibrium", "isolation-of-elements", "p-block-elements",
            "periodic-table-and-periodicity", "polymers", "practical-organic-chemistry",
            "redox-reactions", "s-block-elements", "salt-analysis", "solid-state",
            "solutions", "some-basic-concepts-of-chemistry", "structure-of-atom",
            "surface-chemistry", "thermodynamics",
        ],
        "mathematics": [
            "3d-geometry", "application-of-derivatives", "application-of-integration",
            "circle", "complex-numbers", "definite-integration",
            "differential-equations", "differentiation", "ellipse", "functions",
            "hyperbola", "indefinite-integrals", "inverse-trigonometric-functions",
            "limits-continuity-and-differentiability",
            "mathematical-induction-and-binomial-theorem",
            "matrices-and-determinants", "parabola", "permutations-and-combinations",
            "probability", "properties-of-triangle", "quadratic-equation-and-inequalities",
            "sequences-and-series", "statistics",
            "straight-lines-and-pair-of-straight-lines",
            "trigonometric-functions-and-equations", "vector-algebra",
        ],
    },
}


def http_get(url: str, timeout: int = 30) -> bytes:
    req = urllib.request.Request(url, headers={"User-Agent": UA})
    with urllib.request.urlopen(req, timeout=timeout) as resp:
        return resp.read()


def fetch_topic_questions(exam: str, subject: str, topic: str) -> list[dict] | None:
    """Return the flat list of decoded question dicts for one topic, or None on failure."""
    url = f"{BASE}/past-years/jee/{exam}/{subject}/{topic}/__data.json"
    try:
        raw = http_get(url)
    except Exception as e:
        print(f"  ! {topic}: HTTP fail {e}", file=sys.stderr)
        return None
    try:
        payload = json.loads(raw)
        nodes = decode(payload)
    except Exception as e:
        print(f"  ! {topic}: decode fail {e}", file=sys.stderr)
        return None
    # Find the node carrying `questions` (it's a list-of-groups, each with its own questions array).
    qs: list[dict] = []
    for n in nodes:
        if isinstance(n, dict) and isinstance(n.get("questions"), list):
            for group in n["questions"]:
                if isinstance(group, dict) and isinstance(group.get("questions"), list):
                    qs.extend(group["questions"])
            break
    return qs


_PAPER_RE_MAIN_ONLINE = re.compile(
    r"JEE\s+Main\s+(?P<year>\d{4})\s*\(Online\)\s+"
    r"(?P<day>\d{1,2})(?:st|nd|rd|th)\s+(?P<mon>[A-Za-z]+)\s+"
    r"(?P<shift>Morning|Evening)\s+(?:Shift|Slot)",
    re.IGNORECASE,
)
# Pre-2019 NTA papers were one single offline paper per year, no shift granularity.
_PAPER_RE_MAIN_OFFLINE = re.compile(
    r"JEE\s+Main\s+(?P<year>\d{4})\s*\(Offline\)",
    re.IGNORECASE,
)
# AIEEE = pre-2013 predecessor of JEE Main. One paper per year.
_PAPER_RE_AIEEE = re.compile(r"AIEEE\s+(?P<year>\d{4})", re.IGNORECASE)

_PAPER_RE_ADV = re.compile(
    r"JEE\s+Advanced\s+(?P<year>\d{4})\s+Paper\s+(?P<paper>[12])\s+(?P<mode>Online|Offline)",
    re.IGNORECASE,
)
# IIT-JEE = pre-2013 predecessor of JEE Advanced.
# 2007-2012: split into Paper 1 + Paper 2.
_PAPER_RE_IITJEE_SPLIT = re.compile(
    r"IIT-JEE\s+(?P<year>\d{4})\s+Paper\s+(?P<paper>[12])(?:\s+(?P<mode>Online|Offline))?",
    re.IGNORECASE,
)
# 1978-2006: single paper, sometimes labelled "Screening" or "Mains".
_PAPER_RE_IITJEE_OLD = re.compile(
    r"IIT-JEE\s+(?P<year>\d{4})(?:\s+(?P<extra>Screening|Mains))?$",
    re.IGNORECASE,
)
_MONTH = {
    "january": "Jan", "february": "Feb", "march": "Mar", "april": "Apr",
    "may": "May", "june": "Jun", "july": "Jul", "august": "Aug",
    "september": "Sep", "october": "Oct", "november": "Nov", "december": "Dec",
}


def parse_paper_meta(exam: str, paper_title: str | None) -> dict[str, Any] | None:
    """Pull year + date + shift (Main) or year + paper# (Advanced) out of the paperTitle string."""
    if not paper_title:
        return None
    if exam == "jee-main":
        m = _PAPER_RE_MAIN_ONLINE.search(paper_title)
        if m:
            year = int(m["year"])
            day = int(m["day"])
            mon = _MONTH.get(m["mon"].lower())
            if not mon:
                return None
            shift = "S1" if m["shift"].lower() == "morning" else "S2"
            return {"year": year, "mon": mon, "day": day, "shift": shift,
                    "kind": "main"}
        # Fall back to the pre-2019 offline format: single paper, no shift.
        m = _PAPER_RE_MAIN_OFFLINE.search(paper_title)
        if m:
            return {"year": int(m["year"]), "kind": "main_offline"}
        # AIEEE 2002-2012: single paper per year (legacy name; treated as JEE Main).
        m = _PAPER_RE_AIEEE.search(paper_title)
        if m:
            return {"year": int(m["year"]), "kind": "aieee"}
        return None
    if exam == "jee-advanced":
        m = _PAPER_RE_ADV.search(paper_title)
        if m:
            return {
                "year": int(m["year"]),
                "paper": int(m["paper"]),
                "mode": m["mode"][0].upper(),
                "kind": "adv",
            }
        # IIT-JEE 2007-2012 (Paper 1/2 era): treated as JEE Advanced.
        m = _PAPER_RE_IITJEE_SPLIT.search(paper_title)
        if m:
            return {
                "year": int(m["year"]),
                "paper": int(m["paper"]),
                "kind": "iitjee_split",
            }
        # IIT-JEE 1978-2006 (single paper; sometimes "Screening" or "Mains").
        m = _PAPER_RE_IITJEE_OLD.search(paper_title)
        if m:
            return {
                "year": int(m["year"]),
                "extra": (m["extra"] or "").capitalize() or None,
                "kind": "iitjee_old",
            }
        return None
    return None


_SUBJ_ABBR = {"physics": "Phy", "chemistry": "Chem", "mathematics": "Math"}


def make_id(exam: str, meta: dict, subject: str, ordinal: int) -> str:
    subj = _SUBJ_ABBR[subject]
    kind = meta["kind"]
    if kind == "main":
        return f"JEE_Main_{meta['year']}_{meta['mon']}{meta['day']:02d}_{meta['shift']}_{subj}_{ordinal}"
    if kind == "main_offline":
        return f"JEE_Main_{meta['year']}_Offline_{subj}_{ordinal}"
    if kind == "aieee":
        return f"JEE_Main_AIEEE_{meta['year']}_{subj}_{ordinal}"
    if kind == "adv":
        return f"JEE_Adv_{meta['year']}_P{meta['paper']}_{subj}_{ordinal}"
    if kind == "iitjee_split":
        return f"JEE_Adv_IITJEE_{meta['year']}_P{meta['paper']}_{subj}_{ordinal}"
    if kind == "iitjee_old":
        suffix = f"_{meta['extra']}" if meta.get("extra") else ""
        return f"JEE_Adv_IITJEE_{meta['year']}{suffix}_{subj}_{ordinal}"
    raise ValueError(f"unknown meta kind: {kind}")


_TAG = re.compile(r"<[^>]+>")
_IMG_TAG = re.compile(r"<img[^>]*\bsrc=\"([^\"]+)\"[^>]*>", re.IGNORECASE)
_WS = re.compile(r"[ \t]+")


def extract_images(html_str: str) -> list[str]:
    if not html_str:
        return []
    return _IMG_TAG.findall(html_str)


def html_to_text(html_str: str | None) -> str:
    """Convert examside HTML payload to plain-text-with-LaTeX. Strips tags,
    converts <sup>/<sub>/<br>, decodes entities. Image tags are dropped — they
    are extracted separately for the diagram pipeline."""
    if not html_str:
        return ""
    s = html_str
    # Drop images entirely from text — they're handled separately.
    s = _IMG_TAG.sub("", s)
    # <br>, <br/>, <br /> → newline
    s = re.sub(r"<br\s*/?>", "\n", s, flags=re.IGNORECASE)
    # <sup>X</sup> → ^{X}
    s = re.sub(r"<sup[^>]*>(.*?)</sup>", r"^{\1}", s, flags=re.IGNORECASE | re.DOTALL)
    s = re.sub(r"<sub[^>]*>(.*?)</sub>", r"_{\1}", s, flags=re.IGNORECASE | re.DOTALL)
    # </p> and <li> → newline (keeps paragraph breaks)
    s = re.sub(r"</p>|</li>", "\n", s, flags=re.IGNORECASE)
    # Strip remaining tags.
    s = _TAG.sub("", s)
    s = html.unescape(s)
    s = _WS.sub(" ", s)
    # Collapse 3+ blank lines.
    s = re.sub(r"\n{3,}", "\n\n", s)
    return s.strip()


def to_neet_record(q: dict, exam: str, subject: str, ordinal: int) -> dict | None:
    """Translate one examside question into NEET-schema record. Returns None
    if we cannot resolve year/shift metadata (skipped)."""
    meta = parse_paper_meta(exam, q.get("paperTitle"))
    if not meta:
        return None
    if TARGET_YEARS is not None and meta["year"] not in TARGET_YEARS:
        return None
    en = (q.get("question") or {}).get("en") or {}
    q_html = en.get("content") or ""
    opts = en.get("options") or []
    correct_opts = en.get("correct_options") or []
    numeric_answer = en.get("answer")  # populated for type='integer'
    expl_html = en.get("explanation") or ""

    qid = make_id(exam, meta, subject, ordinal)

    options_text = [html_to_text(o.get("content", "")) for o in opts]
    if len(options_text) not in (0, 4):
        # MCQ should have 4 options. Numerical/integer has 0.
        # Note: a handful of Qs have "MCQ (Multiple Correct Answer)" with 4 options too.
        pass  # we'll record as-is and surface via type field

    qtype = q.get("type", "mcq")
    record: dict[str, Any] = {
        "id": qid,
        "exam": "JEE_Main" if exam == "jee-main" else "JEE_Advanced",
        "question_number": ordinal,
        "question_latex": html_to_text(q_html),
        "options": options_text,
        "answer_key": _normalize_answer(correct_opts, numeric_answer, qtype),
        "solution": html_to_text(expl_html),
        "subject": _SUBJ_ABBR[subject].replace("Math", "Mathematics").replace("Phy", "Physics").replace("Chem", "Chemistry"),
        "topic": _humanize_topic(q.get("chapter") or q.get("topic") or ""),
        "year": meta["year"],
        "difficulty": (q.get("difficulty") or "").capitalize() or "Medium",
    }
    # Annotate non-standard types via a flag so the app can decide rendering.
    if qtype in ("integer", "numerical"):
        record["question_type"] = "integer"
    elif len(correct_opts) > 1:
        record["question_type"] = "multi_correct"
    # Source attribution (kept for our own traceability; not displayed).
    record["_source_qid"] = q.get("question_id")
    record["_paper_title"] = q.get("paperTitle")
    # Image references — extract from content + explanation. The downloader
    # will use these to populate `question_svg` later.
    imgs = extract_images(q_html) + extract_images(expl_html)
    if imgs:
        record["_image_urls"] = imgs
    return record


def _normalize_answer(correct_opts: list[str], numeric: Any, qtype: str) -> str:
    if qtype in ("integer", "numerical"):
        return "" if numeric is None else str(numeric)
    if not correct_opts:
        return ""
    if len(correct_opts) == 1:
        return correct_opts[0]
    return ",".join(correct_opts)


def _humanize_topic(slug: str) -> str:
    return " ".join(w.capitalize() for w in slug.replace("_", "-").split("-"))


def scrape(exam_filter: list[str], subject_filter: list[str] | None,
           topic_filter: list[str] | None, throttle_s: float, out_dir: Path) -> None:
    out_dir.mkdir(parents=True, exist_ok=True)
    all_records: list[dict] = []
    seen_qids: set[str] = set()
    counters: Counter[str] = Counter()
    skipped_no_meta = 0
    skipped_wrong_year = 0

    for exam in exam_filter:
        subjects = EXAMS.get(exam, {})
        for subject, topics in subjects.items():
            if subject_filter and subject not in subject_filter:
                continue
            # Per-paper ordinal counter shared ACROSS topics for this (exam, subject)
            # so that the Nth math Q in a given shift gets ordinal N globally, not
            # restarted at 1 every time we move to the next topic.
            ordinal_by_paper: Counter[str] = Counter()
            for topic in topics:
                if topic_filter and topic not in topic_filter:
                    continue
                qs = fetch_topic_questions(exam, subject, topic)
                if not qs:
                    print(f"[{exam}/{subject}/{topic}] empty / fetch failed")
                    continue
                # Order by paperTitle then question_id for stable ordinal assignment.
                qs.sort(key=lambda q: (q.get("paperTitle") or "", q.get("question_id") or ""))
                topic_kept = 0
                for q in qs:
                    qid = q.get("question_id")
                    if not qid:
                        continue
                    if qid in seen_qids:
                        continue
                    # peek paper meta to bump ordinal
                    meta = parse_paper_meta(exam, q.get("paperTitle"))
                    if not meta:
                        skipped_no_meta += 1
                        continue
                    if TARGET_YEARS is not None and meta["year"] not in TARGET_YEARS:
                        skipped_wrong_year += 1
                        continue
                    pkey = q.get("paperId") or q.get("paperTitle") or ""
                    pkey = f"{exam}|{pkey}|{subject}"
                    ordinal_by_paper[pkey] += 1
                    rec = to_neet_record(q, exam, subject, ordinal_by_paper[pkey])
                    if rec is None:
                        continue
                    seen_qids.add(qid)
                    all_records.append(rec)
                    topic_kept += 1
                    counters[f"{exam}/{subject}"] += 1
                print(f"[{exam}/{subject}/{topic}] kept {topic_kept} (target-year, deduped)")
                if throttle_s:
                    time.sleep(throttle_s)

    # Summary
    print()
    print(f"Total records: {len(all_records)}")
    print(f"Skipped (no paper meta): {skipped_no_meta}")
    year_filter_desc = sorted(TARGET_YEARS) if TARGET_YEARS is not None else "ALL"
    print(f"Skipped (year not in {year_filter_desc}): {skipped_wrong_year}")
    print("By (exam/subject):")
    for k, v in sorted(counters.items()):
        print(f"  {k}: {v}")

    # Save
    out_q = out_dir / "questions.json"
    with out_q.open("w") as f:
        json.dump(all_records, f, ensure_ascii=False, indent=2)
    print(f"\nWrote {out_q}")

    # Image manifest (URLs → suggested filename).
    img_manifest = []
    for rec in all_records:
        for i, url in enumerate(rec.get("_image_urls", []) or []):
            ext = url.rsplit(".", 1)[-1].split("?")[0]
            if ext.lower() not in ("png", "jpg", "jpeg", "gif", "webp"):
                ext = "png"
            img_manifest.append({
                "qid": rec["id"],
                "url": url,
                "filename": f"{rec['id']}{'_'+str(i+1) if i else ''}.{ext}",
            })
    out_imgs = out_dir / "image_manifest.json"
    with out_imgs.open("w") as f:
        json.dump(img_manifest, f, ensure_ascii=False, indent=2)
    print(f"Wrote {out_imgs} ({len(img_manifest)} image refs)")


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--stage1", action="store_true", help="Smoke test: one math topic only")
    ap.add_argument("--full", action="store_true", help="Full sweep across all topics/exams")
    ap.add_argument("--exam", action="append", help="Filter exam(s)", default=None)
    ap.add_argument("--subject", action="append", help="Filter subject(s)", default=None)
    ap.add_argument("--topic", action="append", help="Filter topic(s)", default=None)
    ap.add_argument("--throttle", type=float, default=0.6, help="Sleep between topics (s)")
    args = ap.parse_args()

    if args.stage1:
        scrape(["jee-main"], ["mathematics"], ["circle"], throttle_s=0.0,
               out_dir=OUT_DIR / "stage1")
        return
    if args.full:
        scrape(["jee-main", "jee-advanced"], None, None, throttle_s=args.throttle,
               out_dir=OUT_DIR / "full")
        return

    # Default: honor filters.
    scrape(
        exam_filter=args.exam or ["jee-main"],
        subject_filter=args.subject,
        topic_filter=args.topic,
        throttle_s=args.throttle,
        out_dir=OUT_DIR / "custom",
    )


if __name__ == "__main__":
    main()
