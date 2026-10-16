#!/usr/bin/env bash
set -euo pipefail

project_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
cache_dir=$(mktemp -d)
probe_dir=$(mktemp -d)
trap 'rm -rf -- "$cache_dir" "$probe_dir"' EXIT

adapt() {
  local source_dir=$1
  local entry_point=$2
  local plugin_id=$3
  /usr/bin/python3 -I "$project_dir/lib/omarchy_dashboard_adapter.py" -- \
    "$source_dir" "$entry_point" "$cache_dir" "$plugin_id" "$project_dir/qml/plugins/adapters"
}

bluetooth_output=$(adapt /usr/share/omarchy/shell/plugins/panels/bluetooth Panel.qml omarchy.bluetooth)
bluetooth_panel=${bluetooth_output#file://}
test -f "$bluetooth_panel"
test -f "$(dirname "$bluetooth_panel")/DashboardHost.qml"
test -f "$(dirname "$bluetooth_panel")/DashboardDisabledIpc.qml"
test -f "$(dirname "$bluetooth_panel")/DashboardHiddenBarButton.qml"
grep -q 'property var dashboardHost: null' "$bluetooth_panel"
grep -q 'DashboardHost {' "$bluetooth_panel"
grep -q 'anchors.fill: parent' "$bluetooth_panel"
grep -q 'dashboardHost: root.dashboardHost' "$bluetooth_panel"
grep -q 'DashboardDisabledIpc {' "$bluetooth_panel"
grep -q 'DashboardHiddenBarButton {' "$bluetooth_panel"
! grep -q 'KeyboardPanel {' "$bluetooth_panel"

bluetooth_json=$(/usr/bin/python3 -I "$project_dir/lib/omarchy_dashboard_adapter.py" \
  --json-output -- /usr/share/omarchy/shell/plugins/panels/bluetooth Panel.qml \
  "$cache_dir" omarchy.bluetooth "$project_dir/qml/plugins/adapters")
/usr/bin/python3 -c 'import json, sys; result=json.loads(sys.argv[1]); assert result["layout"] == "padded"; assert result["url"].startswith("file://")' \
  "$bluetooth_json"

weather_output=$(adapt /usr/share/omarchy/shell/plugins/panels/weather BarWidget.qml omarchy.weather)
weather_panel=${weather_output#file://}
test -f "$weather_panel"
grep -q 'DashboardHost {' "$weather_panel"
! grep -q 'KeyboardPanel {' "$weather_panel"

mkdir "$cache_dir/unsafe-source"
touch "$cache_dir/outside.qml"
if adapt "$cache_dir/unsafe-source" ../outside.qml unsafe.plugin; then
  exit 1
fi

mkdir "$cache_dir/symlink-source"
ln -s /usr/share/omarchy/shell/plugins/panels/bluetooth/Panel.qml "$cache_dir/symlink-source/Panel.qml"
if adapt "$cache_dir/symlink-source" Panel.qml symlink.plugin; then
  exit 1
fi

# Every installed standard panel must not only adapt but instantiate. A
# compatibility shim that lags behind Omarchy's UI kit produces an artifact that
# cannot load, which the user sees as an empty tile: KeyboardPanel.content and
# BarIconButton.labelText both arrived in one shell update and did exactly that.
shell_root=${OMARCHY_PATH:-/usr/share/omarchy}/shell
if [[ ! -d "$shell_root/Commons" || ! -d "$shell_root/Ui" ]]; then
  printf 'skipping the panel load pass: no shell modules under %s\n' "$shell_root"
  exit 0
fi

ln -s "$shell_root/Commons" "$probe_dir/Commons"
ln -s "$shell_root/Ui" "$probe_dir/Ui"

panel_urls=()
panel_ids=()
for panel in "$shell_root"/plugins/panels/*/ "$shell_root"/plugins/agents/; do
  [[ -f "$panel/Panel.qml" ]] || continue
  # Panels without a standard Panel root are presented as launchers, not
  # adapted; every other installed panel has to adapt and load here.
  grep -qE '^Panel \{' "$panel/Panel.qml" || continue
  panel_id="omarchy.$(basename "$panel")"
  if ! json=$(/usr/bin/python3 -I "$project_dir/lib/omarchy_dashboard_adapter.py" --json-output \
      "$panel" Panel.qml "$cache_dir" "$panel_id" "$project_dir/qml/plugins/adapters" 2>&1); then
    printf 'adapted panel %s failed: %s\n' "$panel_id" "$(tail -1 <<<"$json")" >&2
    printf 'a standard panel no longer adapts; the compatibility shim lags behind the shell\n' >&2
    exit 1
  fi
  panel_urls+=("$(/usr/bin/python3 -c 'import json, sys; print(json.loads(sys.argv[1])["url"])' "$json")")
  panel_ids+=("$panel_id")
done

if (( ${#panel_urls[@]} < 8 )); then
  printf 'expected the installed shell to provide standard panels, adapted only %s\n' "${#panel_urls[@]}" >&2
  exit 1
fi

{
  printf 'import QtQuick\nimport Quickshell\n\nShellRoot {\n  id: root\n'
  for index in "${!panel_urls[@]}"; do
    printf '  Loader { id: panel%s; source: "%s" }\n' "$index" "${panel_urls[$index]}"
  done
  printf '  Timer { interval: 3000; running: true; onTriggered: {\n'
  for index in "${!panel_urls[@]}"; do
    printf '    console.log("PANEL_LOAD=%s " + panel%s.status)\n' "${panel_ids[$index]}" "$index"
  done
  printf '    Qt.quit() } }\n}\n'
} > "$probe_dir/shell.qml"

load_output=$(timeout 60 env QT_QPA_PLATFORM=offscreen QT_FORCE_STDERR_LOGGING=1 \
  quickshell --no-color --path "$probe_dir/shell.qml" 2>&1) || {
  printf '%s\n' "$load_output" >&2
  printf 'the panel load pass could not run\n' >&2
  exit 1
}

if grep -qE 'non-existent property|Unable to assign' <<<"$load_output"; then
  grep -E 'non-existent property|Unable to assign' <<<"$load_output" >&2
  printf 'an adapted panel cannot instantiate; extend the compatibility shim\n' >&2
  exit 1
fi

failed=0
while read -r line; do
  [[ -n "$line" ]] || continue
  name=${line#PANEL_LOAD=}
  status=${name##* }
  name=${name%% *}
  if [[ "$status" != "1" ]]; then
    printf 'adapted panel %s did not load (status %s)\n' "$name" "$status" >&2
    failed=1
  fi
done < <(grep -o 'PANEL_LOAD=[^ ]* [0-9]' <<<"$load_output")

(( failed == 0 )) || exit 1
printf 'Adapted panels load: %s checked\n' "${#panel_urls[@]}"

