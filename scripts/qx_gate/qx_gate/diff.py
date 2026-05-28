"""Snapshot a content bundle by *meaning* and classify changes between snapshots.

A snapshot maps question id -> fingerprint {answer, diagram, solution}. The diff
turns two snapshots into a list of Change records with a severity:

    FAIL  trust-breaking regression that should block the merge
          (ANSWER_FLIPPED, ANSWER_LOST, DIAGRAM_DROPPED)
    WARN  worth a human look, does not block
          (DIAGRAM_CHANGED, SOLUTION_DRIFT, REMOVED_ID)
    INFO  benign improvement
          (ANSWER_GAINED, DIAGRAM_ADDED, ADDED_ID)
"""

import hashlib
from dataclasses import dataclass

from .normalize import normalize_answer

FAIL = "FAIL"
WARN = "WARN"
INFO = "INFO"


@dataclass(frozen=True)
class Change:
    id: str
    kind: str
    severity: str
    old: object = None
    new: object = None


def _hash(text):
    if text is None:
        return None
    s = " ".join(str(text).split())  # whitespace-insensitive
    if not s:
        return None
    return hashlib.sha256(s.encode("utf-8")).hexdigest()[:16]


def snapshot(bundle):
    """Fingerprint each question by meaning. Returns {id: {answer, diagram, solution}}."""
    snap = {}
    for item in bundle:
        qid = str(item.get("id"))
        snap[qid] = {
            "answer": normalize_answer(item.get("answer_key")),
            "diagram": _hash(item.get("question_svg")),
            "solution": _hash(item.get("solution")),
        }
    return snap


def _answer_change(qid, old, new):
    oa, na = old["answer"], new["answer"]
    if oa == na:
        return None
    if oa is not None and na is not None:
        return Change(qid, "ANSWER_FLIPPED", FAIL, oa, na)
    if oa is not None and na is None:
        return Change(qid, "ANSWER_LOST", FAIL, oa, na)
    return Change(qid, "ANSWER_GAINED", INFO, oa, na)


def _diagram_change(qid, old, new):
    od, nd = old["diagram"], new["diagram"]
    if od == nd:
        return None
    if od is not None and nd is None:
        return Change(qid, "DIAGRAM_DROPPED", FAIL)
    if od is None and nd is not None:
        return Change(qid, "DIAGRAM_ADDED", INFO)
    return Change(qid, "DIAGRAM_CHANGED", WARN)


def diff_snapshots(old, new):
    """Classify every change between two snapshots. Stable order by id then kind."""
    changes = []
    for qid in old.keys() - new.keys():
        changes.append(Change(qid, "REMOVED_ID", WARN))
    for qid in new.keys() - old.keys():
        changes.append(Change(qid, "ADDED_ID", INFO))
    for qid in old.keys() & new.keys():
        o, n = old[qid], new[qid]
        ac = _answer_change(qid, o, n)
        if ac:
            changes.append(ac)
        dc = _diagram_change(qid, o, n)
        if dc:
            changes.append(dc)
        if o["solution"] != n["solution"]:
            changes.append(Change(qid, "SOLUTION_DRIFT", WARN))
    changes.sort(key=lambda c: (c.id, c.kind))
    return changes
