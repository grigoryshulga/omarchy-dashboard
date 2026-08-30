"""Deep CLI module for Dashboard Plugin Installation and Host Placement."""

from __future__ import annotations

import argparse
import json
import subprocess
import sys
import time
from dataclasses import dataclass
from typing import Any, Sequence, TextIO


TARGET = "gshulga.dashboard"
SCHEMA_VERSION = 1
CLI_VERSION = "1.7.0"

ROOT_EPILOG = """agent workflow:
  1. Inspect:  space list --json; grid show --json; plugin list --json; element list --json
  2. Create named Spaces with stable ids:  space create NAME --id SPACE_ID
  3. Add installed plugins as pending, or place them with --space and --rect/--auto.
  4. Add Dashboard-owned headings and axis-aligned dividers with stable element ids.
  5. Re-run the four inspect commands and verify after a shell restart.

coordinate model:
  Rect is X,Y,W,H in logical Dashboard canvas pixels; origin is top-left.
  Line is X1,Y1,X2,Y2 and must be non-zero, horizontal or vertical.
  Exact geometry is atomic: out-of-bounds or colliding plugin Rects are rejected.
  Read current canvas width, height and spacing with `omarchy-dashboard grid show`.

automation contract:
  --json prints exactly one JSON document to stdout. Errors also use stdout in JSON mode.
  `plugin install --json` requires --yes because interactive prompts would corrupt stdout.
  Space selectors accept a stable id or a unique case-insensitive name; prefer ids in scripts.
  Run `<group> --help` and `<group> <command> --help` for examples and command semantics.

exit codes: 0 success, 2 invalid CLI/confirmation, 3 Dashboard unavailable,
            4 Dashboard rejected the operation, 5 plugin installation/catalog failure.
"""


class DashboardArgumentParser(argparse.ArgumentParser):
    def __init__(self, *args: Any, **kwargs: Any) -> None:
        kwargs.setdefault("formatter_class", argparse.RawDescriptionHelpFormatter)
        super().__init__(*args, **kwargs)


@dataclass
class CliFailure(Exception):
    code: str
    message: str
    exit_code: int = 4
    details: dict[str, Any] | None = None


class DashboardIpcAdapter:
    """Production adapter for the Dashboard command seam."""

    def execute(self, request: dict[str, Any]) -> dict[str, Any]:
        envelope = json.dumps({"type": "managePlugins", "request": request}, separators=(",", ":"))
        try:
            result = subprocess.run(
                ["omarchy-shell", "shell", "call", TARGET, "execute", envelope],
                check=False,
                capture_output=True,
                text=True,
                timeout=8,
            )
        except (OSError, subprocess.TimeoutExpired) as error:
            raise CliFailure("dashboard-unavailable", str(error), 3) from error
        if result.returncode != 0:
            message = result.stderr.strip() or result.stdout.strip() or "Dashboard IPC failed"
            raise CliFailure("dashboard-unavailable", message, 3)
        try:
            response = json.loads(result.stdout)
        except json.JSONDecodeError as error:
            raise CliFailure("invalid-dashboard-response", result.stdout.strip(), 3) from error
        if not isinstance(response, dict):
            raise CliFailure("invalid-dashboard-response", "Dashboard returned a non-object", 3)
        return response

    def open(self) -> None:
        result = subprocess.run(
            ["omarchy-shell", "shell", "summon", TARGET], check=False, capture_output=True, text=True
        )
        if result.returncode != 0:
            raise CliFailure("dashboard-unavailable", result.stderr.strip() or "Could not open Dashboard", 3)


