#!/usr/bin/env bash
#
# Live-system check for the qml/system seam.
#
# Runs an isolated Quickshell against the *installed* Omarchy shell modules
# (qs.Commons / qs.Ui), not the test fixture, and asserts that:
#   - HostChrome resolves every palette and metric token to a valid value
#   - HostSession reaches the live environment, screens and focused monitor
#   - the migrated components load through their own `import "../system"`
#   - the shell emits no binding errors while doing so
#
# This is the gate that catches an Omarchy update retargeting or removing a
# token: the plugin must degrade to its fallbacks, never break a binding.
# It needs no compositor, writes nothing to the session and is not part of
# tests/all.sh.

set -euo pipefail

project_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
shell_root=${OMARCHY_PATH:-/usr/share/omarchy}/shell

if [[ ! -f "$shell_root/Commons/qmldir" || ! -f "$shell_root/Ui/qmldir" ]]; then
  printf 'Omarchy shell modules not found under %s; this is a live-system check.\n' \
    "$shell_root" >&2
  exit 1
fi

work=$(mktemp -d)
trap 'rm -rf -- "$work"' EXIT

# `qs.Commons` and `qs.Ui` resolve against the config root, so the isolated
# config folder gets the installed modules rather than the test fixture.
ln -s "$shell_root/Commons" "$work/Commons"
ln -s "$shell_root/Ui" "$work/Ui"

cat > "$work/shell.qml" <<QML
import QtQuick
import Quickshell
import "file://$project_dir/qml/system" as System
import "file://$project_dir/qml/layout" as Layout
import "file://$project_dir/qml/navigation" as Navigation

ShellRoot {
  System.HostChrome { id: chrome }
  System.HostSession { id: session }

  // Migrated components resolve the seam through their own relative import.
  Layout.TileSilhouette { title: "seam"; detail: "seam"; valid: true; width: 200; height: 120 }
  Layout.CanvasAlignmentGuides { width: 100; height: 100 }
  Navigation.ShortcutsOverlay { width: 400; height: 300 }

  Timer {
    interval: 1200
    running: true
    onTriggered: {
      console.log("SEAM_REPORT=" + JSON.stringify({
        background: chrome.background.toString(),
        foreground: chrome.foreground.toString(),
        accent: chrome.accent.toString(),
        urgent: chrome.urgent.toString(),
        popupBackground: chrome.popupBackground.toString(),
        popupText: chrome.popupText.toString(),
        popupBorder: chrome.popupBorder.toString(),
        menuScrim: chrome.menuScrim.toString(),
        hoverFill: chrome.hoverFill(chrome.popupText, chrome.accent).toString(),
        normalFill: chrome.normalFill(chrome.popupText, chrome.accent).toString(),
        cornerRadius: chrome.cornerRadius,
        gapsOut: chrome.gapsOut,
        borderWidth: chrome.borderWidth,
        fontTitle: chrome.fontTitle,
        fontCaption: chrome.fontCaption,
        panelGap: chrome.panelGap,
        controlPaddingY: chrome.controlPaddingY,
        space8: chrome.space(8),
        fontFamily: chrome.fontFamily,
        envHome: session.env("HOME"),
        screens: session.screens().length,
        focused: session.focusedScreenName(),
        commandReady: session.commandReady()
      }))
      Qt.quit()
    }
  }
}
QML

output=$(timeout 30 env QT_QPA_PLATFORM=offscreen QT_FORCE_STDERR_LOGGING=1 \
  quickshell --no-color --path "$work/shell.qml" 2>&1) || {
  printf '%s\n' "$output" >&2
  printf 'Quickshell failed to run the seam probe.\n' >&2
  exit 1
}

# A retargeted token shows up here before it shows up in the UI. Only our own
# files count: Quickshell shortens installed-shell paths to "@Commons/…", and a
# warning raised inside the shell's modules is the shell's business, not the
# seam's. This gate answers one question: does the plugin leak an error when the
# installed shell no longer offers a token it reads?
leaks=$(grep -E 'Unable to assign|TypeError|ReferenceError|is not a function|is not defined' <<<"$output" \
  | grep -F "$project_dir/qml" || true)
if [[ -n "$leaks" ]]; then
  printf '%s\n' "$leaks" >&2
  printf 'The seam leaked a binding error against the installed shell.\n' >&2
  exit 1
fi

report=$(grep -o 'SEAM_REPORT=.*' <<<"$output" | head -1 | cut -d= -f2-)
if [[ -z "$report" ]]; then
  printf '%s\n' "$output" >&2
  printf 'The seam probe produced no report.\n' >&2
  exit 1
fi

check() { jq -e "$1" <<<"$report" >/dev/null || {
  printf 'Seam assertion failed: %s\nreport: %s\n' "$2" "$report" >&2
  exit 1
}; }

check '[.background,.foreground,.accent,.urgent,.popupBackground,.popupText,.popupBorder,.menuScrim,.hoverFill,.normalFill] | all(test("^#[0-9a-fA-F]{6,8}$"))' \
  "every palette entry must be an assignable color"
check '[.cornerRadius,.gapsOut,.borderWidth,.fontTitle,.fontCaption,.panelGap,.controlPaddingY,.space8] | all(type == "number")' \
  "every metric must be a finite number"
check '.fontFamily | length > 0' "the font family must resolve"
check '.envHome | length > 0' "HostSession must read the environment"
check '.screens | type == "number" and . >= 1' "HostSession must list at least one screen"
check '.focused | type == "string"' "the focused monitor lookup must return a string"

printf 'System seam resolved against %s\n' "$shell_root"
jq -r '"  accent=\(.accent) text=\(.popupText) border=\(.borderWidth)px radius=\(.cornerRadius) gaps=\(.gapsOut) font=\(.fontFamily) \(.fontTitle)/\(.fontCaption)px\n  home=\(.envHome) screens=\(.screens) focused=\(.focused // "") commandReady=\(.commandReady)"' <<<"$report"
