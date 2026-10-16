pragma ComponentBehavior: Bound

import QtQuick
import "HyprlandBlur.js" as HyprlandBlur

Item {
  id: root

  visible: false
  property bool active: false
  property bool pending: false
  property var hostSession: null

  function applyRule() {
    if (!root.hostSession) return
    if (!root.hostSession.commandReady()) {
      root.pending = true
      return
    }
    if (!root.hostSession.startCommand(["hyprctl", "eval", HyprlandBlur.ruleExpression(root.active)]))
      root.pending = true
  }

  function scheduleApply() {
    if (!root.hostSession) return
    applyTimer.restart()
  }

  Connections {
    target: root.hostSession
    function onCommandExited() {
      if (!root.pending) return
      root.pending = false
      Qt.callLater(root.applyRule)
    }
  }

  Timer {
    id: applyTimer
    interval: 200
    repeat: false
    onTriggered: root.applyRule()
  }

  onActiveChanged: scheduleApply()
  Component.onCompleted: scheduleApply()
}
