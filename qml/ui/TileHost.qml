pragma ComponentBehavior: Bound

import QtQuick
import qs.Commons
import "../core/GridEngine.js" as GridEngine

Item {
  id: root

  required property var dashboard
  required property string tileId
  required property string tilePluginId
  required property string tileLabel
  required property string tileEmbedding
  required property real tileX
  required property real tileY
  required property real tileW
  required property real tileH
  readonly property var tile: tileData
  QtObject {
    id: tileData
    property string id: root.tileId
    property string pluginId: root.tilePluginId
    property string label: root.tileLabel
    property string embedding: root.tileEmbedding
    property real x: root.tileX
    property real y: root.tileY
    property real w: root.tileW
    property real h: root.tileH
  }
  required property Item canvas
  property real gridWidth: 0
  property real gridHeight: 0
  property bool surfaceActive: false
  property bool keepLoaded: surfaceActive
  property var previewRect: null
  property point pointerStart: Qt.point(0, 0)
  property var startRect: null
  property bool dragging: false
  property bool resizing: false
  property bool resizeLeft: false
  property bool resizeRight: false
  property bool resizeTop: false
  property bool resizeBottom: false
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
  readonly property bool pointerEnabled: surfaceActive && dashboard.overlay === ""
    && !dashboard.placingPlugin && !dashboard.placingDivider
  readonly property bool interacting: canInteract && surfaceActive && dashboard.overlay === ""
    && dashboard.mode === "interact" && selected
  readonly property bool canInteract: (presentation.kind === "embedded" || presentation.kind === "widget")
    && loadedPage !== null && pageError === ""
  readonly property real frameWidth: editing || interacting ? Style.space(3) : 1
  readonly property string keyboardShortcut: dashboard.keyboardShortcutForTile(tile.id)
  readonly property bool keyboardShortcutVisible: dashboard.shortcutHintsVisible
    && keyboardShortcut !== "" && !interacting
  readonly property bool previewValid: previewRect !== null
    && GridEngine.canPlace(previewRect, dashboard.activeTiles, tile.id, gridWidth, gridHeight)
  readonly property var presentation: dashboard.plugins.presentation(tile)
  readonly property string sourceUrl: String(presentation.source || "")
  readonly property bool compactActionTile: (presentation.kind === "launcher" || presentation.kind === "control")
    && Math.min(width, height) < Style.space(96)
  readonly property real resizeHandleWidth: Math.max(Style.space(10), Style.spacing.sm * 2)

  x: tile.x
  y: tile.y
  width: tile.w
  height: tile.h
  z: selected ? 2 : 1

  function pointInCanvas(mouseArea, mouse) {
    return mouseArea.mapToItem(canvas, mouse.x, mouse.y)
  }

  function beginPointer(mouseArea, mouse, resizeEdges) {
    dashboard.selectTileId(tile.id)
    var point = pointInCanvas(mouseArea, mouse)
    pointerStart = Qt.point(point.x, point.y)
    startRect = { x: tile.x, y: tile.y, w: tile.w, h: tile.h }
    previewRect = { x: tile.x, y: tile.y, w: tile.w, h: tile.h }
    resizeLeft = resizeEdges && resizeEdges.left === true
    resizeRight = resizeEdges && resizeEdges.right === true
    resizeTop = resizeEdges && resizeEdges.top === true
    resizeBottom = resizeEdges && resizeEdges.bottom === true
    resizing = resizeLeft || resizeRight || resizeTop || resizeBottom
    dragging = !resizing
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
      var compact = presentation.kind === "launcher" || presentation.kind === "control"
      var minW = compact ? GridEngine.MIN_WIDTH : hints.minW
      var minH = compact ? GridEngine.MIN_HEIGHT : hints.minH
      var left = startRect.x
      var right = startRect.x + startRect.w
      var top = startRect.y
      var bottom = startRect.y + startRect.h
      if (resizeLeft)
        left = Math.max(0, Math.min(right - minW,
          GridEngine.snapFrom(startRect.x, deltaX, gridStep)))
      else if (resizeRight)
        right = Math.min(gridWidth, Math.max(left + minW,
          GridEngine.snapFrom(startRect.x + startRect.w, deltaX, gridStep)))
      if (resizeTop)
        top = Math.max(0, Math.min(bottom - minH,
          GridEngine.snapFrom(startRect.y, deltaY, gridStep)))
      else if (resizeBottom)
        bottom = Math.min(gridHeight, Math.max(top + minH,
          GridEngine.snapFrom(startRect.y + startRect.h, deltaY, gridStep)))
      candidate = {
        x: left, y: top, w: right - left, h: bottom - top
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
    resizeLeft = false
    resizeRight = false
    resizeTop = false
    resizeBottom = false
    verticalGuideVisible = false
    horizontalGuideVisible = false
    previewRect = null
    startRect = null
  }

  function cancelPointer() {
    clearPointer()
  }

  function focusPlugin() {
    if (interacting && loadedPage) dashboard.plugins.focusPage(loadedPage)
  }

  function selectForPointer() {
    if (!pointerEnabled || editing || selected) return
    // Selection by hover must not automatically activate the next plugin.
    if (dashboard.mode === "interact") dashboard.mode = "browse"
    dashboard.selectTileId(tile.id)
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
    if (!interacting && surfaceActive) passiveRestoreTimer.restart()
  }

  function restoreIfPassive() {
    if (!interacting && surfaceActive) restorePlugin()
  }

  function initializeLoadedPage() {
    loadedPage = pageLoader.item
    pageError = ""
    if (!dashboard.plugins.inject(loadedPage, tile)) {
      unloadPage("initialization-failed")
      pageError = "The plugin page failed during initialization."
    } else if (interacting) focusTimer.restart()
  }

  function unloadPage(reason) {
    var page = loadedPage
    loadedPage = null
    if (page) dashboard.plugins.deactivate(page, reason)
  }

  onSourceUrlChanged: {
    pageError = ""
    if (!sourceUrl && surfaceActive && presentation && presentation.state === "preparing")
      dashboard.plugins.requestAdaptation(tile.pluginId)
  }
  onSurfaceActiveChanged: {
    if (surfaceActive && !sourceUrl && presentation && presentation.state === "preparing")
      dashboard.plugins.requestAdaptation(tile.pluginId)
    // Hidden visited pages retain their Loader; only input/focus is suspended.
    if (surfaceActive && loadedPage) restorePassivePlugin()
  }
  onPresentationChanged: {
    launchError = ""
    if (surfaceActive && !sourceUrl && presentation && presentation.state === "preparing")
      dashboard.plugins.requestAdaptation(tile.pluginId)
  }
  onInteractingChanged: {
    if (interacting) {
      hadInteraction = true
      focusTimer.restart()
    } else if (hadInteraction) {
      focusTimer.stop()
      hadInteraction = false
      if (surfaceActive) restorePlugin()
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
  Component.onDestruction: {
    focusTimer.stop()
    passiveRestoreTimer.stop()
    unloadPage("tile-destroyed")
    pageLoader.active = false
  }

  // Object-owned timers are cancelled with a cached tile. Deferred JavaScript
  // callbacks can otherwise outlive its QML context during a quick close.
  Timer { id: focusTimer; interval: 0; onTriggered: root.focusPlugin() }
  Timer { id: passiveRestoreTimer; interval: 0; onTriggered: root.restoreIfPassive() }

  component ResizeHandle: MouseArea {
    id: resizeHandle
    property bool resizeLeft: false
    property bool resizeRight: false
    property bool resizeTop: false
    property bool resizeBottom: false

    enabled: root.editing
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
    onCanceled: root.cancelPointer()
  }

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
    border.width: root.frameWidth
    border.color: root.selected
      ? Color.accent
      : Qt.rgba(Color.popups.text.r, Color.popups.text.g, Color.popups.text.b, 0.09)

    Behavior on opacity { NumberAnimation { duration: 90 } }

    Item {
      id: content
      anchors.fill: parent
      anchors.margins: root.presentation.contentLayout === "edge-to-edge" ? 0
        : (root.compactActionTile ? Style.space(3) : Style.space(10))
      clip: true
      z: root.presentation.kind === "launcher" || root.presentation.kind === "control" ? 5 : 0

      Loader {
        id: pageLoader
        anchors.fill: parent
        enabled: root.interacting
        active: root.keepLoaded && root.sourceUrl !== "" && root.pageError === ""
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
          || root.pageError !== ""
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
        spacing: root.compactActionTile ? 0 : Style.spacing.md
        visible: root.presentation.kind === "launcher"
        opacity: root.presentation.canLaunch ? 1 : 0.52

        Item {
          anchors.horizontalCenter: parent.horizontalCenter
          width: root.compactActionTile
            ? Math.max(0, Math.min(Style.space(104), content.width, content.height))
            : Math.max(Style.space(38), Math.min(
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
          visible: !root.compactActionTile
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
          visible: !root.compactActionTile && root.launchError.length > 0
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
        spacing: root.compactActionTile ? 0 : Style.spacing.sm
        visible: root.presentation.kind === "control"

        Text {
          textFormat: Text.PlainText
          anchors.horizontalCenter: parent.horizontalCenter
          text: root.presentation.icon
          color: root.presentation.active ? Color.accent : Color.popups.text
          opacity: root.presentation.state === "preparing" ? 0.45 : 0.9
          font.family: Style.font.family
          font.pixelSize: root.compactActionTile
            ? Math.max(0, Math.min(Style.space(40), Math.floor(Math.min(content.width, content.height) * 0.65)))
            : Style.space(28)
        }
        Text {
          textFormat: Text.PlainText
          width: parent.width
          visible: !root.compactActionTile
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
          visible: !root.compactActionTile
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
          visible: !root.compactActionTile && root.launchError.length > 0
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
      visible: root.keyboardShortcutVisible
      radius: Style.cornerRadius
      color: Qt.rgba(0, 0, 0, 0.22)
      z: 5
    }

    Rectangle {
      anchors.fill: parent
      visible: root.interacting || root.presentation.contentLayout === "edge-to-edge"
      radius: Style.cornerRadius
      color: "transparent"
      border.width: root.frameWidth
      border.color: root.selected
        ? Color.accent
        : Qt.rgba(Color.popups.text.r, Color.popups.text.g, Color.popups.text.b, 0.09)
      z: 10
    }

    Rectangle {
      visible: root.keyboardShortcutVisible
      anchors.centerIn: parent
      width: Math.max(height, shortcutText.implicitWidth + Style.space(32))
      height: Style.space(58)
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
        font.pixelSize: Style.font.title
        font.bold: true
      }
    }

    MouseArea {
      id: actionMouse
      anchors.fill: parent
      enabled: root.pointerEnabled && !root.interacting && !root.editing
      acceptedButtons: Qt.LeftButton
      hoverEnabled: true
      cursorShape: root.canInteract || root.presentation.kind === "control"
        || (root.presentation.kind === "launcher" && root.presentation.canLaunch)
        ? Qt.PointingHandCursor : Qt.ArrowCursor
      onPositionChanged: function(mouse) {
        if (mouse.buttons === Qt.NoButton) root.selectForPointer()
      }
      onClicked: {
        root.selectForPointer()
        root.dashboard.selectTileId(root.tile.id)
        if (root.canInteract || root.presentation.kind === "control"
            || (root.presentation.kind === "launcher" && root.presentation.canLaunch))
          root.activateAction()
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

    ResizeHandle {
      z: 25
      anchors.left: parent.left
      anchors.top: parent.top
      width: root.resizeHandleWidth
      height: width
      resizeLeft: true
      resizeTop: true
    }

    ResizeHandle {
      z: 25
      anchors.right: parent.right
      anchors.top: parent.top
      width: root.resizeHandleWidth
      height: width
      resizeRight: true
      resizeTop: true
    }

    ResizeHandle {
      z: 25
      anchors.left: parent.left
      anchors.bottom: parent.bottom
      width: root.resizeHandleWidth
      height: width
      resizeLeft: true
      resizeBottom: true
    }

    ResizeHandle {
      z: 25
      anchors.right: parent.right
      anchors.bottom: parent.bottom
      width: root.resizeHandleWidth
      height: width
      resizeRight: true
      resizeBottom: true
    }

    ResizeHandle {
      z: 25
      anchors.left: parent.left
      anchors.right: parent.right
      anchors.top: parent.top
      anchors.leftMargin: root.resizeHandleWidth
      anchors.rightMargin: root.resizeHandleWidth
      height: root.resizeHandleWidth
      resizeTop: true
    }

    ResizeHandle {
      z: 25
      anchors.left: parent.left
      anchors.right: parent.right
      anchors.bottom: parent.bottom
      anchors.leftMargin: root.resizeHandleWidth
      anchors.rightMargin: root.resizeHandleWidth
      height: root.resizeHandleWidth
      resizeBottom: true
    }

    ResizeHandle {
      z: 25
      anchors.left: parent.left
      anchors.top: parent.top
      anchors.bottom: parent.bottom
      anchors.topMargin: root.resizeHandleWidth
      anchors.bottomMargin: root.resizeHandleWidth
      width: root.resizeHandleWidth
      resizeLeft: true
    }

    ResizeHandle {
      z: 25
      anchors.right: parent.right
      anchors.top: parent.top
      anchors.bottom: parent.bottom
      anchors.topMargin: root.resizeHandleWidth
      anchors.bottomMargin: root.resizeHandleWidth
      width: root.resizeHandleWidth
      resizeRight: true
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
