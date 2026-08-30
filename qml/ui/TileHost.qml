pragma ComponentBehavior: Bound

import QtQuick
import qs.Commons
import "../core/GridEngine.js" as GridEngine

Item {
  id: root

  required property var dashboard
  required property var tile
  required property Item canvas
  property real gridWidth: 0
  property real gridHeight: 0
  property bool surfaceActive: false
  property var previewRect: null
  property point pointerStart: Qt.point(0, 0)
  property var startRect: null
  property bool dragging: false
  property bool resizing: false
  property bool verticalGuideVisible: false
  property bool horizontalGuideVisible: false
  property real verticalGuidePosition: 0
  property real horizontalGuidePosition: 0
  property bool hadInteraction: false
  property string pageError: ""
  property string launchError: ""
  property var loadedPage: null

  readonly property bool selected: dashboard.selectedTileId === tile.id
  readonly property bool editing: dashboard.mode === "edit"
  readonly property bool interacting: dashboard.mode === "interact" && selected
  readonly property string keyboardShortcut: dashboard.keyboardShortcutForTile(tile.id)
  readonly property bool keyboardShortcutVisible: dashboard.shortcutHintsVisible
    && keyboardShortcut !== "" && !interacting
  readonly property bool previewValid: previewRect !== null
    && GridEngine.canPlace(previewRect, dashboard.activeTiles, tile.id, gridWidth, gridHeight)
  readonly property var presentation: dashboard.plugins.presentation(tile)
  readonly property string sourceUrl: String(presentation.source || "")

  x: tile.x
  y: tile.y
  width: tile.w
  height: tile.h
  z: selected ? 2 : 1

  function pointInCanvas(mouseArea, mouse) {
    return mouseArea.mapToItem(canvas, mouse.x, mouse.y)
  }

  function beginPointer(mouseArea, mouse, resizeMode) {
    dashboard.selectTileId(tile.id)
    var point = pointInCanvas(mouseArea, mouse)
    pointerStart = Qt.point(point.x, point.y)
    startRect = { x: tile.x, y: tile.y, w: tile.w, h: tile.h }
    previewRect = { x: tile.x, y: tile.y, w: tile.w, h: tile.h }
    dragging = !resizeMode
    resizing = resizeMode
    verticalGuideVisible = false
    horizontalGuideVisible = false
  }

  function updatePointer(mouseArea, mouse) {
    if (!dragging && !resizing) return
    var point = pointInCanvas(mouseArea, mouse)
    var gridStep = dashboard.dashboardState.gridSpacing
    var deltaX = point.x - pointerStart.x
    var deltaY = point.y - pointerStart.y
    var candidate
    if (resizing) {
      var hints = dashboard.plugins.sizeHints(tile.pluginId, gridWidth, gridHeight)
      candidate = {
        x: startRect.x,
        y: startRect.y,
        w: Math.max(hints.minW, Math.min(gridWidth - startRect.x,
          GridEngine.snapFrom(startRect.w, deltaX, gridStep))),
        h: Math.max(hints.minH, Math.min(gridHeight - startRect.y,
          GridEngine.snapFrom(startRect.h, deltaY, gridStep)))
      }
    } else {
      candidate = {
        x: Math.max(0, Math.min(gridWidth - startRect.w,
          GridEngine.snapFrom(startRect.x, deltaX, gridStep))),
        y: Math.max(0, Math.min(gridHeight - startRect.h,
          GridEngine.snapFrom(startRect.y, deltaY, gridStep))),
        w: startRect.w,
        h: startRect.h
      }
      var alignment = GridEngine.snapRectToCenter(
        candidate, gridWidth, gridHeight, Math.max(12, gridStep / 2), gridStep)
      candidate = alignment.rect
      verticalGuideVisible = alignment.vertical
      horizontalGuideVisible = alignment.horizontal
      verticalGuidePosition = alignment.verticalPosition
      horizontalGuidePosition = alignment.horizontalPosition
    }
    previewRect = candidate
  }

  function finishPointer() {
    if (previewValid) dashboard.placeTile(tile.id, previewRect)
    clearPointer()
  }

  function clearPointer() {
    dragging = false
    resizing = false
    verticalGuideVisible = false
    horizontalGuideVisible = false
    previewRect = null
    startRect = null
  }

  function cancelPointer() {
    clearPointer()
  }

  function focusPlugin() {
    if (loadedPage) dashboard.plugins.focusPage(loadedPage)
  }

  function activateAction() {
    launchError = ""
    if (!dashboard.activateTile(tile))
      launchError = presentation.kind === "control"
        ? "This control is not ready yet."
        : "The plugin interface could not be opened."
  }

  function cyclePresentation() {
    var options = ["auto"]
    var available = Array.isArray(presentation.available) ? presentation.available : []
    for (var index = 0; index < available.length; index++)
      if (options.indexOf(available[index]) < 0) options.push(available[index])
    var current = options.indexOf(String(tile.embedding || "auto"))
    dashboard.setTileEmbedding(tile.id, options[(current + 1 + options.length) % options.length])
  }

  function presentationIcon() {
    var preference = String(tile.embedding || "auto")
    if (preference === "embedded") return "󰖲"
    if (preference === "widget") return "󰍉"
    if (preference === "launcher") return "󰐊"
    if (preference === "control") return "󰐥"
    return "󰒠"
  }

  function restorePlugin() {
    if (!loadedPage) return
    try {
      // Standard Panel pages close their own PanelController when their local
      // key catcher sees Escape. Re-open that controller before returning the
      // tile to browse mode so its content does not remain an empty Item.
      if (typeof loadedPage.open === "function" && "opened" in loadedPage && loadedPage.opened === false)
        loadedPage.open()
      else if ("open" in loadedPage && loadedPage.open === false) loadedPage.open = true
    } catch (error) {
      console.warn("Dashboard: failed to restore " + tile.pluginId + " after interaction:", error)
    }
  }

  function restorePassivePlugin() {
    if (!interacting && surfaceActive) Qt.callLater(function() {
      if (!root.interacting && root.surfaceActive) root.restorePlugin()
    })
  }

  function initializeLoadedPage() {
    loadedPage = pageLoader.item
    pageError = ""
    if (!dashboard.plugins.inject(loadedPage, tile)) {
      pageError = "The plugin page failed during initialization."
      pageLoader.active = false
    } else if (interacting) Qt.callLater(root.focusPlugin)
  }

  function unloadPage(reason) {
    if (loadedPage) dashboard.plugins.deactivate(loadedPage, reason)
    loadedPage = null
  }

  onSourceUrlChanged: {
    pageError = ""
    if (!sourceUrl && surfaceActive && presentation.state === "preparing")
      dashboard.plugins.requestAdaptation(tile.pluginId)
  }
  onSurfaceActiveChanged: {
    if (surfaceActive && !sourceUrl && presentation.state === "preparing")
      dashboard.plugins.requestAdaptation(tile.pluginId)
    if (!surfaceActive) unloadPage("surface-hidden")
  }
  onPresentationChanged: {
    launchError = ""
    if (surfaceActive && !sourceUrl && presentation.state === "preparing")
      dashboard.plugins.requestAdaptation(tile.pluginId)
  }
  onInteractingChanged: {
    if (interacting) {
      hadInteraction = true
      Qt.callLater(root.focusPlugin)
    } else if (hadInteraction) {
      hadInteraction = false
      restorePlugin()
    }
  }

  Connections {
    target: root.loadedPage
    ignoreUnknownSignals: true
    function onOpenedChanged() { root.restorePassivePlugin() }
    function onOpenChanged() { root.restorePassivePlugin() }
  }
  Component.onCompleted: if (surfaceActive && !sourceUrl && presentation.state === "preparing")
    dashboard.plugins.requestAdaptation(tile.pluginId)
  Component.onDestruction: unloadPage("tile-destroyed")

  CanvasAlignmentGuides {
    parent: root.canvas
    verticalGuideVisible: root.verticalGuideVisible
    horizontalGuideVisible: root.horizontalGuideVisible
    verticalGuidePosition: root.verticalGuidePosition
    horizontalGuidePosition: root.horizontalGuidePosition
  }

  Rectangle {
    id: frame
    anchors.fill: parent
    opacity: root.dragging || root.resizing ? 0.28 : 1
    radius: Style.cornerRadius
    color: root.presentation.kind === "launcher" && actionMouse.containsMouse
      ? Style.hoverFillFor(Color.popups.text, Color.accent)
      : Color.popups.background
    border.width: 1
    border.color: root.selected
      ? Color.accent
      : Qt.rgba(Color.popups.text.r, Color.popups.text.g, Color.popups.text.b, 0.09)

    Behavior on opacity { NumberAnimation { duration: 90 } }

    Item {
      id: content
      anchors.fill: parent
      anchors.margins: root.presentation.contentLayout === "edge-to-edge" ? 0 : Style.space(10)
      clip: true
      z: root.presentation.kind === "launcher" || root.presentation.kind === "control" ? 5 : 0

      Loader {
        id: pageLoader
        anchors.fill: parent
        enabled: root.interacting
        active: root.surfaceActive && root.sourceUrl !== "" && root.pageError === ""
          && (root.presentation.kind === "embedded" || root.presentation.kind === "widget")
        asynchronous: true
        source: active ? root.sourceUrl : ""
        onLoaded: root.initializeLoadedPage()
        onActiveChanged: if (!active) root.unloadPage("loader-inactive")
        onStatusChanged: if (status === Loader.Error) {
          root.pageError = "The embedded plugin page could not be loaded."
          root.unloadPage("loader-error")
        }
      }

      Column {
        anchors.centerIn: parent
        width: Math.max(0, parent.width - Style.spacing.lg * 2)
        spacing: Style.spacing.md
        z: 5
        visible: root.presentation.kind !== "launcher"
          && root.presentation.kind !== "control"
          && (root.presentation.state === "preparing"
          || pageLoader.status === Loader.Error
          )

        Text {
          textFormat: Text.PlainText
          anchors.horizontalCenter: parent.horizontalCenter
          text: root.pageError ? "⚠" : "…"
          color: root.pageError ? Color.accent : Color.popups.text
          opacity: 0.82
          font.family: Style.font.family
          font.pixelSize: Style.space(30)
        }
        Text {
          textFormat: Text.PlainText
          width: parent.width
          text: root.presentation.name || root.tile.label || root.tile.pluginId
          color: Color.popups.text
          font.family: Style.font.family
          font.pixelSize: Style.font.title
          font.bold: true
          horizontalAlignment: Text.AlignHCenter
          elide: Text.ElideRight
        }
        Text {
          textFormat: Text.PlainText
          width: parent.width
          visible: text.length > 0
          text: root.pageError || root.presentation.reason || ""
          color: Color.popups.text
          opacity: 0.58
          font.family: Style.font.family
          font.pixelSize: Style.font.caption
          horizontalAlignment: Text.AlignHCenter
          wrapMode: Text.WordWrap
          maximumLineCount: 2
          elide: Text.ElideRight
        }
      }

      Column {
        anchors.centerIn: parent
        width: Math.max(0, parent.width - Style.spacing.lg * 2)
        spacing: Style.spacing.md
        visible: root.presentation.kind === "launcher"
        opacity: root.presentation.canLaunch ? 1 : 0.52

        Item {
          anchors.horizontalCenter: parent.horizontalCenter
          width: Math.max(Style.space(38), Math.min(
            Style.space(104), content.width * 0.30, content.height * 0.38))
          height: width

          Image {
            anchors.fill: parent
            visible: root.presentation.iconKind === "image"
            source: visible ? root.presentation.icon : ""
            sourceSize.width: 256
            sourceSize.height: 256
            fillMode: Image.PreserveAspectFit
            asynchronous: true
            cache: false
            smooth: true
            mipmap: true
          }

          Text {
            textFormat: Text.PlainText
            anchors.centerIn: parent
            visible: root.presentation.iconKind !== "image"
            text: root.presentation.icon
            color: Color.popups.text
            font.family: Style.font.family
            font.pixelSize: Math.round(parent.height * 0.72)
          }
        }

        Text {
          textFormat: Text.PlainText
          width: parent.width
          text: root.presentation.name || root.tile.label || root.tile.pluginId
          color: Color.popups.text
          font.family: Style.font.family
          font.pixelSize: Style.font.title
          font.bold: true
          horizontalAlignment: Text.AlignHCenter
          wrapMode: Text.WordWrap
          maximumLineCount: 2
          elide: Text.ElideRight
        }

        Text {
          textFormat: Text.PlainText
          width: parent.width
          visible: root.launchError.length > 0
          text: root.launchError
          color: Color.accent
          font.family: Style.font.family
          font.pixelSize: Style.font.caption
          horizontalAlignment: Text.AlignHCenter
          elide: Text.ElideRight
        }
      }

      Rectangle {
        anchors.fill: parent
        visible: root.presentation.kind === "control" && root.presentation.active
        radius: Style.cornerRadius
        color: Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.10)
      }

      Column {
        anchors.centerIn: parent
        width: Math.max(0, parent.width - Style.spacing.lg * 2)
        spacing: Style.spacing.sm
        visible: root.presentation.kind === "control"

        Text {
          textFormat: Text.PlainText
          anchors.horizontalCenter: parent.horizontalCenter
          text: root.presentation.icon
          color: root.presentation.active ? Color.accent : Color.popups.text
          opacity: root.presentation.state === "preparing" ? 0.45 : 0.9
          font.family: Style.font.family
          font.pixelSize: Style.space(28)
        }
        Text {
          textFormat: Text.PlainText
          width: parent.width
          text: root.presentation.name || root.tile.label
          color: Color.popups.text
          font.family: Style.font.family
          font.pixelSize: Style.font.body
          font.bold: true
          horizontalAlignment: Text.AlignHCenter
          elide: Text.ElideRight
        }
        Rectangle {
          anchors.horizontalCenter: parent.horizontalCenter
          width: controlStatus.implicitWidth + Style.spacing.md * 2
          height: Style.space(24)
          radius: Style.cornerRadius > 0 ? height / 2 : 0
          color: root.presentation.active
            ? Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.20)
            : Qt.rgba(Color.popups.text.r, Color.popups.text.g, Color.popups.text.b, 0.07)
          Text {
            textFormat: Text.PlainText
            id: controlStatus
            anchors.centerIn: parent
            text: root.presentation.statusText || ""
            color: root.presentation.active ? Color.accent : Color.popups.text
            opacity: root.presentation.state === "preparing" ? 0.55 : 0.82
            font.family: Style.font.family
            font.pixelSize: Style.font.caption
            font.bold: true
          }
        }
        Text {
          textFormat: Text.PlainText
          width: parent.width
          visible: root.launchError.length > 0
          text: root.launchError
          color: Color.accent
          font.family: Style.font.family
          font.pixelSize: Style.font.caption
          horizontalAlignment: Text.AlignHCenter
          elide: Text.ElideRight
        }
      }
    }

    Rectangle {
      anchors.fill: parent
      visible: root.presentation.contentLayout === "edge-to-edge"
      radius: Style.cornerRadius
      color: "transparent"
      border.width: 1
      border.color: root.selected
        ? Color.accent
        : Qt.rgba(Color.popups.text.r, Color.popups.text.g, Color.popups.text.b, 0.09)
      z: 10
    }

    Rectangle {
      anchors.left: parent.left
      anchors.top: parent.top
      anchors.margins: Style.spacing.sm
      visible: root.keyboardShortcutVisible
      width: shortcutText.implicitWidth + Style.spacing.md * 2
      height: Math.max(Style.space(26), shortcutText.implicitHeight + Style.spacing.xs * 2)
      radius: Style.cornerRadius > 0 ? height / 2 : 0
      z: 25
      color: Qt.rgba(Color.popups.background.r, Color.popups.background.g,
        Color.popups.background.b, 0.90)
      border.width: 1
      border.color: root.selected
        ? Color.accent
        : Qt.rgba(Color.popups.text.r, Color.popups.text.g, Color.popups.text.b, 0.18)

      Text {
        textFormat: Text.PlainText
        id: shortcutText
        anchors.centerIn: parent
        text: root.keyboardShortcut
        color: root.selected ? Color.accent : Color.popups.text
        font.family: Style.font.family
        font.pixelSize: Style.font.caption
        font.bold: true
      }
    }

    MouseArea {
      id: actionMouse
      anchors.fill: parent
      enabled: !root.interacting && !root.editing
      acceptedButtons: Qt.LeftButton
      hoverEnabled: true
      cursorShape: root.presentation.kind === "control"
        || (root.presentation.kind === "launcher" && root.presentation.canLaunch)
        ? Qt.PointingHandCursor : Qt.ArrowCursor
      onClicked: {
        root.dashboard.selectTileId(root.tile.id)
        if (root.presentation.kind === "control"
            || (root.presentation.kind === "launcher" && root.presentation.canLaunch))
          root.activateAction()
      }
      onDoubleClicked: {
        if (root.presentation.kind === "control" || root.presentation.kind === "launcher") return
        root.dashboard.selectTileId(root.tile.id)
        root.dashboard.activateTile(root.tile)
      }
    }

    MouseArea {
      id: dragArea
      anchors.fill: parent
      enabled: root.editing
      z: 20
      hoverEnabled: true
      cursorShape: enabled ? Qt.SizeAllCursor : Qt.ArrowCursor
      preventStealing: true
      onPressed: function(mouse) { root.beginPointer(dragArea, mouse, false) }
      onPositionChanged: function(mouse) { root.updatePointer(dragArea, mouse) }
      onReleased: root.finishPointer()
      onCanceled: root.cancelPointer()
    }

    Rectangle {
      visible: root.editing
      anchors.left: parent.left
      anchors.top: parent.top
      anchors.margins: Style.spacing.xs
      width: Style.space(26)
      height: width
      radius: Style.cornerRadius > 0 ? height / 2 : 0
      z: 30
      color: presentationMouse.containsMouse
        ? Color.accent
        : Qt.rgba(Color.popups.background.r, Color.popups.background.g, Color.popups.background.b, 0.88)
      Text {
        textFormat: Text.PlainText
        anchors.centerIn: parent
        text: root.presentationIcon()
        color: Color.popups.text
        font.family: Style.font.family
        font.pixelSize: Style.font.caption
      }
      MouseArea {
        id: presentationMouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.cyclePresentation()
      }
    }

    Rectangle {
      visible: root.editing
      anchors.right: parent.right
      anchors.top: parent.top
      anchors.margins: Style.spacing.xs
      width: Style.space(26)
      height: width
      radius: Style.cornerRadius > 0 ? height / 2 : 0
      z: 30
      color: removeMouse.containsMouse ? Color.accent
        : Qt.rgba(Color.popups.background.r, Color.popups.background.g, Color.popups.background.b, 0.88)
      Text {
        textFormat: Text.PlainText
        anchors.centerIn: parent
        text: "\uf1f8"
        color: Color.popups.text
        font.family: Style.font.family
        font.pixelSize: Style.font.caption
      }
      MouseArea {
        id: removeMouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.dashboard.removeTile(root.tile.id)
      }
    }

    Rectangle {
      visible: root.editing
      anchors.right: parent.right
      anchors.bottom: parent.bottom
      anchors.margins: Style.spacing.xs
      width: Style.space(24)
      height: width
      radius: Style.cornerRadius
      z: 30
      color: resizeArea.containsMouse || root.resizing ? Color.accent
        : Qt.rgba(Color.popups.background.r, Color.popups.background.g, Color.popups.background.b, 0.88)
      Text {
        textFormat: Text.PlainText
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
        onCanceled: root.cancelPointer()
      }
    }
  }

  Item {
    parent: root.canvas
    visible: root.previewRect !== null
    x: visible ? root.previewRect.x : 0
    y: visible ? root.previewRect.y : 0
    width: visible ? root.previewRect.w : 0
    height: visible ? root.previewRect.h : 0
    z: 50

    TileSilhouette {
      anchors.fill: parent
      valid: root.previewValid
      title: root.presentation.name || root.tile.label || root.tile.pluginId
      detail: parent.width + " × " + parent.height
    }
  }
}
