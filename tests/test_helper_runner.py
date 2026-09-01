"""Tests for bounded subprocess execution used by QML helpers."""

from __future__ import annotations

import subprocess
import unittest
from pathlib import Path


PROJECT_DIR = Path(__file__).resolve().parents[1]
RUNNER = PROJECT_DIR / "bin" / "omarchy-dashboard-run-helper"


class HelperRunnerTests(unittest.TestCase):
    def run_helper(self, source: str, maximum: int = 64, timeout: str = "1") -> subprocess.CompletedProcess[bytes]:
        return subprocess.run(
            [
                "/usr/bin/python3", "-I", str(RUNNER), "--max-bytes", str(maximum),
                "--timeout-seconds", timeout, "--", "/usr/bin/python3", "-c", source,
            ],
            capture_output=True,
            check=False,
            timeout=3,
        )

    def test_forwards_a_bounded_successful_result(self) -> None:
        result = self.run_helper("import sys; sys.stdout.write('ok')")
        self.assertEqual(result.returncode, 0)
        self.assertEqual(result.stdout, b"ok")

    def test_terminates_when_stdout_exceeds_the_limit(self) -> None:
        result = self.run_helper("import sys; sys.stdout.write('x' * 65)")
        self.assertEqual(result.returncode, 121)
        self.assertIn(b"output exceeds", result.stderr)
        self.assertEqual(result.stdout, b"")

    def test_terminates_when_stderr_exceeds_the_limit(self) -> None:
        result = self.run_helper("import sys; sys.stderr.write('x' * 65)")
        self.assertEqual(result.returncode, 121)
        self.assertIn(b"output exceeds", result.stderr)

    def test_enforces_a_deadline(self) -> None:
        result = self.run_helper("import time; time.sleep(2)", timeout="0.05")
        self.assertEqual(result.returncode, 120)
        self.assertIn(b"timed out", result.stderr)


if __name__ == "__main__":
    unittest.main()
