"""Tests for snapshot + semantic diff classification.

A *snapshot* fingerprints each question by meaning (normalized answer, diagram
hash, solution hash). A *diff* classifies what changed between two snapshots and
assigns severity. FAIL = a trust-breaking regression (a verified answer flipped,
a diagram silently dropped). WARN/INFO = changes worth seeing but not blocking.
"""

import unittest

from qx_gate.diff import snapshot, diff_snapshots, FAIL, WARN, INFO


def bundle(*items):
    return list(items)


def q(qid, answer=None, svg=None, solution=None):
    return {"id": qid, "answer_key": answer, "question_svg": svg, "solution": solution}


class TestSnapshot(unittest.TestCase):
    def test_normalizes_answer(self):
        snap = snapshot(bundle(q("q1", answer="1")))
        self.assertEqual(snap["q1"]["answer"], "A")

    def test_diagram_present_hashes_absent_is_none(self):
        snap = snapshot(bundle(q("q1", svg="<svg>x</svg>"), q("q2", svg="")))
        self.assertIsNotNone(snap["q1"]["diagram"])
        self.assertIsNone(snap["q2"]["diagram"])

    def test_identical_svg_hashes_equal(self):
        a = snapshot(bundle(q("q1", svg="<svg>x</svg>")))
        b = snapshot(bundle(q("q1", svg="<svg>x</svg>")))
        self.assertEqual(a["q1"]["diagram"], b["q1"]["diagram"])


class TestDiffClassification(unittest.TestCase):
    def _kinds(self, old_items, new_items):
        changes = diff_snapshots(snapshot(old_items), snapshot(new_items))
        return {c.id: (c.kind, c.severity) for c in changes}

    def test_format_migration_produces_no_changes(self):
        # The defining property: 2,095 historical '1'->'A' rewrites must be silent.
        changes = diff_snapshots(
            snapshot(bundle(q("q1", answer="3"), q("q2", answer="1"))),
            snapshot(bundle(q("q1", answer="C"), q("q2", answer="A"))),
        )
        self.assertEqual(changes, [])

    def test_real_answer_flip_is_fail(self):
        kinds = self._kinds(bundle(q("q1", answer="C")), bundle(q("q1", answer="D")))
        self.assertEqual(kinds["q1"], ("ANSWER_FLIPPED", FAIL))

    def test_answer_lost_is_fail(self):
        kinds = self._kinds(bundle(q("q1", answer="A")), bundle(q("q1", answer="NA")))
        self.assertEqual(kinds["q1"], ("ANSWER_LOST", FAIL))

    def test_answer_gained_is_info(self):
        kinds = self._kinds(bundle(q("q1", answer="NA")), bundle(q("q1", answer="C")))
        self.assertEqual(kinds["q1"], ("ANSWER_GAINED", INFO))

    def test_diagram_dropped_on_kept_question_is_fail(self):
        kinds = self._kinds(bundle(q("q1", svg="<svg>x</svg>")), bundle(q("q1", svg="")))
        self.assertEqual(kinds["q1"], ("DIAGRAM_DROPPED", FAIL))

    def test_diagram_changed_is_warn(self):
        kinds = self._kinds(bundle(q("q1", svg="<svg>x</svg>")), bundle(q("q1", svg="<svg>y</svg>")))
        self.assertEqual(kinds["q1"], ("DIAGRAM_CHANGED", WARN))

    def test_diagram_added_is_info(self):
        kinds = self._kinds(bundle(q("q1", svg="")), bundle(q("q1", svg="<svg>x</svg>")))
        self.assertEqual(kinds["q1"], ("DIAGRAM_ADDED", INFO))

    def test_removed_id_is_warn_not_fail(self):
        # The trust-trim intentionally removed 1,200 ids; removal must not block.
        kinds = self._kinds(bundle(q("q1", answer="A")), bundle())
        self.assertEqual(kinds["q1"], ("REMOVED_ID", WARN))

    def test_added_id_is_info(self):
        kinds = self._kinds(bundle(), bundle(q("q1", answer="A")))
        self.assertEqual(kinds["q1"], ("ADDED_ID", INFO))

    def test_solution_drift_is_warn(self):
        kinds = self._kinds(
            bundle(q("q1", answer="A", solution="because x")),
            bundle(q("q1", answer="A", solution="because y")),
        )
        self.assertEqual(kinds["q1"], ("SOLUTION_DRIFT", WARN))

    def test_unchanged_question_produces_no_change(self):
        changes = diff_snapshots(
            snapshot(bundle(q("q1", answer="A", svg="<svg>x</svg>", solution="s"))),
            snapshot(bundle(q("q1", answer="A", svg="<svg>x</svg>", solution="s"))),
        )
        self.assertEqual(changes, [])


if __name__ == "__main__":
    unittest.main()