class OmarchyPluginAdapter:
    """Production adapter for Plugin Installation operations."""

    def _installed_ids(self) -> set[str]:
        result = subprocess.run(
            ["omarchy", "plugin", "list", "--json"], check=False, capture_output=True, text=True
        )
        if result.returncode != 0:
            raise CliFailure("plugin-catalog-unavailable", result.stderr.strip(), 5)
        try:
            entries = json.loads(result.stdout)
        except json.JSONDecodeError as error:
            raise CliFailure("plugin-catalog-unavailable", "Plugin list returned invalid JSON", 5) from error
        return {str(entry.get("id", "")) for entry in entries if isinstance(entry, dict) and entry.get("id")}

    def install(self, source: str, assume_yes: bool = False) -> str:
        before = self._installed_ids()
        command = ["omarchy", "plugin", "add", source]
        if assume_yes:
            command.append("--yes")
        result = subprocess.run(
            command,
            check=False,
            text=True,
            capture_output=assume_yes,
        )
        if assume_yes and result.stdout:
            print(result.stdout, end="", file=sys.stderr)
        if assume_yes and result.stderr:
            print(result.stderr, end="", file=sys.stderr)
        if result.returncode != 0:
            raise CliFailure("installation-failed", "omarchy plugin add failed", 5)
        for _ in range(40):
            after = self._installed_ids()
            added = sorted(after - before)
            if len(added) == 1:
                return added[0]
            if len(added) > 1:
                raise CliFailure("installation-id-ambiguous", ", ".join(added), 5)
            time.sleep(0.05)
        raise CliFailure("installation-id-unresolved", "Installed plugin was not discovered", 5)

    def uninstall(self, plugin_id: str, assume_yes: bool = False) -> None:
        command = ["omarchy", "plugin", "remove", plugin_id]
        if assume_yes:
            command.append("--yes")
        result = subprocess.run(command, check=False)
        if result.returncode != 0:
            raise CliFailure("uninstall-failed", f"Could not uninstall {plugin_id}", 5)


def parse_rect(value: str) -> dict[str, int]:
    try:
        parts = [int(part.strip()) for part in value.split(",")]
    except ValueError as error:
        raise argparse.ArgumentTypeError("Rect must be X,Y,W,H integers") from error
    if len(parts) != 4 or parts[0] < 0 or parts[1] < 0 or parts[2] <= 0 or parts[3] <= 0:
        raise argparse.ArgumentTypeError("Rect must be X,Y,W,H with non-negative X/Y and positive W/H")
    return dict(zip(("x", "y", "w", "h"), parts, strict=True))


def parse_line(value: str) -> dict[str, int]:
    try:
        parts = [int(part.strip()) for part in value.split(",")]
    except ValueError as error:
        raise argparse.ArgumentTypeError("Line must be X1,Y1,X2,Y2 integers") from error
    if len(parts) != 4 or any(part < 0 for part in parts):
        raise argparse.ArgumentTypeError("Line must be X1,Y1,X2,Y2 with non-negative coordinates")
    x1, y1, x2, y2 = parts
    if (x1 == x2) == (y1 == y2):
        raise argparse.ArgumentTypeError("Line must be a non-zero horizontal or vertical divider")
    return dict(zip(("x1", "y1", "x2", "y2"), parts, strict=True))


def add_output_flags(parser: argparse.ArgumentParser) -> None:
    parser.add_argument(
        "--json", action="store_true",
        help="print exactly one machine-readable JSON document to stdout",
    )


def add_target_flags(
    parser: argparse.ArgumentParser, *, required: bool = False, include_pending: bool = True
) -> None:
    parser.add_argument("--space", help="stable Space id (preferred) or a unique Space name")
    target = parser.add_mutually_exclusive_group(required=required)
    if include_pending:
        target.add_argument("--pending", action="store_true", help="create a Pending Placement")
    target.add_argument("--auto", action="store_true", help="let Dashboard choose a free Rect")
    target.add_argument(
        "--rect", type=parse_rect, metavar="X,Y,W,H",
        help="use this exact logical-pixel Rect; reject collision or out-of-bounds geometry",
    )
    parser.add_argument(
        "--embedding", choices=("auto", "embedded", "widget", "launcher", "control"), default="auto",
        help="presentation mode requested for a newly created placement (default: auto)",
    )


