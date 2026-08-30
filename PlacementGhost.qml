pragma ComponentBehavior: Bound

import QtQuick
import qs.Commons
import "GridEngine.js" as GridEngine

Item {
  id: root

  required property var dashboard
  required property Item canvas
  property point pointerStart: Qt.point(0, 0)
  property var startRect: null
  property bool resizing: false
  property bool verticalGuideVisible: false
  property bool horizontalGuideVisible: false

  readonly property var draft: dashboard.placementDraft
  readonly property var rect: draft ? draft.rect : ({ x: 0, y: 0, w: 0, h: 0 })
  readonly property bool valid: dashboard.placementValid

  x: rect.x
  y: rect.y
  width: rect.w
  height: rect.h
  visible: dashboard.placingPlugin
  z: 40

  function pointInCanvas(mouseArea, mouse) {
    return mouseArea.mapToItem(canvas, mouse.x, mouse.y)
  }

  function beginPointer(mouseArea, mouse, resizeMode) {
    var point = pointInCanvas(mouseArea, mouse)
    pointerStart = Qt.point(point.x, point.y)
    startRect = { x: rect.x, y: rect.y, w: rect.w, h: rect.h }
    resizing = resizeMode
    verticalGuideVisible = false
    horizontalGuideVisible = false
  }

  function updatePointer(mouseArea, mouse) {
    if (!startRect || !draft) return
    var point = pointInCanvas(mouseArea, mouse)
    var step = dashboard.dashboardState.gridSpacing
    var deltaX = point.x - pointerStart.x
    var deltaY = point.y - pointerStart.y
    if (resizing) {
      dashboard.updatePlacementRect({
        x: startRect.x,
        y: startRect.y,
        w: Math.max(draft.minW, Math.min(canvas.width - startRect.x,
          GridEngine.snapFrom(startRect.w, deltaX, step))),
        h: Math.max(draft.minH, Math.min(canvas.height - startRect.y,
          GridEngine.snapFrom(startRect.h, deltaY, step)))
      })
    } else {
      var x = GridEngine.snapFrom(startRect.x, deltaX, step)
      var y = GridEngine.snapFrom(startRect.y, deltaY, step)
      var candidate = {
        x: Math.max(0, Math.min(canvas.width - startRect.w, x)),
        y: Math.max(0, Math.min(canvas.height - startRect.h, y)),
        w: startRect.w,
        h: startRect.h
      }
      var alignment = GridEngine.snapRectToCenter(
        candidate, canvas.width, canvas.height, Math.max(12, step / 2))
      verticalGuideVisible = alignment.vertical
      horizontalGuideVisible = alignment.horizontal
      dashboard.updatePlacementRect(alignment.rect)
    }
  }

  function finishPointer() {
    startRect = null
    resizing = false
    verticalGuideVisible = false
    horizontalGuideVisible = false
  }

  CanvasAlignmentGuides {
    parent: root.canvas
    verticalGuideVisible: root.verticalGuideVisible
    horizontalGuideVisible: root.horizontalGuideVisible
  }

  TileSilhouette {
    anchors.fill: parent
    valid: root.valid
    title: root.draft ? root.draft.label : ""
    detail: root.width + " × " + root.height
  }

  MouseArea {
    id: moveArea
    anchors.fill: parent
    hoverEnabled: true
    cursorShape: Qt.SizeAllCursor
    preventStealing: true
    onPressed: function(mouse) { root.beginPointer(moveArea, mouse, false) }
    onPositionChanged: function(mouse) { root.updatePointer(moveArea, mouse) }
    onReleased: root.finishPointer()
    onCanceled: root.finishPointer()
  }

  Rectangle {
    anchors.right: parent.right
    anchors.bottom: parent.bottom
    anchors.margins: Style.spacing.xs
    width: Style.space(28)
    height: width
    radius: Style.cornerRadius
    color: resizeArea.containsMouse || root.resizing ? root.valid
      ? Color.accent : Qt.rgba(0.95, 0.25, 0.30, 1)
      : Color.popups.background
    border.width: 1
    border.color: root.valid ? Color.accent : Qt.rgba(0.95, 0.25, 0.30, 1)
    z: 2

    Text {
      anchors.centerIn: parent
      text: "\uf065"
      color: Color.popups.text
      font.family: Style.font.family
      font.pixelSize: Style.font.caption
    }
    MouseArea {
      id: resizeArea
      anchors.fill: parent
      hoverEnabled: true
      cursorShape: Qt.SizeFDiagCursor
      preventStealing: true
      onPressed: function(mouse) { root.beginPointer(resizeArea, mouse, true) }
      onPositionChanged: function(mouse) { root.updatePointer(resizeArea, mouse) }
      onReleased: root.finishPointer()
      onCanceled: root.finishPointer()
    }
  }
}
