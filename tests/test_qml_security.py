from __future__ import annotations

import re
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]


class QmlSecurityTests(unittest.TestCase):
    def test_every_text_renderer_is_explicitly_plain_text(self) -> None:
        for path in sorted((ROOT / "qml").rglob("*.qml")):
            lines = path.read_text(encoding="utf-8").splitlines()
            for index, line in enumerate(lines):
                if re.search(r"\bText\s*\{\s*$", line):
                    self.assertLess(index + 1, len(lines), path)
                    self.assertIn(
                        "textFormat: Text.PlainText", lines[index + 1],
                        f"{path.relative_to(ROOT)}:{index + 1}",
                    )

    def test_every_text_input_has_a_length_limit(self) -> None:
        for path in sorted((ROOT / "qml").rglob("*.qml")):
            source = path.read_text(encoding="utf-8")
            for match in re.finditer(r"\bTextInput\s*\{", source):
                block = source[match.start():]
                next_input = block.find("TextInput {", len("TextInput {"))
                candidate = block if next_input < 0 else block[:next_input]
                self.assertIn(
                    "maximumLength:", candidate,
                    f"unbounded TextInput in {path.relative_to(ROOT)}",
                )


if __name__ == "__main__":
    unittest.main()
