import importlib.util
import json
import os
import subprocess
import sys
import tempfile
import unittest
from concurrent.futures import ThreadPoolExecutor
from unittest import mock
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
ADAPTER_DIR = ROOT / "qml" / "adapters"
SPEC = importlib.util.spec_from_file_location("adapter", ROOT / "lib" / "omarchy_dashboard_adapter.py")
adapter = importlib.util.module_from_spec(SPEC)
assert SPEC.loader is not None
sys.modules[SPEC.name] = adapter
SPEC.loader.exec_module(adapter)


PANEL = """import QtQuick
Panel {
  id: root
  IpcHandler { function close() { root.close() } }
  BarIconButton { onPressed: root.close() }
  Shortcut { sequence: "Escape"; enabled: root.opened }
  Shortcut { sequence: "/" }
  KeyboardPanel { open: root.opened }
}
"""

MAPPED_PANEL = """import QtQuick
import Quickshell
import Quickshell.Wayland
Item {
  id: root
  property var shell: null
  property bool opened: false
  function open() { root.opened = true }
  function close() { root.opened = false }
  function dismiss() {
    if (root.shell && typeof root.shell.hide === "function") root.shell.hide("example.plugin")
    else root.close()
  }
  PanelWindow {
    visible: root.opened
    anchors { top: true; bottom: true; left: true; right: true }
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.namespace: "example"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
    Item { id: focusTarget }
  }
}
"""

MAPPED_CARD = MAPPED_PANEL.replace(
    "    Item { id: focusTarget }",
    """    Rectangle { anchors.fill: parent }
    BorderSurface {
      anchors.centerIn: parent
      width: Math.min(780, window.width - 16)
      height: Math.min(620, window.height - 16)
      padding: 12
      Item { id: focusTarget }
    }""",
)


