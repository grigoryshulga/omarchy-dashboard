import importlib.util
import json
import sys
import tempfile
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
SPEC = importlib.util.spec_from_file_location("icons", ROOT / "lib" / "omarchy_dashboard_icons.py")
icons = importlib.util.module_from_spec(SPEC)
assert SPEC.loader is not None
sys.modules[SPEC.name] = icons
SPEC.loader.exec_module(icons)


class IconDiscoveryTests(unittest.TestCase):
    def plugin(self, root: Path, plugin_id: str, entry: str) -> Path:
        directory = root / plugin_id
        directory.mkdir()
        (directory / "manifest.json").write_text(json.dumps({
            "id": plugin_id,
            "entryPoints": {"barWidget": "BarWidget.qml"},
        }))
        (directory / "BarWidget.qml").write_text(entry)
        return directory

    def test_prefers_conventional_image_without_reading_preview(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            plugin = self.plugin(root, "image.plugin", "Item {}")
            (plugin / "icon.png").write_bytes(b"icon")
            (plugin / "preview.png").write_bytes(b"preview")

            result = icons.discover([root])
            self.assertEqual(result["image.plugin"]["kind"], "image")
            self.assertTrue(result["image.plugin"]["value"].endswith("/icon.png"))

    def test_extracts_declared_glyph_and_ignores_comments_and_labels(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            self.plugin(root, "glyph.plugin", '''
// property string icon: "󰅙"
Item {
  readonly property string icon: "\\ue75c"
  Text { text: "Settings" }
}
''')

            result = icons.discover([root])
            self.assertEqual(result["glyph.plugin"], {"kind": "glyph", "value": "\ue75c"})

    def test_dynamic_or_unsafe_icons_fall_through(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            plugin = self.plugin(root, "dynamic.plugin", 'Item { property string icon: model.icon }')
            manifest = json.loads((plugin / "manifest.json").read_text())
            manifest["icon"] = "../outside.png"
            (plugin / "manifest.json").write_text(json.dumps(manifest))
            self.assertNotIn("dynamic.plugin", icons.discover([root]))
