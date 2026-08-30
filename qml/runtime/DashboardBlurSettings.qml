pragma ComponentBehavior: Bound

import QtQuick
import Quickshell.Io
import "../core/HyprlandBlur.js" as HyprlandBlur

Item {
  id: root

  visible: false
  property var options: HyprlandBlur.DEFAULTS
  readonly property var effect: HyprlandBlur.effect(options)

  function refresh() {
    if (readProc.running) return
    var keys = ["enabled", "size", "passes", "brightness", "contrast", "vibrancy"]
    var batch = []
    for (var index = 0; index < keys.length; index++)
      batch.push("getoption decoration:blur:" + keys[index])
    readProc.command = ["hyprctl", "-j", "--batch", batch.join(" ; ")]
    readProc.running = true
  }

  function scheduleRefresh() {
    refreshTimer.restart()
  }

  Process {
    id: readProc
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: root.options = HyprlandBlur.parse(text, root.options)
    }
  }

  Timer {
    id: refreshTimer
    interval: 200
    repeat: false
    onTriggered: root.refresh()
  }

  Component.onCompleted: refresh()
}
