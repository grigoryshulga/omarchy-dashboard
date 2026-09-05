"""Exercise the save queue with real Quickshell processes and state helpers."""

from __future__ import annotations

import json
import os
from pathlib import Path
import subprocess
import tempfile
import unittest


ROOT = Path(__file__).resolve().parents[1]


class StateStoreTests(unittest.TestCase):
    def check_save_queue(self, edit_during_write: bool, fail_first: bool = False) -> None:
        with tempfile.TemporaryDirectory() as directory:
            state_path = Path(directory) / "state.json"
            config = Path(directory) / "shell.qml"
            writer = ROOT / "bin/omarchy-dashboard-write-state"
            if fail_first:
                wrapper = Path(directory) / "fail_once.py"
                wrapper.write_text(f"""
from pathlib import Path
import runpy
import sys
marker = Path(__file__).with_suffix('.attempted')
if not marker.exists():
    marker.touch()
    sys.exit(4)
runpy.run_path({str(writer)!r}, run_name='__main__')
""", encoding="utf-8")
                writer = wrapper
            config.write_text(f"""
import QtQuick
import Quickshell
import {json.dumps((ROOT / 'qml/state').as_uri())} as State

ShellRoot {{
  property int writes: 0
  property bool edited: false
  State.DashboardStore {{
    id: store
    statePath: {json.dumps(str(state_path))}
    readerPath: {json.dumps(str(ROOT / 'bin/omarchy-dashboard-read-state'))}
    writerPath: {json.dumps(str(writer))}
    onWriteInProgressChanged: {{
      if (!writeInProgress) return
      writes += 1
      if ({str(edit_during_write).lower()} && !edited) {{
        edited = true
        document = Object.assign({{}}, document, {{ gridSpacing: 20 }})
        scheduleSave()
      }}
    }}
  }}
  Timer {{
    interval: {2500 if fail_first else 1500}
    running: true
    onTriggered: {{
      console.log("STATE_STORE_RESULT=" + JSON.stringify({{
        ready: store.ready, writes: writes,
        pending: store.pendingText, writing: store.writeInProgress
      }}))
      Qt.quit()
    }}
  }}
}}
""", encoding="utf-8")
            result = subprocess.run(
                ["quickshell", "--no-color", "--path", str(config)],
                env={**os.environ, "QT_QPA_PLATFORM": "offscreen"},
                capture_output=True, text=True, timeout=8, check=False,
            )
            output = result.stdout + result.stderr
            self.assertEqual(result.returncode, 0, output)
            reports = [line.split("STATE_STORE_RESULT=", 1)[1]
                       for line in output.splitlines() if "STATE_STORE_RESULT=" in line]
            self.assertEqual(len(reports), 1, output)
            report = json.loads(reports[0])
            self.assertTrue(report["ready"], output)
            self.assertEqual(report["writes"], 1 + edit_during_write + fail_first, output)
            self.assertEqual(report["pending"], "", output)
            self.assertFalse(report["writing"], output)
            saved = json.loads(state_path.read_text(encoding="utf-8"))
            self.assertEqual(saved["gridSpacing"], 20 if edit_during_write else 10)

    def test_successful_save_becomes_idle(self) -> None:
        self.check_save_queue(edit_during_write=False)

    def test_edit_during_write_saves_latest_document_then_becomes_idle(self) -> None:
        self.check_save_queue(edit_during_write=True)

    def test_failed_save_retries_then_becomes_idle(self) -> None:
        self.check_save_queue(edit_during_write=False, fail_first=True)


if __name__ == "__main__":
    unittest.main()