def parser() -> argparse.ArgumentParser:
    root = DashboardArgumentParser(
        prog="omarchy-dashboard",
        description="Provision Dashboard Spaces, plugin placements, grid settings and graphic elements.",
        epilog=ROOT_EPILOG,
    )
    root.add_argument("--version", action="version", version=f"%(prog)s {CLI_VERSION}")
    groups = root.add_subparsers(dest="group", required=True)

    plugin = groups.add_parser(
        "plugin",
        help="manage Plugin Installations and Host Placements",
        description="Manage plugin code separately from its single Dashboard Host Placement.",
        epilog="""placement lifecycle:
  install SOURCE   install code, then create pending placement by default
  add ID           ensure an installed plugin is hosted; does not move an existing placement
  place ID         turn a pending placement into a tile
  move ID          move an already placed tile, atomically
  pending ID       keep hosting/settings but remove Space and Rect
  remove ID        remove only the Host Placement; keep installed code
  uninstall ID     remove code; refuses while hosted unless --remove-placement

examples:
  omarchy-dashboard plugin add omarchy.weather
  omarchy-dashboard plugin add omarchy.weather --space space-home --rect 750,330,480,180
  omarchy-dashboard plugin move omarchy.weather --space space-home --auto
  omarchy-dashboard plugin list --json
""",
    )
    commands = plugin.add_subparsers(dest="command", required=True)

    install = commands.add_parser(
        "install", help="install from git and create a Host Placement",
        epilog="""examples:
  omarchy-dashboard plugin install https://example/plugin.git
  omarchy-dashboard plugin install URL --space space-home --auto --yes
  omarchy-dashboard plugin install URL --space space-home --rect 0,0,420,300 --yes --json

Default target is pending. --json requires --yes.
""",
    )
    install.add_argument("source")
    install.add_argument("--yes", "-y", action="store_true")
    add_target_flags(install)
    add_output_flags(install)

    add = commands.add_parser(
        "add", help="create a Host Placement for an installed plugin",
        epilog="""examples:
  omarchy-dashboard plugin add omarchy.weather                 # pending
  omarchy-dashboard plugin add omarchy.weather --space space-home --auto
  omarchy-dashboard plugin add omarchy.weather --space space-home --rect 750,330,480,180

This is an idempotent ensure operation: an existing placement is left unchanged.
Use `place` for pending placement or `move` for an existing tile.
""",
    )
    add.add_argument("plugin_id")
    add_target_flags(add)
    add_output_flags(add)

    listing = commands.add_parser(
        "list", help="list Dashboard Host Placements",
        epilog="""examples:
  omarchy-dashboard plugin list
  omarchy-dashboard plugin list --state pending --json
  omarchy-dashboard plugin list --space space-home --json
""",
    )
    listing.add_argument("--state", choices=("pending", "placed"))
    listing.add_argument("--space")
    add_output_flags(listing)

    for name in ("place", "move"):
        mutation = commands.add_parser(
            name, help=f"{name} a Dashboard Host Placement",
            epilog=f"""examples:
  omarchy-dashboard plugin {name} PLUGIN_ID --space SPACE_ID --auto
  omarchy-dashboard plugin {name} PLUGIN_ID --space SPACE_ID --rect X,Y,W,H

`place` requires a pending placement; `move` requires an existing placed tile.
Both operations reject invalid geometry without changing the previous state.
""",
        )
        mutation.add_argument("plugin_id")
        add_target_flags(mutation, required=True, include_pending=False)
        add_output_flags(mutation)

    pending = commands.add_parser(
        "pending", help="create or return to a Pending Placement",
        epilog="""example:
  omarchy-dashboard plugin pending omarchy.weather

The plugin remains hosted and keeps its placement id, settings and embedding,
but has no Space or Rect until `plugin place` is called.
""",
    )
    pending.add_argument("plugin_id")
    add_output_flags(pending)

    remove = commands.add_parser(
        "remove", help="remove the Host Placement but keep plugin code",
        epilog="""example:
  omarchy-dashboard plugin remove omarchy.weather

This does not uninstall plugin code. The operation is idempotent.
""",
    )
    remove.add_argument("plugin_id")
    add_output_flags(remove)

    uninstall = commands.add_parser(
        "uninstall", help="remove plugin code after checking Host Placement",
        epilog="""examples:
  omarchy-dashboard plugin uninstall omarchy.weather
  omarchy-dashboard plugin uninstall omarchy.weather --remove-placement --yes

Without --remove-placement this refuses to uninstall a hosted plugin.
""",
    )
    uninstall.add_argument("plugin_id")
    uninstall.add_argument("--remove-placement", action="store_true")
    uninstall.add_argument("--yes", "-y", action="store_true")
    add_output_flags(uninstall)

    space = groups.add_parser(
        "space", help="inspect and provision Dashboard Spaces",
        description="Create, name, select and remove Dashboard pages (Spaces).",
        epilog="""selectors and stable ids:
  Commands accept a stable Space id or a unique case-insensitive name.
  Agents should create explicit ids and use those ids in subsequent commands.

examples:
  omarchy-dashboard space list --json
  omarchy-dashboard space create Home --id space-home
  omarchy-dashboard space rename space-home Personal
  omarchy-dashboard space select space-home
  omarchy-dashboard space remove space-home --yes
""",
    )
    space_commands = space.add_subparsers(dest="command", required=True)
    space_list = space_commands.add_parser(
        "list", help="list stable Space ids",
        epilog="""example:
  omarchy-dashboard space list --json

Use the returned ids as --space selectors in automation.
""",
    )
    add_output_flags(space_list)
    space_create = space_commands.add_parser(
        "create", help="create a Dashboard Space",
        epilog="""examples:
  omarchy-dashboard space create Home
  omarchy-dashboard space create Home --id space-home --json

Use --id for deterministic agent provisioning. Names and ids must be unique.
""",
    )
    space_create.add_argument("name")
    space_create.add_argument("--id", help="use a stable id for declarative provisioning")
    add_output_flags(space_create)
    space_rename = space_commands.add_parser(
        "rename", help="rename a Dashboard Space",
        epilog="""example:
  omarchy-dashboard space rename space-home Personal

Renaming does not change the stable Space id or its contents.
""",
    )
    space_rename.add_argument("space")
    space_rename.add_argument("name")
    add_output_flags(space_rename)
    space_remove = space_commands.add_parser(
        "remove", help="remove a Dashboard Space and its placements",
        epilog="""example:
  omarchy-dashboard space remove space-old --yes

This deletes every placed tile and graphic element in the Space. Plugin code is kept.
The last Space cannot be removed.
""",
    )
    space_remove.add_argument("space")
    space_remove.add_argument("--yes", "-y", action="store_true", help="confirm destructive removal")
    add_output_flags(space_remove)
    space_select = space_commands.add_parser(
        "select", help="make a Dashboard Space active",
        epilog="""example:
  omarchy-dashboard space select space-home

The selected Space is persisted and becomes visible when Dashboard opens.
""",
    )
    space_select.add_argument("space")
    add_output_flags(space_select)

    grid = groups.add_parser(
        "grid", help="inspect or configure the Dashboard grid",
        description="Inspect canvas bounds and configure its placement spacing.",
        epilog="""examples:
  omarchy-dashboard grid show --json
  omarchy-dashboard grid set 30

Rect and Line coordinates are logical canvas pixels, independent of monitor scale.
Always inspect bounds before constructing exact layouts.
""",
    )
    grid_commands = grid.add_subparsers(dest="command", required=True)
    grid_show = grid_commands.add_parser(
        "show", help="show persisted grid geometry",
        epilog="""example:
  omarchy-dashboard grid show --json

Read width and height before generating Rect or Line coordinates.
""",
    )
    add_output_flags(grid_show)
    grid_set = grid_commands.add_parser(
        "set", help="set the grid spacing",
        epilog="""example:
  omarchy-dashboard grid set 30

Spacing controls UI snap and automatic placement; existing exact geometry is preserved.
""",
    )
    grid_set.add_argument("spacing", type=int)
    add_output_flags(grid_set)

    element = groups.add_parser(
        "element", help="manage Dashboard text and divider elements",
        description="Manage Dashboard-owned headings and axis-aligned visual dividers.",
        epilog="""layout recipe:
  1. Reserve a header band above plugin Rects.
  2. Add heading text with --rect and a stable --id.
  3. Add a horizontal rule below each heading.
  4. Add vertical rules only inside free gaps between plugin columns.
  5. Verify with `element list --json` and `plugin list --json`.

example:
  omarchy-dashboard element add-text Life --space space-home \\
    --rect 30,15,660,45 --id home-title-life
  omarchy-dashboard element add-divider --space space-home \\
    --line 30,75,690,75 --id home-rule-life
""",
    )
    element_commands = element.add_subparsers(dest="command", required=True)
    element_list = element_commands.add_parser(
        "list", help="list Dashboard graphic elements",
        epilog="""examples:
  omarchy-dashboard element list --json
  omarchy-dashboard element list --space space-home --json
""",
    )
    element_list.add_argument("--space")
    add_output_flags(element_list)
    element_text = element_commands.add_parser(
        "add-text", help="add a text heading",
        epilog="""example:
  omarchy-dashboard element add-text 'System Controls' --space space-system \\
    --rect 1290,15,690,45 --id system-title-controls

Rect is X,Y,W,H. Text is clipped to the Rect and scales to fit.
""",
    )
    element_text.add_argument("text")
    element_text.add_argument("--space", required=True)
    element_text.add_argument("--rect", type=parse_rect, required=True, metavar="X,Y,W,H")
    element_text.add_argument("--id", help="use a stable element id")
    add_output_flags(element_text)
    element_divider = element_commands.add_parser(
        "add-divider", help="add an axis-aligned divider",
        epilog="""examples:
  omarchy-dashboard element add-divider --space space-home \\
    --line 720,0,720,1050 --id home-column-rule
  omarchy-dashboard element add-divider --space space-home \\
    --line 30,75,690,75 --id home-heading-rule

Line is X1,Y1,X2,Y2 and must be horizontal or vertical with non-zero length.
""",
    )
    element_divider.add_argument("--space", required=True)
    element_divider.add_argument("--line", type=parse_line, required=True, metavar="X1,Y1,X2,Y2")
    element_divider.add_argument("--id", help="use a stable element id")
    add_output_flags(element_divider)
    element_remove = element_commands.add_parser(
        "remove", help="remove a graphic element",
        epilog="""example:
  omarchy-dashboard element remove home-title-life

This removes only Dashboard-owned text/divider geometry, never a plugin placement.
""",
    )
    element_remove.add_argument("element_id")
    add_output_flags(element_remove)

    groups.add_parser("open", help="open Dashboard on the focused monitor")
    return root


