"""Tests for the CLI surface CI consumes: a human-readable report and a process
exit code (0 = clean / acknowledged, 1 = a real regression blocks the merge).
"""

import contextlib
import io
import json
import os
import tempfile
import unittest

from qx_gate.diff import Change, FAIL, WARN
from qx_gate.gate import GateResult
from qx_gate.cli import format_report, main


def _silent_main(argv):
    with contextlib.redirect_stdout(io.StringIO()):
        return main(argv)


class TestFormatReport(unittest.TestCase):
    def test_clean_report_says_pass(self):
        text = format_report(GateResult(passed=True))
        self.assertIn("PASS", text)

    def test_blocking_report_names_the_regression(self):
        result = GateResult(
            passed=False,
            blocking=[Change("AIPMT_2009_Phy_22", "ANSWER_FLIPPED", FAIL, "C", "D")],
        )
        text = format_report(result)
        self.assertIn("FAIL", text)
        self.assertIn("AIPMT_2009_Phy_22", text)
        self.assertIn("ANSWER_FLIPPED", text)

    def test_report_summarizes_warning_counts(self):
        result = GateResult(passed=True, warnings=[Change("q1", "DIAGRAM_CHANGED", WARN)])
        self.assertIn("1", format_report(result))


class TestMainExitCode(unittest.TestCase):
    def _write(self, items):
        fd, path = tempfile.mkstemp(suffix=".json")
        with os.fdopen(fd, "w") as f:
            json.dump(items, f)
        self.addCleanup(os.remove, path)
        return path

    def test_exit_zero_when_only_format_migration(self):
        old = self._write([{"id": "q1", "answer_key": "3"}])
        new = self._write([{"id": "q1", "answer_key": "C"}])
        self.assertEqual(_silent_main(["check", "--baseline", old, "--current", new]), 0)

    def test_exit_one_on_real_flip(self):
        old = self._write([{"id": "q1", "answer_key": "C"}])
        new = self._write([{"id": "q1", "answer_key": "D"}])
        self.assertEqual(_silent_main(["check", "--baseline", old, "--current", new]), 1)

    def test_exit_zero_when_flip_is_overridden(self):
        old = self._write([{"id": "q1", "answer_key": "C"}])
        new = self._write([{"id": "q1", "answer_key": "D"}])
        ov = self._write({"q1": "approved correction"})
        code = _silent_main(["check", "--baseline", old, "--current", new, "--overrides", ov])
        self.assertEqual(code, 0)


if __name__ == "__main__":
    unittest.main()
