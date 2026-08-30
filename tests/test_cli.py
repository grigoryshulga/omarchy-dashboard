from __future__ import annotations

import contextlib
import io
import sys
import unittest

from lib import omarchy_dashboard_cli as cli


class FakeDashboard:
    def __init__(self, responses=None):
        self.requests = []
        self.responses = list(responses or [])
        self.opened = False

    def execute(self, request):
        self.requests.append(request)
        if self.responses:
            return self.responses.pop(0)
        return {"ok": True, "changed": True, "placement": {"pluginId": request.get("pluginId")}}

    def open(self):
        self.opened = True


class FakeInstaller:
    def __init__(self, plugin_id="example.weather"):
        self.plugin_id = plugin_id
        self.installs = []
        self.uninstalls = []

    def install(self, source, assume_yes=False):
        self.installs.append((source, assume_yes))
        return self.plugin_id

    def uninstall(self, plugin_id, assume_yes=False):
        self.uninstalls.append((plugin_id, assume_yes))


class DashboardCliTests(unittest.TestCase):
    def invoke(self, argv, dashboard=None, installer=None):
        output = io.StringIO()
        error = io.StringIO()
        exit_code = cli.main(
            argv,
            dashboard=dashboard or FakeDashboard(),
            installer=installer or FakeInstaller(),
            output=output,
            error=error,
        )
        return exit_code, output.getvalue(), error.getvalue()

    def test_add_defaults_to_pending(self):
        dashboard = FakeDashboard()
        exit_code, _, _ = self.invoke(["plugin", "add", "example.weather"], dashboard=dashboard)
        self.assertEqual(exit_code, 0)
        self.assertEqual(dashboard.requests[0]["operation"], "ensure")
        self.assertEqual(dashboard.requests[0]["target"], "pending")

    def test_add_can_request_exact_placement(self):
        dashboard = FakeDashboard()
        exit_code, _, _ = self.invoke(
            ["plugin", "add", "example.weather", "--space", "work", "--rect", "20,40,360,260"],
            dashboard=dashboard,
        )
        self.assertEqual(exit_code, 0)
        self.assertEqual(dashboard.requests[0]["target"], "placed")
        self.assertEqual(dashboard.requests[0]["strategy"], "exact")
        self.assertEqual(dashboard.requests[0]["rect"], {"x": 20, "y": 40, "w": 360, "h": 260})

    def test_install_discovers_id_then_creates_pending_placement(self):
        dashboard = FakeDashboard()
        installer = FakeInstaller("installed.plugin")
        exit_code, _, _ = self.invoke(
            ["plugin", "install", "https://example.test/plugin.git", "--yes"],
            dashboard=dashboard,
            installer=installer,
        )
        self.assertEqual(exit_code, 0)
        self.assertEqual(installer.installs, [("https://example.test/plugin.git", True)])
        self.assertEqual(dashboard.requests[0]["pluginId"], "installed.plugin")

    def test_json_install_requires_non_interactive_confirmation(self):
        installer = FakeInstaller()
        exit_code, output, _ = self.invoke(
            ["plugin", "install", "https://example.test/plugin.git", "--json"],
            installer=installer,
        )
        self.assertEqual(exit_code, 2)
        self.assertIn('"code": "interactive-json"', output)
        self.assertEqual(installer.installs, [])

    def test_place_requires_space_for_exact_rect(self):
        exit_code, _, error = self.invoke(["plugin", "place", "example.weather", "--rect", "0,0,360,260"])
        self.assertEqual(exit_code, 2)
        self.assertIn("--space is required", error)

    def test_list_filters_pending_placements(self):
        dashboard = FakeDashboard([{
            "ok": True,
            "placements": [
                {"pluginId": "one", "state": "pending", "spaceId": ""},
                {"pluginId": "two", "state": "placed", "spaceId": "work"},
            ],
        }])
        exit_code, output, _ = self.invoke(
            ["plugin", "list", "--state", "pending", "--json"], dashboard=dashboard
        )
        self.assertEqual(exit_code, 0)
        self.assertIn('"pluginId": "one"', output)
        self.assertNotIn('"pluginId": "two"', output)

    def test_list_space_filter_accepts_unique_space_name(self):
        dashboard = FakeDashboard([{
            "ok": True,
            "placements": [
                {"pluginId": "one", "state": "placed", "spaceId": "space-home", "spaceName": "Home"},
                {"pluginId": "two", "state": "placed", "spaceId": "space-work", "spaceName": "Work"},
            ],
        }])
        exit_code, output, _ = self.invoke(
            ["plugin", "list", "--space", "home", "--json"], dashboard=dashboard
        )
        self.assertEqual(exit_code, 0)
        self.assertIn('"pluginId": "one"', output)
        self.assertNotIn('"pluginId": "two"', output)

    def test_uninstall_refuses_while_hosted(self):
        dashboard = FakeDashboard([{
            "ok": True,
            "placements": [{"pluginId": "example.weather", "state": "pending"}],
        }])
        installer = FakeInstaller()
        exit_code, _, error = self.invoke(
            ["plugin", "uninstall", "example.weather"], dashboard=dashboard, installer=installer
        )
        self.assertEqual(exit_code, 4)
        self.assertIn("plugin-hosted", error)
        self.assertEqual(installer.uninstalls, [])

    def test_space_create_uses_dashboard_command_seam(self):
        dashboard = FakeDashboard()
        exit_code, _, _ = self.invoke(
            ["space", "create", "System", "--id", "space-system"], dashboard=dashboard
        )
        self.assertEqual(exit_code, 0)
        self.assertEqual(
            dashboard.requests[0],
            {
                "schemaVersion": 1,
                "operation": "space-create",
                "name": "System",
                "id": "space-system",
            },
        )

    def test_space_remove_requires_explicit_confirmation(self):
        dashboard = FakeDashboard()
        exit_code, _, error = self.invoke(["space", "remove", "System"], dashboard=dashboard)
        self.assertEqual(exit_code, 2)
        self.assertIn("confirmation-required", error)
        self.assertEqual(dashboard.requests, [])

    def test_grid_set_uses_dashboard_command_seam(self):
        dashboard = FakeDashboard()
        exit_code, _, _ = self.invoke(["grid", "set", "30"], dashboard=dashboard)
        self.assertEqual(exit_code, 0)
        self.assertEqual(
            dashboard.requests[0],
            {"schemaVersion": 1, "operation": "grid-set", "spacing": 30},
        )

    def test_add_text_sends_exact_space_rect_and_stable_id(self):
        dashboard = FakeDashboard()
        exit_code, _, _ = self.invoke(
            [
                "element", "add-text", "Life", "--space", "Home",
                "--rect", "30,15,660,45", "--id", "home-life-title",
            ],
            dashboard=dashboard,
        )
        self.assertEqual(exit_code, 0)
        self.assertEqual(
            dashboard.requests[0],
            {
                "schemaVersion": 1,
                "operation": "element-add-text",
                "space": "Home",
                "text": "Life",
                "rect": {"x": 30, "y": 15, "w": 660, "h": 45},
                "id": "home-life-title",
            },
        )

    def test_divider_parser_rejects_diagonal_line(self):
        with self.assertRaises(cli.argparse.ArgumentTypeError):
            cli.parse_line("0,0,10,10")

    def test_parser_rejects_oversized_text_and_unsafe_ids(self):
        with self.assertRaises(SystemExit):
            cli.parser().parse_args([
                "element", "add-text", "x" * (cli.MAX_TEXT_LENGTH + 1),
                "--space", "space-main", "--rect", "0,0,100,100",
            ])
        with self.assertRaises(SystemExit):
            cli.parser().parse_args(["plugin", "add", "__proto__"])

    def test_captured_subprocess_output_is_bounded(self):
        with self.assertRaises(cli.CliFailure) as raised:
            cli.run_captured(
                [sys.executable, "-c", f"print('x' * {cli.MAX_IPC_OUTPUT_BYTES + 1})"],
                timeout=5,
                failure_code="too-large",
                failure_exit_code=3,
            )
        self.assertEqual(raised.exception.code, "too-large")

    def test_human_output_neutralizes_terminal_controls(self):
        dashboard = FakeDashboard([{
            "ok": True,
            "spaces": [{"id": "space-main", "name": "safe\x1b[31m\u202e", "active": True}],
        }])
        exit_code, output, _ = self.invoke(["space", "list"], dashboard=dashboard)
        self.assertEqual(exit_code, 0)
        self.assertNotIn("\x1b", output)
        self.assertNotIn("\u202e", output)

    def test_root_help_teaches_agent_workflow_and_coordinate_contract(self):
        help_text = cli.parser().format_help()
        self.assertIn("agent workflow:", help_text)
        self.assertIn("Rect is X,Y,W,H", help_text)
        self.assertIn("exit codes:", help_text)

    def test_element_help_contains_a_constructible_layout_recipe(self):
        output = io.StringIO()
        with self.assertRaises(SystemExit), contextlib.redirect_stdout(output):
            cli.parser().parse_args(["element", "--help"])
        help_text = output.getvalue()
        self.assertIn("layout recipe:", help_text)
        self.assertIn("--line 30,75,690,75", help_text)

    def test_plugin_add_help_explains_idempotency_and_move_semantics(self):
        output = io.StringIO()
        with self.assertRaises(SystemExit), contextlib.redirect_stdout(output):
            cli.parser().parse_args(["plugin", "add", "--help"])
        help_text = output.getvalue()
        self.assertIn("idempotent ensure", help_text)
        self.assertIn("Use `place`", help_text)


if __name__ == "__main__":
    unittest.main()
