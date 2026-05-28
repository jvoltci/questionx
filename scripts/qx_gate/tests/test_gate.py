"""Tests for the gate verdict: which changes block a merge, and how an
intentional change is acknowledged via an overrides allowlist so it stops
blocking without weakening the gate for everything else.
"""

import unittest

from qx_gate.diff import Change, FAIL, WARN, INFO
from qx_gate.gate import evaluate


class TestEvaluate(unittest.TestCase):
    def test_no_changes_passes(self):
        result = evaluate([])
        self.assertTrue(result.passed)
        self.assertEqual(result.blocking, [])

    def test_fail_change_blocks_merge(self):
        changes = [Change("q1", "ANSWER_FLIPPED", FAIL, "C", "D")]
        result = evaluate(changes)
        self.assertFalse(result.passed)
        self.assertEqual([c.id for c in result.blocking], ["q1"])

    def test_warn_and_info_never_block(self):
        changes = [
            Change("q1", "DIAGRAM_CHANGED", WARN),
            Change("q2", "ANSWER_GAINED", INFO, None, "C"),
            Change("q3", "REMOVED_ID", WARN),
        ]
        result = evaluate(changes)
        self.assertTrue(result.passed)
        self.assertEqual(len(result.warnings), 2)
        self.assertEqual(len(result.info), 1)

    def test_override_acknowledges_a_fail(self):
        changes = [Change("q1", "ANSWER_FLIPPED", FAIL, "C", "D")]
        result = evaluate(changes, overrides={"q1": "verified correction per NEET 2009 key"})
        self.assertTrue(result.passed)
        self.assertEqual(result.blocking, [])
        self.assertEqual([c.id for c in result.acknowledged], ["q1"])

    def test_override_is_per_id_not_global(self):
        changes = [
            Change("q1", "ANSWER_FLIPPED", FAIL, "C", "D"),
            Change("q2", "DIAGRAM_DROPPED", FAIL),
        ]
        result = evaluate(changes, overrides={"q1": "approved"})
        self.assertFalse(result.passed)  # q2 still blocks
        self.assertEqual([c.id for c in result.blocking], ["q2"])
        self.assertEqual([c.id for c in result.acknowledged], ["q1"])


if __name__ == "__main__":
    unittest.main()
