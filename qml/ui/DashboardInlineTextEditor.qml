pragma ComponentBehavior: Bound

import QtQuick
import qs.Commons
import "../state/DashboardModel.js" as DashboardModel

Item {
  id: root

  required property Item canvas
  property var element: null
  readonly property point canvasOrigin: {
    // Recalculate the mapped origin when the window or centered canvas moves.
    var geometry = [width, height, canvas.x, canvas.y, canvas.width, canvas.height]
    return canvas.mapToItem(root, 0, 0)
  }
  signal accepted(string value)
  signal rejected()

  function accept() {
    var value = input.text.trim()
    if (value) accepted(value)
  }

  onVisibleChanged: {
    if (visible && element) {
      input.text = String(element.text || "")
      focusTimer.restart()
    } else {
      focusTimer.stop()
      input.focus = false
    }
  }
  Timer {
    id: focusTimer
    interval: 0
    onTriggered: {
      input.forceActiveFocus()
      input.selectAll()
    }
  }

  MouseArea {
    anchors.fill: parent
    onClicked: input.text.trim() ? root.accept() : root.rejected()
  }

  Rectangle {
    objectName: "inlineTextFrame"
    x: root.canvasOrigin.x + (root.element ? root.element.x : 0)
    y: root.canvasOrigin.y + (root.element ? root.element.y : 0)
    width: root.element ? root.element.w : 0
    height: root.element ? root.element.h : 0
    color: Color.popups.background
    radius: Style.cornerRadius
    border.width: 1
    border.color: Color.accent
    clip: true

    TextInput {
      id: input
      objectName: "inlineTextInput"
      anchors.fill: parent
      color: Color.popups.text
      selectionColor: Color.accent
      selectedTextColor: Color.background
      font.family: Style.font.family
      font.bold: true
      font.pixelSize: Math.max(Style.font.title, Math.min(Style.space(180), height * 0.78))
      maximumLength: DashboardModel.MAX_TEXT_LENGTH
      selectByMouse: true
      horizontalAlignment: root.element && root.element.alignment === "right" ? TextInput.AlignRight
        : (root.element && root.element.alignment === "center" ? TextInput.AlignHCenter : TextInput.AlignLeft)
      verticalAlignment: TextInput.AlignVCenter
      onAccepted: root.accept()
      Keys.onEscapePressed: function(event) { root.rejected(); event.accepted = true }
    }
  }
}