class AdapterTests(unittest.TestCase):
    def write_source(self, directory: Path, content: str = PANEL) -> Path:
        source = directory / "source"
        source.mkdir()
        (source / "Panel.qml").write_text(content)
        return source

    def test_transforms_only_syntax_tokens_and_preserves_nested_close(self):
        transformed = adapter.transform_qml(PANEL + "// KeyboardPanel { root.controller.hide()\n")
        self.assertIn("property var dashboardHost: null", transformed)
        self.assertIn("DashboardDisabledIpc { function close()", transformed)
        self.assertIn("DashboardHiddenBarButton {", transformed)
        self.assertIn("DashboardHost {\n    anchors.fill: parent\n    dashboardHost: root.dashboardHost", transformed)
        self.assertIn("function dashboardFocus()", transformed)
        self.assertIn("onFocusTargetChanged: root.dashboardFocusTarget = focusTarget", transformed)
        self.assertIn("function close() { root.close() }", transformed)
        self.assertIn('sequence: root.dashboardHost ? "" : "Escape"', transformed)
        self.assertIn('sequence: "/"', transformed)
        self.assertIn("// KeyboardPanel { root.controller.hide()", transformed)

    def test_disables_single_quoted_escape_without_touching_string_contents(self):
        transformed = adapter.transform_qml(PANEL.replace(
            'sequence: "Escape"', "sequence: 'Escape'"
        ) + '// Shortcut { sequence: "Escape" }\n')

        self.assertIn("sequence: root.dashboardHost ? \"\" : 'Escape'", transformed)
        self.assertIn('// Shortcut { sequence: "Escape" }', transformed)

    def test_regex_literals_do_not_create_fake_surfaces_or_break_quoting(self):
        expressions = [
            r'''var match = lines[i].match(/^\s*green\s*=\s*["']?(#[0-9A-Fa-f]{6})/)''',
            r'''var pattern = /PanelWindow { ["'{}\/] }/gi''',
            r'''return /[/*]/.test(value)''',
            r'''var ratio = width / 2; var re = /x{2}/; var remainder = height / 3''',
        ]
        for expression in expressions:
            with self.subTest(expression=expression):
                source = PANEL.replace('  id: root', '  id: root\n  function parse() { ' + expression + ' }')
                transformed = adapter.transform_qml(source)
                self.assertIn(expression, transformed)
                self.assertIn('DashboardHost {', transformed)
        with self.assertRaisesRegex(adapter.AdaptationError, "mapped surface"):
            adapter.transform_qml(PANEL.replace('  id: root', '  id: root\n  PanelWindow {}'))

    def test_adapts_a_floating_window_and_preserves_its_local_lifecycle(self):
        source = MAPPED_PANEL.replace('PanelWindow {', 'FloatingWindow {').replace(
            '    visible: root.opened',
            '    title: "Settings"\n    minimumSize: Qt.size(400, 300)\n    visible: root.opened',
        )
        transformed, layout = adapter.adapt_qml(source)
        self.assertEqual(layout, adapter.EDGE_TO_EDGE_LAYOUT)
        self.assertNotIn('FloatingWindow {', transformed)
        self.assertIn('minimumSize: Qt.size(400, 300)', transformed)
        self.assertIn('function close() { root.opened = false }', transformed)
        self.assertIn('root.dashboardHost.handleEscape(); return', transformed)
        with self.assertRaisesRegex(adapter.AdaptationError, 'exactly one'):
            adapter.adapt_qml(source.replace('FloatingWindow {', 'PopupWindow {}\n  FloatingWindow {'))

    def test_does_not_replace_a_declared_mapped_page_with_an_unrelated_sibling(self):
        with tempfile.TemporaryDirectory() as temporary:
            source = self.write_source(Path(temporary))
            (source / 'Overlay.qml').write_text(MAPPED_PANEL)
            self.assertEqual(adapter.choose_source(source, 'Overlay.qml').name, 'Overlay.qml')

    def test_named_sibling_discovery_includes_mapped_panels_and_ignores_broken_files(self):
        with tempfile.TemporaryDirectory() as temporary:
            source = self.write_source(Path(temporary), 'Item {}')
            (source / 'Bar.qml').write_text('Item {}')
            (source / 'BrokenPanel.qml').write_text('Item { "')
            (source / 'SettingsPanel.qml').write_text(MAPPED_PANEL.replace('PanelWindow {', 'FloatingWindow {'))
            self.assertEqual(adapter.choose_source(source, 'Bar.qml').name, 'SettingsPanel.qml')

    def test_fallback_entry_points_share_one_validated_source_snapshot(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            source = self.write_source(root, 'Item {}')
            (source / 'Overlay.qml').write_text(MAPPED_PANEL)
            with mock.patch.object(adapter, 'copy_tree', wraps=adapter.copy_tree) as copy:
                output = adapter.build(source, ['Missing.qml', 'Panel.qml', 'Overlay.qml'],
                                       root / 'cache', 'example.plugin', ADAPTER_DIR)
            self.assertEqual(output.name, 'Overlay.qml')
            self.assertIn('DashboardHost {', output.read_text())
            self.assertEqual(copy.call_count, 1)
            self.assertEqual((source / 'Overlay.qml').read_text(), MAPPED_PANEL)

    def test_fallback_failure_reports_each_attempt_without_publishing_an_artifact(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            source = self.write_source(root, 'Item {}')
            with self.assertRaises(adapter.AdaptationError) as failure:
                adapter.build(source, ['Panel.qml', 'Missing.qml'], root / 'cache',
                              'example.plugin', ADAPTER_DIR)
            self.assertIn('Panel.qml:', str(failure.exception))
            self.assertIn('Missing.qml:', str(failure.exception))
            self.assertEqual(list((root / 'cache').rglob(adapter.MARKER_NAME)), [])

    def test_generated_floating_panel_loads_resizes_and_returns_escape_to_host(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            source = self.write_source(root, '''import QtQuick
Item {
  id: root
  function open() { surface.visible = true }
  function close() { surface.visible = false }
  FloatingWindow {
    id: surface
    objectName: "surface"
    title: "Settings"
    implicitWidth: 720
    implicitHeight: 500
    minimumSize: Qt.size(400, 300)
    maximumSize: Qt.size(1200, 900)
    color: "red"
    visible: false
    Rectangle { objectName: "content"; anchors.fill: parent; color: "blue" }
  }
}
''')
            output = adapter.build(source, 'Panel.qml', root / 'cache', 'example.plugin', ADAPTER_DIR)
            suite = root / 'tst_Embedded.qml'
            suite.write_text('''import QtQuick
import QtTest
TestCase {
  id: test
  name: "AdaptedFloatingPanel"
  when: windowShown
  visible: true
  width: 640
  height: 480
  property string mode: "interact"
  property int escapes: 0
  property var registeredSurface: null
  function registerSurface(surface) { registeredSurface = surface }
  function handleEscape() { escapes += 1 }
  function test_lifecycle() {
    var component = Qt.createComponent(''' + json.dumps(output.as_uri()) + ''')
    compare(component.status, Component.Ready, component.errorString())
    var page = createTemporaryObject(component, test, { width: 640, height: 480, dashboardHost: test })
    verify(page !== null)
    var surface = findChild(page, "surface")
    var content = findChild(page, "content")
    verify(surface !== null)
    verify(content !== null)
    compare(surface.parent, page)
    compare(test.registeredSurface, surface)
    compare(surface.dashboardPreferredWidth, 720)
    compare(surface.dashboardPreferredHeight, 500)
    verify(!surface.visible)
    page.open()
    verify(surface.visible)
    compare(content.width, 640)
    compare(content.height, 480)
    page.width = 800
    compare(content.width, 800)
    compare(surface.fittedContentWidth(1000), 800)
    tryCompare(surface, "dashboardPreferredWidth", 1000)
    compare(surface.fittedContentHeight(900), 480)
    tryCompare(surface, "dashboardPreferredHeight", 900)
    content.forceActiveFocus()
    keyClick(Qt.Key_Escape)
    compare(test.escapes, 1)
    page.close()
    verify(!surface.visible)
  }
}
''')
            runner = os.environ.get('QMLTESTRUNNER', '/usr/lib/qt6/bin/qmltestrunner')
            result = subprocess.run([runner, '-input', str(suite), '-o', '-,txt'],
                                    env={**os.environ, 'QT_QPA_PLATFORM': 'offscreen'},
                                    capture_output=True, text=True, timeout=30)
            self.assertEqual(result.returncode, 0, result.stdout + result.stderr)

    def test_large_preview_assets_are_preserved_in_the_validated_copy(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            source = self.write_source(root)
            preview = b'x' * (3 * 1024 * 1024)
            (source / 'preview.png').write_bytes(preview)
            output = adapter.build(source, 'Panel.qml', root / 'cache', 'example.plugin', ADAPTER_DIR)
            self.assertEqual((output.parent / 'preview.png').read_bytes(), preview)

    def test_comment_only_host_falls_back_to_sibling_panel(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            source = root / "source"
            source.mkdir()
            (source / "BarWidget.qml").write_text("// KeyboardPanel {\nItem {}\n")
            (source / "Panel.qml").write_text(PANEL)
            self.assertEqual(adapter.choose_source(source, "BarWidget.qml").name, "Panel.qml")

    def test_discovers_a_unique_named_sibling_panel(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            source = root / "source"
            source.mkdir()
            (source / "BarWidget.qml").write_text("Item {}\n")
            (source / "OmatePanel.qml").write_text(PANEL)

            self.assertEqual(adapter.choose_source(source, "BarWidget.qml").name, "OmatePanel.qml")

    def test_rejects_ambiguous_named_sibling_panels(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            source = root / "source"
            source.mkdir()
            (source / "BarWidget.qml").write_text("Item {}\n")
            (source / "FirstPanel.qml").write_text(PANEL)
            (source / "SecondPanel.qml").write_text(PANEL)

            with self.assertRaisesRegex(adapter.AdaptationError, "ambiguous sibling panel"):
                adapter.choose_source(source, "BarWidget.qml")

    def test_rejects_custom_windows_and_ambiguous_hosts(self):
        with self.assertRaisesRegex(adapter.AdaptationError, "mapped surface"):
            adapter.transform_qml("""Panel {
  id: root
  PanelWindow {}
  KeyboardPanel {}
}
""")
        with self.assertRaisesRegex(adapter.AdaptationError, "exactly one"):
            adapter.transform_qml(PANEL.replace("KeyboardPanel {", "KeyboardPanel {}\n  KeyboardPanel {"))

    def test_adapts_one_nested_panel_window_without_touching_lifecycle(self):
        transformed = adapter.transform_qml(MAPPED_PANEL)

        self.assertIn("property var dashboardHost: null", transformed)
        self.assertIn("DashboardHost {\n    anchors.fill: parent\n    dashboardHost: root.dashboardHost\n    page: root", transformed)
        self.assertNotIn("anchors { top: true", transformed)
        self.assertNotIn("PanelWindow {", transformed)
        self.assertNotIn("WlrLayershell.namespace", transformed)
        self.assertIn("root.dashboardHost.handleEscape(); return", transformed)
        self.assertIn("function close() { root.opened = false }", transformed)

    def test_selects_layout_from_the_adapted_surface_shape(self):
        self.assertEqual(adapter.adaptation_layout(PANEL), adapter.PADDED_LAYOUT)
        self.assertEqual(adapter.adaptation_layout(MAPPED_PANEL), adapter.EDGE_TO_EDGE_LAYOUT)

    def test_expands_a_conventional_mapped_window_card_to_the_host_edges(self):
        transformed = adapter.transform_qml(MAPPED_CARD)

        self.assertNotIn("anchors.centerIn: parent", transformed)
        self.assertNotIn("width: Math.min(780", transformed)
        self.assertNotIn("height: Math.min(620", transformed)
        self.assertIn("BorderSurface {\n      anchors.fill: parent\n      padding: 12", transformed)

    def test_rejects_ambiguous_or_non_panel_mapped_surfaces(self):
        with self.assertRaisesRegex(adapter.AdaptationError, "exactly one"):
            adapter.transform_qml(MAPPED_PANEL.replace("PanelWindow {", "PanelWindow {}\n  PanelWindow {"))
        with self.assertRaisesRegex(adapter.AdaptationError, "exactly one nested PanelWindow"):
            adapter.transform_qml(MAPPED_PANEL.replace("PanelWindow {", "PopupWindow {"))

    def test_build_is_non_destructive_and_uses_immutable_fingerprint(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            source = self.write_source(root)
            cache = root / "cache"
            output = adapter.build(source, "Panel.qml", cache, "example.plugin", ADAPTER_DIR)
            self.assertTrue(output.is_file())
            self.assertEqual((source / "Panel.qml").read_text(), PANEL)
            self.assertTrue((output.parent / "DashboardHost.qml").is_file())
            self.assertIn("property bool dimmed", (output.parent / "DashboardHiddenBarButton.qml").read_text())
            self.assertEqual(adapter.artifact_layout(output, cache), adapter.PADDED_LAYOUT)
            self.assertEqual(output, adapter.build(source, "Panel.qml", cache, "example.plugin", ADAPTER_DIR))

    def test_ignores_root_vcs_metadata_when_building_a_runtime_artifact(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            source = self.write_source(root)
            pack = source / ".git" / "objects" / "pack" / "plugin.pack"
            pack.parent.mkdir(parents=True)
            pack.write_bytes(b"x" * (adapter.MAX_SOURCE_FILE_BYTES + 1))

            output = adapter.build(source, "Panel.qml", root / "cache", "example.plugin", ADAPTER_DIR)

            self.assertTrue(output.is_file())
            self.assertFalse((output.parent / ".git").exists())

    def test_mapped_panel_artifact_publishes_edge_to_edge_layout(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            source = self.write_source(root, MAPPED_PANEL)
            cache = root / "cache"

            output = adapter.build(source, "Panel.qml", cache, "example.plugin", ADAPTER_DIR)

            self.assertEqual(adapter.artifact_layout(output, cache), adapter.EDGE_TO_EDGE_LAYOUT)

    def test_build_rebases_relative_imports_outside_the_plugin(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            source = root / "source"
            source.mkdir()
            components = root / "components"
            components.mkdir()
            (source / "Panel.qml").write_text(
                """import QtQuick
import "../components" as Components
Panel {
  id: root
  KeyboardPanel { open: root.opened }
}
"""
            )

            output = adapter.build(source, "Panel.qml", root / "cache", "example.plugin", ADAPTER_DIR)
            self.assertIn(f'import "{components.as_uri()}" as Components', output.read_text())

    def test_rejects_escape_and_symlinked_source(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            source = self.write_source(root)
            with self.assertRaisesRegex(adapter.AdaptationError, "outside"):
                adapter.build(source, "../outside.qml", root / "cache", "example.plugin", ADAPTER_DIR)
            (source / "linked.qml").symlink_to(source / "Panel.qml")
            with self.assertRaisesRegex(adapter.AdaptationError, "symlink"):
                adapter.build(source, "Panel.qml", root / "cache", "example.plugin", ADAPTER_DIR)

    def test_rejects_an_entry_point_larger_than_one_megabyte_before_adapting(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            source = self.write_source(root, PANEL + " " * (1024 * 1024))

            with self.assertRaisesRegex(adapter.AdaptationError, "entry point exceeds"):
                adapter.build(source, "Panel.qml", root / "cache", "example.plugin", ADAPTER_DIR)

    def test_rejects_a_plugin_tree_with_more_than_1024_files_before_copying(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            source = self.write_source(root)
            for index in range(1024):
                (source / f"extra-{index}.qml").write_text("Item {}\n")

            with mock.patch.object(adapter, "MAX_SOURCE_ENTRIES", 2048):
                with self.assertRaisesRegex(adapter.AdaptationError, "too many files"):
                    adapter.build(source, "Panel.qml", root / "cache", "example.plugin", ADAPTER_DIR)

    def test_rejects_a_plugin_tree_larger_than_its_byte_budget_before_copying(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            source = self.write_source(root)
            (source / "asset.bin").write_bytes(b"x" * 64)

            with mock.patch.object(adapter, "MAX_SOURCE_TREE_BYTES", len(PANEL.encode("utf-8"))):
                with self.assertRaisesRegex(adapter.AdaptationError, "tree exceeds"):
                    adapter.build(source, "Panel.qml", root / "cache", "example.plugin", ADAPTER_DIR)

    def test_rejects_cache_overlap_before_creating_staging_files(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            source = self.write_source(root)
            with self.assertRaisesRegex(adapter.AdaptationError, "overlap"):
                adapter.build(source, "Panel.qml", source / "cache", "example.plugin", ADAPTER_DIR)
            self.assertFalse((source / "cache").exists())

    def test_rejects_symlinked_cache_ancestor_before_reading_destination(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            source = self.write_source(root)
            real_cache = root / "real-cache"
            real_cache.mkdir()
            linked_cache = root / "linked-cache"
            linked_cache.symlink_to(real_cache, target_is_directory=True)
            with self.assertRaisesRegex(adapter.AdaptationError, "symlinked ancestors"):
                adapter.build(source, "Panel.qml", linked_cache, "example.plugin", ADAPTER_DIR)

    def test_repairs_a_corrupted_cached_artifact(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            source = self.write_source(root)
            cache = root / "cache"
            output = adapter.build(source, "Panel.qml", cache, "example.plugin", ADAPTER_DIR)
            artifact = output.parent
            artifact.chmod(0o700)
            output.chmod(0o600)
            output.write_text("Item {}")
            artifact.chmod(0o500)

            repaired = adapter.build(source, "Panel.qml", cache, "example.plugin", ADAPTER_DIR)

            self.assertEqual(repaired, output)
            self.assertIn("DashboardHost {", repaired.read_text())

    def test_repairs_an_artifact_with_a_non_object_marker(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            source = self.write_source(root)
            cache = root / "cache"
            output = adapter.build(source, "Panel.qml", cache, "example.plugin", ADAPTER_DIR)
            marker = output.parent / adapter.MARKER_NAME
            marker.chmod(0o600)
            marker.write_text('["version","fingerprint","entryPoint","artifactDigest"]')

            repaired = adapter.build(source, "Panel.qml", cache, "example.plugin", ADAPTER_DIR)

            self.assertEqual(repaired, output)
            self.assertIn("DashboardHost {", repaired.read_text())

    def test_repairs_an_artifact_with_excessively_nested_marker_json(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            source = self.write_source(root)
            cache = root / "cache"
            output = adapter.build(source, "Panel.qml", cache, "example.plugin", ADAPTER_DIR)
            marker = output.parent / adapter.MARKER_NAME
            marker.chmod(0o600)
            marker.write_text("[" * 1100 + "0" + "]" * 1100)

            repaired = adapter.build(source, "Panel.qml", cache, "example.plugin", ADAPTER_DIR)

            self.assertEqual(repaired, output)
            self.assertIn("DashboardHost {", repaired.read_text())

    def test_entry_point_is_part_of_the_artifact_identity(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            source = self.write_source(root)
            (source / "Other.qml").write_text(PANEL.replace("id: root", "id: other"))

            first = adapter.build(source, "Panel.qml", root / "cache", "example.plugin", ADAPTER_DIR)
            second = adapter.build(source, "Other.qml", root / "cache", "example.plugin", ADAPTER_DIR)

            self.assertNotEqual(first.parent, second.parent)
            self.assertIn("DashboardHost {", first.read_text())
            self.assertIn("DashboardHost {", second.read_text())

    def test_file_mode_changes_invalidate_the_artifact(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            source = self.write_source(root)
            helper = source / "helper.sh"
            helper.write_text("#!/bin/sh\n")
            helper.chmod(0o644)

            first = adapter.build(source, "Panel.qml", root / "cache", "example.plugin", ADAPTER_DIR)
            helper.chmod(0o755)
            second = adapter.build(source, "Panel.qml", root / "cache", "example.plugin", ADAPTER_DIR)

            self.assertNotEqual(first.parent, second.parent)
            self.assertFalse(os.stat(first.parent / "helper.sh").st_mode & 0o111)
            self.assertTrue(os.stat(second.parent / "helper.sh").st_mode & 0o111)

    def test_adapter_helper_changes_invalidate_the_artifact(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            source = self.write_source(root)
            adapter_dir = root / "adapter"
            adapter_dir.mkdir()
            for helper in adapter.HELPER_NAMES:
                (adapter_dir / helper).write_bytes((ADAPTER_DIR / helper).read_bytes())

            first = adapter.build(source, "Panel.qml", root / "cache", "example.plugin", adapter_dir)
            host = adapter_dir / "DashboardHost.qml"
            host.write_text(host.read_text() + "\n// changed\n")
            second = adapter.build(source, "Panel.qml", root / "cache", "example.plugin", adapter_dir)

            self.assertNotEqual(first.parent, second.parent)

    def test_nested_entry_point_uses_its_sibling_panel_and_helpers(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            source = root / "source"
            nested = source / "nested"
            nested.mkdir(parents=True)
            (nested / "BarWidget.qml").write_text("import QtQuick\nItem {}\n")
            (nested / "Panel.qml").write_text(PANEL)

            output = adapter.build(source, "nested/BarWidget.qml", root / "cache", "example.plugin", ADAPTER_DIR)

            self.assertEqual(output.name, "Panel.qml")
            self.assertEqual(output.parent.name, "nested")
            for helper in adapter.HELPER_NAMES:
                self.assertTrue((output.parent / helper).is_file())

    def test_rejects_helper_name_collisions(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            source = self.write_source(root)
            (source / "DashboardHost.qml").write_text("Item {}\n")

            with self.assertRaisesRegex(adapter.AdaptationError, "collides"):
                adapter.build(source, "Panel.qml", root / "cache", "example.plugin", ADAPTER_DIR)

    def test_rejects_relative_and_insecure_cache_roots(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            source = self.write_source(root)
            with self.assertRaisesRegex(adapter.AdaptationError, "absolute"):
                adapter.build(source, "Panel.qml", Path("relative-cache"), "example.plugin", ADAPTER_DIR)

            insecure = root / "insecure"
            insecure.mkdir()
            insecure.chmod(0o777)
            with self.assertRaisesRegex(adapter.AdaptationError, "insecure cache ancestor"):
                adapter.build(source, "Panel.qml", insecure / "cache", "example.plugin", ADAPTER_DIR)

    def test_tree_digest_has_unambiguous_file_boundaries(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            first = root / "first"
            second = root / "second"
            first.mkdir()
            second.mkdir()
            (first / "a").write_bytes(b"F:b\0X")
            (second / "a").write_bytes(b"")
            (second / "b").write_bytes(b"X")

            self.assertNotEqual(adapter.source_tree_digest(first), adapter.source_tree_digest(second))

    def test_concurrent_builds_publish_one_valid_artifact(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            source = self.write_source(root)
            cache = root / "cache"

            def build(_: int) -> Path:
                return adapter.build(source, "Panel.qml", cache, "example.plugin", ADAPTER_DIR)

            with ThreadPoolExecutor(max_workers=4) as executor:
                outputs = list(executor.map(build, range(4)))

            self.assertEqual(len(set(outputs)), 1)
            self.assertIn("DashboardHost {", outputs[0].read_text())

    def test_nested_directories_cannot_bypass_the_global_entry_limit(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            source = self.write_source(root)
            first = source / "first"
            second = source / "second"
            first.mkdir()
            second.mkdir()
            (first / "one").write_text("1")
            (first / "two").write_text("2")

            with mock.patch.object(adapter, "MAX_SOURCE_ENTRIES", 4):
                with self.assertRaisesRegex(adapter.AdaptationError, "too many entries"):
                    adapter.source_tree_digest(source)

    def test_rejects_a_source_tree_that_is_too_deeply_nested(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            source = self.write_source(root)
            nested = source / "one"
            nested.mkdir()
            (nested / "two").mkdir()

            with mock.patch.object(adapter, "MAX_SOURCE_DEPTH", 1):
                with self.assertRaisesRegex(adapter.AdaptationError, "too deeply nested"):
                    adapter.source_tree_digest(source)

    def test_remove_tree_unlinks_symlinks_instead_of_following_them(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            target = root / "outside"
            target.mkdir()
            important = target / "important"
            important.write_text("keep")
            tree = root / "tree"
            tree.mkdir()
            (tree / "link").symlink_to(target, target_is_directory=True)

            adapter.remove_tree(tree)

            self.assertEqual(important.read_text(), "keep")
            self.assertFalse(tree.exists())

    def test_stale_cleanup_does_not_remove_an_active_build(self):
        with tempfile.TemporaryDirectory() as temporary:
            staging_parent = Path(temporary)
            staging = staging_parent / "adapter-active"
            staging.mkdir()
            lock_path = staging / ".active"
            lock_path.touch()
            descriptor = os.open(lock_path, os.O_RDWR)
            adapter.fcntl.flock(descriptor, adapter.fcntl.LOCK_EX)
            old = adapter.time.time() - adapter.STALE_STAGING_SECONDS - 1
            os.utime(staging, (old, old))
            try:
                adapter.clean_stale_staging(staging_parent)
                self.assertTrue(staging.is_dir())
            finally:
                os.close(descriptor)

            adapter.clean_stale_staging(staging_parent)
            self.assertFalse(staging.exists())


if __name__ == "__main__":
    unittest.main()
