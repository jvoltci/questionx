"""Drop records from the launch dataset that have no clean verification path:

  - JEE pre-2019 era (AIEEE 2002-2012, IIT-JEE 1978-2012, JEE Main 2013-2018
    Offline). Coaching archives don't reliably cover these.
  - NEET AIIMS records (1,197). AIIMS never officially published answer keys;
    coaching sources disagree on many AIIMS Qs.

These archived-but-not-shipped records stay in
  scripts/jee/out/full/archive_<reason>.json
so we can re-include them in a later release when verified.
"""
from __future__ import annotations

import json
import re
from pathlib import Path

REPO = Path(__file__).resolve().parents[2]
ASSETS = REPO / "assets"
OUT_FULL = REPO / "scripts" / "jee" / "out" / "full"


def is_legacy_jee(qid: str) -> bool:
    if "AIEEE" in qid:
        return True
    if "IITJEE" in qid:
        return True
    if "Offline" in qid:
        return True
    return False


def main() -> None:
    OUT_FULL.mkdir(parents=True, exist_ok=True)

    # JEE filter
    jee_path = ASSETS / "jee.json"
    jee = json.loads(jee_path.read_text())
    keep_jee, archive_jee = [], []
    for q in jee:
        (archive_jee if is_legacy_jee(q["id"]) else keep_jee).append(q)
    print(f"JEE: kept {len(keep_jee)}, archived {len(archive_jee)} (legacy pre-2019)")
    jee_path.write_text(json.dumps(keep_jee, ensure_ascii=False, indent=2))
    (OUT_FULL / "archive_jee_pre2019.json").write_text(
        json.dumps(archive_jee, ensure_ascii=False, indent=2)
    )

    # NEET filter — drop AIIMS exam rows.
    neet_path = ASSETS / "neet.json"
    neet = json.loads(neet_path.read_text())
    keep_neet, archive_neet = [], []
    for q in neet:
        if q.get("exam") == "AIIMS":
            archive_neet.append(q)
        else:
            keep_neet.append(q)
    print(f"NEET: kept {len(keep_neet)}, archived {len(archive_neet)} (AIIMS)")
    neet_path.write_text(json.dumps(keep_neet, ensure_ascii=False, indent=2))
    (OUT_FULL / "archive_neet_aiims.json").write_text(
        json.dumps(archive_neet, ensure_ascii=False, indent=2)
    )


if __name__ == "__main__":
    main()
