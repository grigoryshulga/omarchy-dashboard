"""Tests for the descriptor-based Dashboard state writer."""

from __future__ import annotations

import os
import subprocess
import tempfile
import unittest
from pathlib import Path


PROJECT_DIR = Path(__file__).resolve().parents[1]
WRITER = PROJECT_DIR / "bin" / "omarchy-dashboard-write-state"


class StateWriterTests(unittest.TestCase):
    def run_writer(self, path: Path, content: bytes, maximum: int = 64) -> subprocess.CompletedProcess[bytes]:
        return subprocess.run(
            ["/usr/bin/python3", "-I", str(WRITER), str(path), str(len(content)), str(maximum)],
            input=content,
            capture_output=True,
            check=False,
            timeout=2,
        )

    def test_creates_a_private_parent_and_regular_state_file(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "new" / "state.json"
            result = self.run_writer(path, b'{"version":1}')
            self.assertEqual(result.returncode, 0)
            self.assertEqual(path.read_bytes(), b'{"version":1}')
            self.assertEqual(path.stat().st_mode & 0o777, 0o600)

    def test_refuses_a_symlink_leaf_without_touching_its_target(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            target = root / "target.json"
            target.write_bytes(b"original")
            state = root / "state.json"
            state.symlink_to(target)
            result = self.run_writer(state, b"replacement")
            self.assertEqual(result.returncode, 3)
            self.assertEqual(target.read_bytes(), b"original")
            self.assertTrue(state.is_symlink())

    def test_refuses_an_insecure_parent(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory) / "insecure"
            root.mkdir()
            root.chmod(0o777)
            result = self.run_writer(root / "state.json", b"{}")
            self.assertEqual(result.returncode, 3)

    def test_bounds_stdin_before_publishing(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "state.json"
            result = self.run_writer(path, b"x" * 65)
            self.assertEqual(result.returncode, 2)
            self.assertFalse(path.exists())

    def test_rejects_relative_paths(self) -> None:
        self.assertEqual(self.run_writer(Path("relative-state.json"), b"{}").returncode, 3)


if __name__ == "__main__":
    unittest.main()