def target_request(args: argparse.Namespace, operation: str, plugin_id: str) -> dict[str, Any]:
    request: dict[str, Any] = {
        "schemaVersion": SCHEMA_VERSION,
        "operation": operation,
        "pluginId": plugin_id,
        "selector": plugin_id,
        "embedding": getattr(args, "embedding", "auto"),
    }
    if getattr(args, "pending", False) or (
        operation == "ensure" and not getattr(args, "auto", False) and not getattr(args, "rect", None)
    ):
        request["target"] = "pending"
        return request
    if not getattr(args, "space", None):
        raise CliFailure("invalid-target", "--space is required with --auto or --rect", 2)
    request.update(
        {
            "target": "placed",
            "space": args.space,
            "strategy": "auto" if getattr(args, "auto", False) else "exact",
        }
    )
    if getattr(args, "rect", None):
        request["rect"] = args.rect
    return request


def response_or_failure(response: dict[str, Any]) -> dict[str, Any]:
    if response.get("ok") is True:
        return response
    code = str(response.get("code") or "dashboard-rejected")
    message = str(response.get("message") or code.replace("-", " "))
    raise CliFailure(code, message, 4, response)


def placement_line(placement: dict[str, Any]) -> str:
    rect = placement.get("rect")
    rect_text = "-" if not rect else f'{rect["x"]},{rect["y"]},{rect["w"]},{rect["h"]}'
    return "\t".join(
        (
            str(placement.get("pluginId", "")),
            str(placement.get("state", "")),
            str(placement.get("spaceId") or "-"),
            rect_text,
            str(placement.get("embedding", "auto")),
        )
    )


