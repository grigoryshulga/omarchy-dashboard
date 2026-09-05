pragma ComponentBehavior: Bound

import QtQuick
import qs.Commons
import "GridEngine.js" as GridEngine
import "../state/DashboardModel.js" as DashboardModel

Item {
  id: root

  required property var dashboard
  required property var element
  required property Item canvas
  property real gridWidth: 0
  property real gridHeight: 0
  property var previewGeometry: null
  property var startGeometry: null
  property point pointerStart: Qt.point(0, 0)
  property string pointerMode: ""
  property bool verticalGuideVisible: false
  property bool horizontalGuideVisible: false
  property real verticalGuidePosition: 0
  property real horizontalGuidePosition: 0

  readonly property bool editing: dashboard.mode === "edit"
  readonly property bool selected: dashboard.selectedElementId === element.id
  readonly property var shown: previewGeometry || element
  readonly property real dividerThickness: Style.space(DashboardModel.normalizeDividerThickness(element.thickness))
  readonly property bool horizontalDivider: element.kind === "divider"
    && shown.y1 === shown.y2

  signal editTextRequested(string elementId, string text)

  anchors.fill: parent
  z: selected ? 40 : (editing ? 3 : 0)

  function canvasPoint(mouseArea, mouse) {
    return mouseArea.mapToItem(canvas, mouse.x, mouse.y)
  }

  function copyGeometry() {
    if (element.kind === "divider") return {
      x1: element.x1, y1: element.y1, x2: element.x2, y2: element.y2
    }
    return { x: element.x, y: element.y, w: element.w, h: element.h }
  }

  function beginPointer(mouseArea, mouse, mode) {
    dashboard.selectElement(element.id)
    pointerStart = canvasPoint(mouseArea, mouse)
    startGeometry = copyGeometry()
    previewGeometry = copyGeometry()
    pointerMode = mode
    verticalGuideVisible = false
    horizontalGuideVisible = false
  }

  function updatePointer(mouseArea, mouse) {
    if (!pointerMode || !startGeometry) return
    var point = canvasPoint(mouseArea, mouse)
    var step = dashboard.dashboardState.gridSpacing
    var dx = point.x - pointerStart.x
    var dy = point.y - pointerStart.y

    if (element.kind === "text") {
      if (pointerMode === "resize") {
        previewGeometry = {
          x: startGeometry.x,
          y: startGeometry.y,
          w: Math.max(40, Math.min(gridWidth - startGeometry.x,
            GridEngine.snapFrom(startGeometry.w, dx, step))),
          h: Math.max(20, Math.min(gridHeight - startGeometry.y,
            GridEngine.snapFrom(startGeometry.h, dy, step)))
        }
      } else {
        var candidate = {
          x: Math.max(0, Math.min(gridWidth - startGeometry.w,
            GridEngine.snapFrom(startGeometry.x, dx, step))),
          y: Math.max(0, Math.min(gridHeight - startGeometry.h,
            GridEngine.snapFrom(startGeometry.y, dy, step))),
          w: startGeometry.w,
          h: startGeometry.h
        }
        var alignment = GridEngine.snapRectToCenter(
          candidate, gridWidth, gridHeight, Math.max(12, step / 2), step)
        previewGeometry = alignment.rect
        verticalGuideVisible = alignment.vertical
        horizontalGuideVisible = alignment.horizontal
        verticalGuidePosition = alignment.verticalPosition
        horizontalGuidePosition = alignment.horizontalPosition
      }
      return
    }

    var geometry = {
      x1: startGeometry.x1, y1: startGeometry.y1,
      x2: startGeometry.x2, y2: startGeometry.y2
    }
    if (pointerMode === "start") {
      if (startGeometry.y1 === startGeometry.y2)
        geometry.x1 = Math.max(0, Math.min(gridWidth,
          GridEngine.snapFrom(startGeometry.x1, dx, step)))
      else geometry.y1 = Math.max(0, Math.min(gridHeight,
        GridEngine.snapFrom(startGeometry.y1, dy, step)))
    } else if (pointerMode === "end") {
      if (startGeometry.y1 === startGeometry.y2)
        geometry.x2 = Math.max(0, Math.min(gridWidth,
          GridEngine.snapFrom(startGeometry.x2, dx, step)))
      else geometry.y2 = Math.max(0, Math.min(gridHeight,
        GridEngine.snapFrom(startGeometry.y2, dy, step)))
    } else {
      var wantedX = GridEngine.snapFrom(startGeometry.x1, dx, step)
      var wantedY = GridEngine.snapFrom(startGeometry.y1, dy, step)
      var moveX = wantedX - startGeometry.x1
      var moveY = wantedY - startGeometry.y1
      moveX = Math.max(-Math.min(startGeometry.x1, startGeometry.x2),
        Math.min(gridWidth - Math.max(startGeometry.x1, startGeometry.x2), moveX))
      moveY = Math.max(-Math.min(startGeometry.y1, startGeometry.y2),
        Math.min(gridHeight - Math.max(startGeometry.y1, startGeometry.y2), moveY))
      geometry.x1 += moveX
      geometry.x2 += moveX
      geometry.y1 += moveY
      geometry.y2 += moveY
    }
    previewGeometry = geometry
  }

  function finishPointer() {
    if (previewGeometry) dashboard.placeElement(element.id, previewGeometry)
    clearPointer()
  }

  function clearPointer() {
    previewGeometry = null
    startGeometry = null
    pointerMode = ""
    verticalGuideVisible = false
    horizontalGuideVisible = false
  }

  CanvasAlignmentGuides {
    parent: root.canvas
    verticalGuideVisible: root.verticalGuideVisible
    horizontalGuideVisible: root.horizontalGuideVisible
    verticalGuidePosition: root.verticalGuidePosition
    horizontalGuidePosition: root.horizontalGuidePosition
  }

  Item {
    id: textFrame
    visible: root.element.kind === "text"
    x: visible ? (root.shown.x || 0) : 0
    y: visible ? (root.shown.y || 0) : 0
    width: visible ? (root.shown.w || 0) : 0
    height: visible ? (root.shown.h || 0) : 0

    Text {
      textFormat: Text.PlainText
      anchors.fill: parent
      objectName: "graphicText"
      text: String(root.element.text || "")
      color: Color.popups.text
      font.family: Style.font.family
      font.bold: true
      font.pixelSize: Math.max(Style.font.title, Math.min(Style.space(180), height * 0.78))
      fontSizeMode: Text.Fit
      minimumPixelSize: Math.max(8, Style.font.caption)
      horizontalAlignment: root.element.alignment === "right" ? Text.AlignRight
        : (root.element.alignment === "center" ? Text.AlignHCenter : Text.AlignLeft)
      verticalAlignment: Text.AlignVCenter
      elide: Text.ElideRight
    }

    Rectangle {
      anchors.fill: parent
      visible: root.editing && root.selected
      color: "transparent"
      border.width: 1
      border.color: Color.accent
      radius: Style.cornerRadius
    }

    MouseArea {
      id: textDragArea
      anchors.fill: parent
      enabled: root.editing
      hoverEnabled: true
      cursorShape: enabled ? Qt.SizeAllCursor : Qt.ArrowCursor
      preventStealing: true
      onPressed: function(mouse) { root.beginPointer(textDragArea, mouse, "move") }
      onPositionChanged: function(mouse) { root.updatePointer(textDragArea, mouse) }
      onReleased: root.finishPointer()
      onCanceled: root.clearPointer()
      onDoubleClicked: root.editTextRequested(root.element.id, root.element.text)
    }

    Rectangle {
      anchors.right: parent.right
      anchors.bottom: parent.bottom
      width: Style.space(24)
      height: width
      visible: root.editing && root.selected
      radius: Style.cornerRadius
      color: textResizeArea.containsMouse ? Color.accent : Color.popups.background
      border.width: 1
      border.color: Color.accent
      z: 5
      Text {
        textFormat: Text.PlainText
        anchors.centerIn: parent
        text: "\uf065"
        color: Color.popups.text
        font.family: Style.font.family
        font.pixelSize: Style.font.caption
      }
      MouseArea {
        id: textResizeArea
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.SizeFDiagCursor
        preventStealing: true
        onPressed: function(mouse) { root.beginPointer(textResizeArea, mouse, "resize") }
        onPositionChanged: function(mouse) { root.updatePointer(textResizeArea, mouse) }
        onReleased: root.finishPointer()
        onCanceled: root.clearPointer()
      }
    }

    Rectangle {
      anchors.right: parent.right
      anchors.top: parent.top
      width: Style.space(24)
      height: width
      visible: root.editing && root.selected
      radius: Style.cornerRadius
      color: textRemoveArea.containsMouse ? Color.accent : Color.popups.background
      border.width: 1
      border.color: Color.accent
      z: 5
      Text {
        textFormat: Text.PlainText
        anchors.centerIn: parent
        text: "\uf1f8"
        color: Color.popups.text
        font.family: Style.font.family
        font.pixelSize: Style.font.caption
      }
      MouseArea {
        id: textRemoveArea
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.dashboard.removeElement(root.element.id)
      }
    }
  }

  Item {
    id: dividerFrame
    visible: root.element.kind === "divider"
    x: visible ? Math.min(root.shown.x1, root.shown.x2) - (root.horizontalDivider ? 0 : hitPadding) : 0
    y: visible ? Math.min(root.shown.y1, root.shown.y2) - (root.horizontalDivider ? hitPadding : 0) : 0
    width: visible ? (root.horizontalDivider
      ? Math.abs(root.shown.x2 - root.shown.x1) : hitPadding * 2) : 0
    height: visible ? (root.horizontalDivider
      ? hitPadding * 2 : Math.abs(root.shown.y2 - root.shown.y1)) : 0
    readonly property real hitPadding: Math.max(8, Style.space(8), root.dividerThickness / 2)

    Rectangle {
      objectName: "graphicDivider"
      x: root.horizontalDivider ? 0 : Math.round((parent.width - width) / 2)
      y: root.horizontalDivider ? Math.round((parent.height - height) / 2) : 0
      width: root.horizontalDivider ? parent.width : root.dividerThickness
      height: root.horizontalDivider ? root.dividerThickness : parent.height
      radius: Math.min(width, height) / 2
      color: root.selected ? Color.accent : Color.popups.text
      opacity: root.selected ? 1 : 0.48
    }

    MouseArea {
      id: dividerDragArea
      anchors.fill: parent
      enabled: root.editing
      hoverEnabled: true
      cursorShape: enabled ? Qt.SizeAllCursor : Qt.ArrowCursor
      preventStealing: true
      onPressed: function(mouse) { root.beginPointer(dividerDragArea, mouse, "move") }
      onPositionChanged: function(mouse) { root.updatePointer(dividerDragArea, mouse) }
      onReleased: root.finishPointer()
      onCanceled: root.clearPointer()
    }
  }

  Repeater {
    model: root.element.kind === "divider" && root.editing && root.selected ? 2 : 0
    delegate: Rectangle {
      id: endpointHandle
      required property int index
      readonly property bool atStart: index === 0
      width: Style.space(18)
      height: width
      radius: width / 2
      x: (atStart ? root.shown.x1 : root.shown.x2) - width / 2
      y: (atStart ? root.shown.y1 : root.shown.y2) - height / 2
      color: endpointMouse.containsMouse ? Color.accent : Color.popups.background
      border.width: 2
      border.color: Color.accent
      z: 6
      MouseArea {
        id: endpointMouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: root.horizontalDivider ? Qt.SizeHorCursor : Qt.SizeVerCursor
        preventStealing: true
        onPressed: function(mouse) {
          root.beginPointer(endpointMouse, mouse, endpointHandle.atStart ? "start" : "end")
        }
        onPositionChanged: function(mouse) { root.updatePointer(endpointMouse, mouse) }
        onReleased: root.finishPointer()
        onCanceled: root.clearPointer()
      }
    }
  }

  Rectangle {
    visible: root.element.kind === "divider" && root.editing && root.selected
    x: (root.shown.x1 + root.shown.x2 - width) / 2
    y: (root.shown.y1 + root.shown.y2 - height) / 2
    width: Style.space(24)
    height: width
    radius: width / 2
    color: dividerRemoveArea.containsMouse ? Color.accent : Color.popups.background
    border.width: 1
    border.color: Color.accent
    z: 7
    Text {
      textFormat: Text.PlainText
      anchors.centerIn: parent
      text: "\uf1f8"
      color: Color.popups.text
      font.family: Style.font.family
      font.pixelSize: Style.font.caption
    }
    MouseArea {
      id: dividerRemoveArea
      anchors.fill: parent
      hoverEnabled: true
      cursorShape: Qt.PointingHandCursor
      onClicked: root.dashboard.removeElement(root.element.id)
    }
  }
}
