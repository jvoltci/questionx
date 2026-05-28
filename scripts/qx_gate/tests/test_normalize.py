"""Tests for answer-key normalization.

The whole point of qx-gate is to tell a *benign format migration* (the historical
`1 -> A` rewrite that touched 2,095 questions in one commit) apart from a *real
semantic flip* (the 12 questions whose answer actually changed). Normalization is
what collapses the format noise so the diff only sees meaning.
"""

import unittest

from qx_gate.normalize import normalize_answer


class TestNormalizeAnswer(unittest.TestCase):
    def test_numeric_maps_to_letter(self):
        self.assertEqual(normalize_answer("1"), "A")
        self.assertEqual(normalize_answer("2"), "B")
        self.assertEqual(normalize_answer("3"), "C")
        self.assertEqual(normalize_answer("4"), "D")

    def test_letter_passes_through(self):
        self.assertEqual(normalize_answer("A"), "A")
        self.assertEqual(normalize_answer("D"), "D")

    def test_format_migration_is_invariant(self):
        # The core property: '3' and 'C' must canonicalize identically so the
        # historical 1->A migration produces ZERO diffs.
        self.assertEqual(normalize_answer("3"), normalize_answer("C"))
        self.assertEqual(normalize_answer("1"), normalize_answer("a"))

    def test_case_and_whitespace_insensitive(self):
        self.assertEqual(normalize_answer(" c "), "C")
        self.assertEqual(normalize_answer("b"), "B")

    def test_multi_answer_is_sorted_and_deduped(self):
        self.assertEqual(normalize_answer("1,3"), "A,C")
        self.assertEqual(normalize_answer("3,1"), "A,C")
        self.assertEqual(normalize_answer("A, C"), "A,C")
        self.assertEqual(normalize_answer("C;A"), "A,C")

    def test_empty_and_none_are_unresolved(self):
        self.assertIsNone(normalize_answer(None))
        self.assertIsNone(normalize_answer(""))
        self.assertIsNone(normalize_answer("   "))

    def test_freetext_notes_are_unresolved_not_clever_parsed(self):
        # 'NA' and human notes must NOT be coerced into an option. They are
        # unresolved -> a later resolution is a GAIN (info), never a silent flip.
        self.assertIsNone(normalize_answer("NA"))
        self.assertIsNone(normalize_answer("No Option Correct in Key (Answer (1) in doc)"))

    def test_real_flip_is_visible_after_normalization(self):
        # AIPMT_2009_Phy_22 actually changed C -> D in history. Must NOT collapse.
        self.assertNotEqual(normalize_answer("C"), normalize_answer("D"))
        # AIIMS_2013_Phy_5 went '4'(=D) -> 'C': a real flip, must stay visible.
        self.assertNotEqual(normalize_answer("4"), normalize_answer("C"))


if __name__ == "__main__":
    unittest.main()