def element_line(element: dict[str, Any]) -> str:
    geometry = element.get("rect") or element.get("line") or {}
    if element.get("kind") == "text":
        geometry_text = ",".join(str(geometry.get(key, "")) for key in ("x", "y", "w", "h"))
    else:
        geometry_text = ",".join(str(geometry.get(key, "")) for key in ("x1", "y1", "x2", "y2"))
    return "\t".join(
        (
            str(element.get("id", "")),
            str(element.get("kind", "")),
            str(element.get("spaceId", "")),
            geometry_text,
            str(element.get("text", "")),
        )
    )


def emit(response: dict[str, Any], json_mode: bool, output: TextIO) -> None:
    if json_mode:
        print(json.dumps(response, ensure_ascii=False, sort_keys=True), file=output)
        return
    if "placements" in response:
        print("PLUGIN\tSTATE\tSPACE\tRECT\tEMBEDDING", file=output)
        for placement in response["placements"]:
            print(placement_line(placement), file=output)
    elif "elements" in response:
        print("ELEMENT\tKIND\tSPACE\tGEOMETRY\tTEXT", file=output)
        for element in response["elements"]:
            print(element_line(element), file=output)
    elif "spaces" in response:
        print("SPACE\tNAME\tACTIVE", file=output)
        for space in response["spaces"]:
            print(
                f'{space.get("id", "")}\t{space.get("name", "")}\t'
                f'{"yes" if space.get("active") else "no"}',
                file=output,
            )
    elif response.get("uninstalled"):
        print(f'Uninstalled {response["uninstalled"]}', file=output)
    elif response.get("space"):
        change = "Updated" if response.get("changed") else "Unchanged"
        print(f'{change} Space: {response["space"]["id"]}\t{response["space"]["name"]}', file=output)
    elif response.get("removedSpace"):
        print(f'Removed Space: {response["removedSpace"]["id"]}\t{response["removedSpace"]["name"]}', file=output)
    elif response.get("grid"):
        grid = response["grid"]
        print(f'Grid: spacing={grid["spacing"]} size={grid["width"]}x{grid["height"]}', file=output)
    elif response.get("element"):
        print(f'Updated Element: {element_line(response["element"])}', file=output)
    elif "removedElement" in response:
        removed = response.get("removedElement")
        print(f'Removed Element: {removed["id"]}' if removed else "No Graphic Element", file=output)
    elif response.get("opened"):
        print("Dashboard opened", file=output)
    else:
        placement = response.get("placement")
        if placement:
            change = "Updated" if response.get("changed") else "Unchanged"
            print(f"{change}: {placement_line(placement)}", file=output)
        else:
            print("Removed Host Placement" if response.get("changed") else "No Host Placement", file=output)


