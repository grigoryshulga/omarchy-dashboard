#!/usr/bin/env bash
set -euo pipefail

project_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
cache_dir=$(mktemp -d)
trap 'rm -rf -- "$cache_dir"' EXIT

adapt() {
  local source_dir=$1
  local entry_point=$2
  local plugin_id=$3
  /usr/bin/python3 -I "$project_dir/lib/omarchy_dashboard_adapter.py" -- \
    "$source_dir" "$entry_point" "$cache_dir" "$plugin_id" "$project_dir"
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
  "$cache_dir" omarchy.bluetooth "$project_dir")
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
