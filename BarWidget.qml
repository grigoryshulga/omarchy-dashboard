pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import qs.Commons
import qs.Ui

BarWidget {
  id: root

  moduleName: "gshulga.dashboard"

  readonly property bool opened: bar && bar.shell && typeof bar.shell.isPluginOpen === "function"
    ? bar.shell.isPluginOpen(moduleName) : false
  readonly property string label: setting("showLabel", false) === true ? "  Dashboard" : ""

  function screenName() {
    var window = root.QsWindow ? root.QsWindow.window : null
    return window && window.screen ? String(window.screen.name || "") : ""
  }

  function open() {
    if (!bar || !bar.shell || typeof bar.shell.summon !== "function") return
    bar.shell.summon(moduleName, JSON.stringify({ screenName: screenName() }))
  }

  function close() {
    if (bar && bar.shell && typeof bar.shell.hide === "function") bar.shell.hide(moduleName)
  }

  function togglePanel() {
    if (opened) close()
    else open()
  }

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  WidgetButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: "󰕮" + root.label
    tooltipText: root.opened ? "Close Dashboard" : "Open Dashboard"
    active: root.opened
    onPressed: root.togglePanel()
  }
}