def run(
    args: argparse.Namespace,
    dashboard: DashboardIpcAdapter,
    installer: OmarchyPluginAdapter,
) -> dict[str, Any]:
    if args.group == "open":
        dashboard.open()
        return {"ok": True, "opened": True}
    if args.group == "space":
        if args.command == "list":
            request = {"schemaVersion": 1, "operation": "spaces"}
        elif args.command == "create":
            request = {"schemaVersion": 1, "operation": "space-create", "name": args.name}
            if args.id:
                request["id"] = args.id
        elif args.command == "rename":
            request = {
                "schemaVersion": 1,
                "operation": "space-rename",
                "space": args.space,
                "name": args.name,
            }
        elif args.command == "remove":
            if not args.yes:
                raise CliFailure(
                    "confirmation-required",
                    "space remove deletes every placement in that Space; pass --yes",
                    2,
                )
            request = {"schemaVersion": 1, "operation": "space-remove", "space": args.space}
        else:
            request = {"schemaVersion": 1, "operation": "space-select", "space": args.space}
        return response_or_failure(dashboard.execute(request))
    if args.group == "grid":
        request = {"schemaVersion": 1, "operation": "grid"}
        if args.command == "set":
            request = {"schemaVersion": 1, "operation": "grid-set", "spacing": args.spacing}
        return response_or_failure(dashboard.execute(request))
    if args.group == "element":
        if args.command == "list":
            response = response_or_failure(
                dashboard.execute({"schemaVersion": 1, "operation": "elements"})
            )
            if args.space:
                wanted = args.space.casefold()
                response["elements"] = [
                    entry
                    for entry in response.get("elements", [])
                    if str(entry.get("spaceId", "")).casefold() == wanted
                    or str(entry.get("spaceName", "")).casefold() == wanted
                ]
            return response
        if args.command == "add-text":
            request = {
                "schemaVersion": 1,
                "operation": "element-add-text",
                "space": args.space,
                "text": args.text,
                "rect": args.rect,
            }
            if args.id:
                request["id"] = args.id
        elif args.command == "add-divider":
            request = {
                "schemaVersion": 1,
                "operation": "element-add-divider",
                "space": args.space,
                "line": args.line,
            }
            if args.id:
                request["id"] = args.id
        else:
            request = {
                "schemaVersion": 1,
                "operation": "element-remove",
                "elementId": args.element_id,
            }
        return response_or_failure(dashboard.execute(request))

    command = args.command
    if command == "install":
        if args.json and not args.yes:
            raise CliFailure(
                "interactive-json",
                "plugin install --json requires --yes so stdout remains machine-readable",
                2,
            )
        plugin_id = installer.install(args.source, args.yes)
        try:
            response = response_or_failure(dashboard.execute(target_request(args, "ensure", plugin_id)))
        except CliFailure as error:
            error.code = "partial-install"
            error.message = f"Installed {plugin_id}, but placement failed: {error.message}"
            error.details = {"pluginId": plugin_id, "placementError": error.details}
            raise
        response["installation"] = {"pluginId": plugin_id, "created": True}
        return response
    if command == "add":
        return response_or_failure(dashboard.execute(target_request(args, "ensure", args.plugin_id)))
    if command in ("place", "move"):
        return response_or_failure(dashboard.execute(target_request(args, command, args.plugin_id)))
    if command == "pending":
        return response_or_failure(
            dashboard.execute(
                {"schemaVersion": 1, "operation": "pending", "pluginId": args.plugin_id, "selector": args.plugin_id}
            )
        )
    if command == "remove":
        return response_or_failure(
            dashboard.execute(
                {"schemaVersion": 1, "operation": "remove", "pluginId": args.plugin_id, "selector": args.plugin_id}
            )
        )
    if command == "list":
        response = response_or_failure(dashboard.execute({"schemaVersion": 1, "operation": "list"}))
        placements = response.get("placements", [])
        if args.state:
            placements = [placement for placement in placements if placement.get("state") == args.state]
        if args.space:
            wanted = args.space.casefold()
            placements = [
                placement
                for placement in placements
                if str(placement.get("spaceId", "")).casefold() == wanted
                or str(placement.get("spaceName", "")).casefold() == wanted
            ]
        response["placements"] = placements
        return response
    if command == "uninstall":
        response = response_or_failure(dashboard.execute({"schemaVersion": 1, "operation": "list"}))
        hosted = [entry for entry in response.get("placements", []) if entry.get("pluginId") == args.plugin_id]
        if hosted and not args.remove_placement:
            raise CliFailure("plugin-hosted", "Remove the Host Placement first or pass --remove-placement", 4)
        if hosted:
            response_or_failure(
                dashboard.execute(
                    {"schemaVersion": 1, "operation": "remove", "pluginId": args.plugin_id, "selector": args.plugin_id}
                )
            )
        installer.uninstall(args.plugin_id, args.yes)
        return {"ok": True, "uninstalled": args.plugin_id}
    raise CliFailure("unknown-command", command, 2)


def main(
    argv: Sequence[str] | None = None,
    *,
    dashboard: DashboardIpcAdapter | None = None,
    installer: OmarchyPluginAdapter | None = None,
    output: TextIO = sys.stdout,
    error: TextIO = sys.stderr,
) -> int:
    arguments = parser().parse_args(argv)
    try:
        response = run(arguments, dashboard or DashboardIpcAdapter(), installer or OmarchyPluginAdapter())
        emit(response, bool(getattr(arguments, "json", False)), output)
        return 0
    except CliFailure as failure:
        payload = {
            "ok": False,
            "code": failure.code,
            "message": failure.message,
            "details": failure.details or {},
        }
        if bool(getattr(arguments, "json", False)):
            print(json.dumps(payload, ensure_ascii=False, sort_keys=True), file=output)
        else:
            print(f"omarchy-dashboard: {failure.code}: {failure.message}", file=error)
        return failure.exit_code
