"""Sanity tests for the holdout builder. Run: .venv/bin/python -m unittest eval.test_build_holdout"""

import json
import unittest
from pathlib import Path

HERE = Path(__file__).resolve().parent


class HoldoutSplitTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.holdout = json.loads((HERE / "holdout_500.json").read_text())
        cls.corpus = json.loads((HERE / "corpus_side.json").read_text())
        cls.manifest = json.loads((HERE / "split_manifest.json").read_text())

    def test_holdout_size_is_500(self):
        self.assertEqual(len(self.holdout), 500)

    def test_no_overlap_with_corpus(self):
        h_ids = {q["id"] for q in self.holdout}
        c_ids = {q["id"] for q in self.corpus}
        self.assertEqual(len(h_ids & c_ids), 0)

    def test_every_holdout_is_NEET_2015_2025(self):
        for q in self.holdout:
            self.assertEqual(q["exam"], "NEET", q["id"])
            self.assertGreaterEqual(q["year"], 2015, q["id"])
            self.assertLessEqual(q["year"], 2025, q["id"])

    def test_every_holdout_has_valid_AK(self):
        for q in self.holdout:
            self.assertIn(q["answer_key"], {"A", "B", "C", "D"}, q["id"])
            self.assertEqual(len(q["options"]), 4, q["id"])
            self.assertTrue(q["question_latex"], q["id"])

    def test_subject_quota(self):
        from collections import Counter
        c = Counter(q["subject"] for q in self.holdout)
        # within ±5 of quota (small slack for thin year-bucket subjects)
        self.assertAlmostEqual(c["Physics"], 125, delta=5)
        self.assertAlmostEqual(c["Chemistry"], 125, delta=5)
        self.assertAlmostEqual(c["Biology"], 250, delta=5)

    def test_no_general_knowledge(self):
        for q in self.holdout:
            self.assertNotEqual(q["subject"], "General Knowledge", q["id"])

    def test_corpus_side_total_matches(self):
        # corpus_side + holdout == every original question
        self.assertEqual(
            len(self.corpus) + len(self.holdout),
            self.manifest["source_question_count"],
        )


if __name__ == "__main__":
    unittest.main()
