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
  property bool resizeLeft: false
  property bool resizeRight: false
  property bool resizeTop: false
  property bool resizeBottom: false
  property bool verticalGuideVisible: false
  property bool horizontalGuideVisible: false
  property real verticalGuidePosition: 0
  property real horizontalGuidePosition: 0

  readonly property var draft: dashboard.placementDraft
  readonly property var rect: draft ? draft.rect : ({ x: 0, y: 0, w: 0, h: 0 })
  readonly property bool valid: dashboard.placementValid
  readonly property real resizeHandleWidth: Math.max(Style.space(10), Style.spacing.sm * 2)

  x: rect.x
  y: rect.y
  width: rect.w
  height: rect.h
  visible: dashboard.placingPlugin
  z: 40

  function pointInCanvas(mouseArea, mouse) {
    return mouseArea.mapToItem(canvas, mouse.x, mouse.y)
  }

  function beginPointer(mouseArea, mouse, resizeEdges) {
    var point = pointInCanvas(mouseArea, mouse)
    pointerStart = Qt.point(point.x, point.y)
    startRect = { x: rect.x, y: rect.y, w: rect.w, h: rect.h }
    resizeLeft = resizeEdges && resizeEdges.left === true
    resizeRight = resizeEdges && resizeEdges.right === true
    resizeTop = resizeEdges && resizeEdges.top === true
    resizeBottom = resizeEdges && resizeEdges.bottom === true
    resizing = resizeLeft || resizeRight || resizeTop || resizeBottom
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
      var left = startRect.x
      var right = startRect.x + startRect.w
      var top = startRect.y
      var bottom = startRect.y + startRect.h
      if (resizeLeft)
        left = Math.max(0, Math.min(right - draft.minW,
          GridEngine.snapFrom(startRect.x, deltaX, step)))
      else if (resizeRight)
        right = Math.min(canvas.width, Math.max(left + draft.minW,
          GridEngine.snapFrom(startRect.x + startRect.w, deltaX, step)))
      if (resizeTop)
        top = Math.max(0, Math.min(bottom - draft.minH,
          GridEngine.snapFrom(startRect.y, deltaY, step)))
      else if (resizeBottom)
        bottom = Math.min(canvas.height, Math.max(top + draft.minH,
          GridEngine.snapFrom(startRect.y + startRect.h, deltaY, step)))
      dashboard.updatePlacementRect({
        x: left, y: top, w: right - left, h: bottom - top
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
        candidate, canvas.width, canvas.height, Math.max(12, step / 2), step)
      verticalGuideVisible = alignment.vertical
      horizontalGuideVisible = alignment.horizontal
      verticalGuidePosition = alignment.verticalPosition
      horizontalGuidePosition = alignment.horizontalPosition
      dashboard.updatePlacementRect(alignment.rect)
    }
  }

  function finishPointer() {
    startRect = null
    resizing = false
    resizeLeft = false
    resizeRight = false
    resizeTop = false
    resizeBottom = false
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

  component ResizeHandle: MouseArea {
    id: resizeHandle
    property bool resizeLeft: false
    property bool resizeRight: false
    property bool resizeTop: false
    property bool resizeBottom: false

    hoverEnabled: true
    preventStealing: true
    cursorShape: (resizeLeft && resizeTop) || (resizeRight && resizeBottom)
      ? Qt.SizeFDiagCursor
      : ((resizeRight && resizeTop) || (resizeLeft && resizeBottom)
        ? Qt.SizeBDiagCursor
        : ((resizeLeft || resizeRight) ? Qt.SizeHorCursor : Qt.SizeVerCursor))
    onPressed: function(mouse) {
      root.beginPointer(resizeHandle, mouse, {
        left: resizeLeft, right: resizeRight, top: resizeTop, bottom: resizeBottom
      })
    }
    onPositionChanged: function(mouse) { root.updatePointer(resizeHandle, mouse) }
    onReleased: root.finishPointer()
    onCanceled: root.finishPointer()
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

  ResizeHandle {
    z: 2
    anchors.left: parent.left
    anchors.top: parent.top
    width: root.resizeHandleWidth
    height: width
    resizeLeft: true
    resizeTop: true
  }

  ResizeHandle {
    z: 2
    anchors.right: parent.right
    anchors.top: parent.top
    width: root.resizeHandleWidth
    height: width
    resizeRight: true
    resizeTop: true
  }

  ResizeHandle {
    z: 2
    anchors.left: parent.left
    anchors.bottom: parent.bottom
    width: root.resizeHandleWidth
    height: width
    resizeLeft: true
    resizeBottom: true
  }

  ResizeHandle {
    z: 2
    anchors.right: parent.right
    anchors.bottom: parent.bottom
    width: root.resizeHandleWidth
    height: width
    resizeRight: true
    resizeBottom: true
  }

  ResizeHandle {
    z: 2
    anchors.left: parent.left
    anchors.right: parent.right
    anchors.top: parent.top
    anchors.leftMargin: root.resizeHandleWidth
    anchors.rightMargin: root.resizeHandleWidth
    height: root.resizeHandleWidth
    resizeTop: true
  }

  ResizeHandle {
    z: 2
    anchors.left: parent.left
    anchors.right: parent.right
    anchors.bottom: parent.bottom
    anchors.leftMargin: root.resizeHandleWidth
    anchors.rightMargin: root.resizeHandleWidth
    height: root.resizeHandleWidth
    resizeBottom: true
  }

  ResizeHandle {
    z: 2
    anchors.left: parent.left
    anchors.top: parent.top
    anchors.bottom: parent.bottom
    anchors.topMargin: root.resizeHandleWidth
    anchors.bottomMargin: root.resizeHandleWidth
    width: root.resizeHandleWidth
    resizeLeft: true
  }

  ResizeHandle {
    z: 2
    anchors.right: parent.right
    anchors.top: parent.top
    anchors.bottom: parent.bottom
    anchors.topMargin: root.resizeHandleWidth
    anchors.bottomMargin: root.resizeHandleWidth
    width: root.resizeHandleWidth
    resizeRight: true
  }
}
