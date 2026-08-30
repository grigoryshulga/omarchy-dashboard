pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Wayland
import qs.Commons
import qs.Ui
import "GridEngine.js" as GridEngine

PanelWindow {
  id: root

  required property var dashboard
  property bool focusPrimed: false
  property string editorText: ""
  property string textEditorValue: ""
  property string textEditorElementId: ""
  property string pendingRemovalSpaceId: ""
  readonly property int surfaceInset: Math.max(Style.spacing.panelGap, Style.gapsOut)
  readonly property int cardInset: dashboard.glassBackground ? 0 : Style.gapsOut

  color: "transparent"
  exclusionMode: ExclusionMode.Ignore
  WlrLayershell.namespace: "gshulga-dashboard"
  WlrLayershell.layer: WlrLayer.Overlay
  WlrLayershell.keyboardFocus: visible
    ? (focusPrimed ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.Exclusive)
    : WlrKeyboardFocus.None
  anchors { top: true; bottom: true; left: true; right: true }
  mask: Region { width: root.width; height: root.height }

  function enterInteract() {
    if (!dashboard.selectedTileId) return
    dashboard.activateSelectedTile()
  }

  function leaveInteract() {
    dashboard.mode = "browse"
    keyCatcher.forceActiveFocus()
  }

  function beginRename() {
    editorText = dashboard.activeSpace.name
    dashboard.overlay = "rename"
  }

  function beginCreate() {
    var name = "Space " + (dashboard.dashboardState.spaces.length + 1)
    dashboard.addSpace(name)
    Qt.callLater(root.beginRename)
  }

  function finishNameEditor() {
    var value = String(editorText || "").trim()
    if (value) dashboard.renameActiveSpace(value)
    dashboard.overlay = ""
    keyCatcher.forceActiveFocus()
  }

  function beginNewText() {
    textEditorElementId = ""
    textEditorValue = "Text"
    dashboard.overlay = "text-editor"
  }

  function beginTextEdit(elementId, value) {
    textEditorElementId = String(elementId || "")
    textEditorValue = String(value || "")
    dashboard.overlay = "text-editor"
  }

  function finishTextEditor(value) {
    if (textEditorElementId) dashboard.updateText(textEditorElementId, value)
    else dashboard.addText(value)
    textEditorElementId = ""
    textEditorValue = ""
    dashboard.overlay = ""
    keyCatcher.forceActiveFocus()
  }

  function cancelTextEditor() {
    textEditorElementId = ""
    textEditorValue = ""
    dashboard.overlay = ""
    keyCatcher.forceActiveFocus()
  }

  function requestSpaceRemoval(spaceId) {
    if (dashboard.dashboardState.spaces.length <= 1) return
    pendingRemovalSpaceId = String(spaceId || "")
    if (!pendingRemovalSpaceId) return
    dashboard.overlay = "remove-space"
  }

  function cancelSpaceRemoval() {
    pendingRemovalSpaceId = ""
    dashboard.overlay = ""
    keyCatcher.forceActiveFocus()
  }

  function confirmSpaceRemoval() {
    if (pendingRemovalSpaceId) dashboard.removeSpace(pendingRemovalSpaceId)
    cancelSpaceRemoval()
  }

  function spaceName(spaceId) {
    var spaces = dashboard.dashboardState.spaces
    for (var index = 0; index < spaces.length; index++)
      if (spaces[index].id === spaceId) return spaces[index].name
    return "this Space"
  }

  function handleEscape() {
    if (dashboard.placingPlugin) {
      dashboard.cancelPluginPlacement()
      keyCatcher.forceActiveFocus()
    } else if (dashboard.overlay !== "") {
      if (dashboard.overlay === "plugin") dashboard.closePluginPopout()
      else if (dashboard.overlay === "text-editor") cancelTextEditor()
      else dashboard.overlay = ""
      keyCatcher.forceActiveFocus()
    } else {
      dashboard.handleEscape()
      if (dashboard.opened) keyCatcher.forceActiveFocus()
    }
  }

  function handleKey(event) {
    var alt = (event.modifiers & Qt.AltModifier) !== 0
    var ctrl = (event.modifiers & Qt.ControlModifier) !== 0
    var shift = (event.modifiers & Qt.ShiftModifier) !== 0

    if (event.key === Qt.Key_Escape) {
      handleEscape()
      event.accepted = true
      return
    }

    if (dashboard.overlay === "rename") {
      return
    }
    if (dashboard.overlay === "help") {
      if (event.key === Qt.Key_Question || event.key === Qt.Key_Slash) {
        dashboard.overlay = ""
        keyCatcher.forceActiveFocus()
        event.accepted = true
      }
      return
    }
    if (dashboard.overlay === "catalog") {
      return
    }
    if (dashboard.overlay === "plugin") {
      return
    }
    if (dashboard.overlay === "remove-space") {
      return
    }
    if (dashboard.overlay === "text-editor") {
      return
    }

    if (dashboard.placingPlugin) {
      if ([Qt.Key_Left, Qt.Key_Right, Qt.Key_Up, Qt.Key_Down].indexOf(event.key) >= 0) {
        var horizontal = event.key === Qt.Key_Left ? -1 : (event.key === Qt.Key_Right ? 1 : 0)
        var vertical = event.key === Qt.Key_Up ? -1 : (event.key === Qt.Key_Down ? 1 : 0)
        if (ctrl) dashboard.resizePlacementByGrid(horizontal, vertical)
        else dashboard.movePlacementByGrid(horizontal, vertical)
        event.accepted = true
      } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
        dashboard.confirmPluginPlacement()
        event.accepted = true
      }
      return
    }

    if (event.key === Qt.Key_Tab && ctrl) {
      dashboard.cycleTile(shift ? -1 : 1)
      dashboard.mode = "browse"
      keyCatcher.forceActiveFocus()
      event.accepted = true
      return
    }

    if (dashboard.mode === "interact") {
      return
    }

    if ((event.key === Qt.Key_Left || event.key === Qt.Key_Right) && alt && !ctrl) {
      if (dashboard.mode === "edit" && (dashboard.selectedTileId || dashboard.selectedElementId))
        dashboard.moveSelectedItemByGrid(event.key === Qt.Key_Left ? -1 : 1, 0)
      else dashboard.moveSpace(event.key === Qt.Key_Left ? -1 : 1)
      event.accepted = true
    } else if ((event.key === Qt.Key_Up || event.key === Qt.Key_Down) && alt && !ctrl
               && dashboard.mode === "edit") {
      dashboard.moveSelectedItemByGrid(0, event.key === Qt.Key_Up ? -1 : 1)
      event.accepted = true
    } else if (ctrl && alt && dashboard.mode === "edit"
               && [Qt.Key_Left, Qt.Key_Right, Qt.Key_Up, Qt.Key_Down].indexOf(event.key) >= 0) {
      dashboard.resizeSelectedItemByGrid(
        event.key === Qt.Key_Left ? -1 : (event.key === Qt.Key_Right ? 1 : 0),
        event.key === Qt.Key_Up ? -1 : (event.key === Qt.Key_Down ? 1 : 0)
      )
      event.accepted = true
    } else if (event.key === Qt.Key_Left) {
      dashboard.selectTile("left"); event.accepted = true
    } else if (event.key === Qt.Key_Right) {
      dashboard.selectTile("right"); event.accepted = true
    } else if (event.key === Qt.Key_Up) {
      dashboard.selectTile("up"); event.accepted = true
    } else if (event.key === Qt.Key_Down) {
      dashboard.selectTile("down"); event.accepted = true
    } else if (event.key === Qt.Key_PageUp) {
      dashboard.moveSpace(-1); event.accepted = true
    } else if (event.key === Qt.Key_PageDown) {
      dashboard.moveSpace(1); event.accepted = true
    } else if ((event.key === Qt.Key_Return || event.key === Qt.Key_Enter) && dashboard.mode === "browse") {
      enterInteract(); event.accepted = true
    } else if (event.key === Qt.Key_E && alt) {
      dashboard.toggleEditMode()
      event.accepted = true
    } else if (event.key === Qt.Key_V && alt && dashboard.mode === "edit") {
      dashboard.toggleSurfaceMode()
      event.accepted = true
    } else if ((event.key === Qt.Key_Plus || event.key === Qt.Key_Equal) && alt
               && dashboard.mode === "edit") {
      dashboard.overlay = "catalog"
      event.accepted = true
    } else if (event.key === Qt.Key_Question || (event.key === Qt.Key_Slash && shift)) {
      dashboard.overlay = "help"
      event.accepted = true
    } else if (event.key === Qt.Key_C && alt && dashboard.mode === "edit") {
      beginCreate(); event.accepted = true
    } else if (event.key === Qt.Key_R && alt && dashboard.mode === "edit") {
      beginRename(); event.accepted = true
    } else if (event.key === Qt.Key_X && alt && dashboard.mode === "edit") {
      requestSpaceRemoval(dashboard.activeSpace.id); event.accepted = true
    } else if ((event.key === Qt.Key_Delete || event.key === Qt.Key_Backspace)
               && dashboard.mode === "edit"
               && (dashboard.selectedTileId || dashboard.selectedElementId)) {
      if (dashboard.selectedElementId) dashboard.removeElement(dashboard.selectedElementId)
      else dashboard.removeTile(dashboard.selectedTileId)
      event.accepted = true
    }
  }

  onVisibleChanged: {
    if (visible) {
      dashboard.updateGridBounds(gridCanvas.width, gridCanvas.height)
      focusPrimed = false
      focusPrimeTimer.restart()
      Qt.callLater(function() { if (root.visible) keyCatcher.forceActiveFocus() })
    } else focusPrimed = false
  }

  Timer {
    id: focusPrimeTimer
    interval: 75
    onTriggered: {
      if (!root.visible) return
      root.focusPrimed = true
      keyCatcher.forceActiveFocus()
    }
  }

  Shortcut {
    sequence: "Escape"
    context: Qt.WindowShortcut
    enabled: root.visible
    onActivated: root.handleEscape()
    onActivatedAmbiguously: root.handleEscape()
  }

  DashboardSpaceShortcuts {
    dashboard: root.dashboard
    active: root.visible
  }

  Connections {
    target: dashboard
    function onModeChanged() {
      if (root.visible && dashboard.mode !== "interact")
        Qt.callLater(function() { if (root.visible) keyCatcher.forceActiveFocus() })
    }
  }

  Rectangle {
    anchors.fill: parent
    visible: dashboard.glassBackground
    color: Color.background
  }

  Item {
    id: wallpaperBackdrop
    anchors.fill: parent
    visible: dashboard.glassBackground && dashboard.backgroundUrl !== ""
    clip: true

    Image {
      id: wallpaperImage
      anchors.fill: parent
      source: dashboard.backgroundUrl
      fillMode: Image.PreserveAspectCrop
      asynchronous: true
      cache: true
      smooth: true
      mipmap: true
      sourceSize.width: width
      sourceSize.height: height
    }

    MultiEffect {
      anchors.fill: wallpaperImage
      source: wallpaperImage
      visible: dashboard.blurBackground && dashboard.blurEffect.enabled
        && wallpaperImage.status === Image.Ready
      autoPaddingEnabled: false
      blurEnabled: visible
      blur: 1
      blurMax: dashboard.blurEffect.blurMax
      brightness: dashboard.blurEffect.brightness
      contrast: dashboard.blurEffect.contrast
      saturation: dashboard.blurEffect.saturation
    }
  }

  Rectangle {
    anchors.fill: parent
    color: dashboard.glassBackground ? Color.menu.scrim : Color.background
    opacity: dashboard.dimBackground ? (dashboard.glassBackground ? 1 : 0.86) : 0
  }

  Item {
    id: keyCatcher
    anchors.fill: parent
    focus: true
    Keys.priority: Keys.BeforeItem
    Keys.onPressed: function(event) { root.handleKey(event) }

    Rectangle {
      id: dashboardCard
      anchors.fill: parent
      anchors.margins: root.cardInset
      radius: dashboard.glassBackground ? 0 : Style.cornerRadius
      color: dashboard.glassBackground
        ? "transparent" : Qt.darker(Color.popups.background, 1.14)
      border.width: dashboard.glassBackground ? 0 : Math.max(1, Style.space(1))
      border.color: Color.popups.border

      Column {
        anchors.fill: parent
        anchors.margins: root.surfaceInset - root.cardInset
        spacing: root.surfaceInset

        Item {
          id: toolbar
          width: parent.width
          height: Math.max(Style.space(42), Style.font.title + Style.spacing.controlPaddingY * 2)
          readonly property bool controlsVisible: dashboard.mode === "edit" || toolbarHover.hovered

          HoverHandler {
            id: toolbarHover
          }

          Item {
            id: spaceTitle
            anchors.right: spaceSwitcher.left
            anchors.rightMargin: Style.spacing.lg
            anchors.verticalCenter: parent.verticalCenter
            width: dashboard.overlay === "rename"
              ? Style.space(220)
              : Math.min(Style.space(300), Math.max(Style.space(128), activeSpaceName.implicitWidth + Style.space(88)))
            height: Style.space(28)

            Rectangle {
              anchors.fill: parent
              visible: dashboard.overlay !== "rename"
              radius: height / 2
              color: Qt.rgba(Color.popups.text.r, Color.popups.text.g, Color.popups.text.b, 0.07)
              border.width: 1
              border.color: Qt.rgba(Color.popups.text.r, Color.popups.text.g, Color.popups.text.b, 0.14)
            }

            Text {
              id: spaceLabel
              anchors.left: parent.left
              anchors.leftMargin: Style.spacing.sm
              anchors.verticalCenter: parent.verticalCenter
              visible: dashboard.overlay !== "rename"
              text: "SPACE"
              color: Color.popups.text
              opacity: 0.48
              font.family: Style.font.family
              font.pixelSize: Style.font.caption
              font.bold: true
            }

            Rectangle {
              anchors.left: spaceLabel.right
              anchors.leftMargin: Style.spacing.sm
              anchors.verticalCenter: parent.verticalCenter
              visible: dashboard.overlay !== "rename"
              width: 1
              height: Style.space(12)
              color: Qt.rgba(Color.popups.text.r, Color.popups.text.g, Color.popups.text.b, 0.22)
            }

            Text {
              id: activeSpaceName
              anchors.left: spaceLabel.right
              anchors.leftMargin: Style.spacing.md + 1
              anchors.right: parent.right
              anchors.rightMargin: Style.spacing.md
              anchors.verticalCenter: parent.verticalCenter
              visible: dashboard.overlay !== "rename"
              text: dashboard.activeSpace.name
              color: Color.popups.text
              font.family: Style.font.family
              font.pixelSize: Style.font.subtitle
              font.bold: true
              elide: Text.ElideRight
            }

            Rectangle {
              anchors.fill: parent
              visible: dashboard.overlay === "rename"
              radius: Style.cornerRadius
              color: Style.normalFillFor(Color.popups.text, Color.accent)
              border.width: 1
              border.color: Color.accent

              TextInput {
                id: inlineNameInput
                anchors.fill: parent
                anchors.leftMargin: Style.spacing.sm
                anchors.rightMargin: Style.spacing.sm
                visible: dashboard.overlay === "rename"
                text: visible ? root.editorText : ""
                color: Color.popups.text
                selectionColor: Color.accent
                verticalAlignment: TextInput.AlignVCenter
                font.family: Style.font.family
                font.pixelSize: Style.font.body
                onTextChanged: if (visible) root.editorText = text
                onAccepted: root.finishNameEditor()
                Keys.onEscapePressed: {
                  dashboard.overlay = ""
                  keyCatcher.forceActiveFocus()
                }
                onVisibleChanged: if (visible) Qt.callLater(function() {
                  inlineNameInput.forceActiveFocus()
                  inlineNameInput.selectAll()
                })
              }
            }

            MouseArea {
              anchors.fill: parent
              enabled: dashboard.overlay !== "rename"
              hoverEnabled: true
              cursorShape: Qt.PointingHandCursor
              onDoubleClicked: root.beginRename()
            }
          }

          Item {
            id: spaceSwitcher
            anchors.centerIn: parent
            readonly property int spaceCount: dashboard.dashboardState.spaces.length
            readonly property real tabStep: Style.space(24)
            width: spaceCount * tabStep + (dashboard.mode === "edit" ? Style.space(20) : 0)
            height: Style.space(28)

            function dropIndexFor(spaceTab) {
              var center = spaceTab.x + spaceTab.width / 2 + spaceTab.dragOffset
              return Math.max(0, Math.min(spaceCount - 1, Math.floor(center / tabStep)))
            }

            Repeater {
              model: dashboard.dashboardState.spaces
              delegate: Item {
                id: spaceTab
                required property var modelData
                required property int index
                property real dragOffset: 0
                property bool wasDragged: false
                readonly property bool active: modelData.id === dashboard.dashboardState.activeSpaceId
                x: index * spaceSwitcher.tabStep
                width: spaceSwitcher.tabStep
                height: parent.height
                z: spaceDrag.active ? 3 : 0

                transform: Translate { x: spaceTab.dragOffset }

                HoverHandler {
                  id: spaceTabHover
                }

                Rectangle {
                  id: spaceIndicator
                  anchors.centerIn: parent
                  width: Style.space(9)
                  height: width
                  radius: width / 2
                  scale: spaceTab.active ? 1.28 : 1
                  color: spaceTab.active
                    ? Color.accent
                    : (spaceTabHover.hovered ? Color.accent
                      : Qt.rgba(Color.popups.text.r, Color.popups.text.g, Color.popups.text.b, 0.32))

                  Behavior on scale { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }
                }

                MouseArea {
                  id: spaceMouse
                  anchors.fill: parent
                  hoverEnabled: true
                  cursorShape: Qt.PointingHandCursor
                  onPressed: spaceTab.wasDragged = false
                  onClicked: if (!spaceTab.wasDragged && !spaceTab.active)
                    dashboard.selectSpace(spaceTab.modelData.id)
                }

                DragHandler {
                  id: spaceDrag
                  enabled: dashboard.mode === "edit"
                  target: null
                  xAxis.enabled: true
                  yAxis.enabled: false
                  onTranslationChanged: spaceTab.dragOffset = translation.x
                  onActiveChanged: {
                    if (active) return
                    if (spaceTab.dragOffset !== 0) {
                      spaceTab.wasDragged = true
                      var targetIndex = spaceSwitcher.dropIndexFor(spaceTab)
                      spaceTab.dragOffset = 0
                      if (targetIndex !== spaceTab.index)
                        dashboard.reorderSpace(spaceTab.modelData.id, targetIndex)
                    } else spaceTab.dragOffset = 0
                  }
                }
              }
            }

            DashboardActionButton {
              anchors.right: parent.right
              anchors.verticalCenter: parent.verticalCenter
              visible: dashboard.mode === "edit"
              icon: "\uf067"
              text: "Add Space"
              expandOnHover: false
              width: Style.space(20)
              height: Style.space(20)
              onClicked: root.beginCreate()
            }
          }

          DashboardActionButton {
            anchors.right: spaceSwitcher.left
            anchors.rightMargin: Style.spacing.sm
            anchors.verticalCenter: parent.verticalCenter
            visible: dashboard.mode === "edit" && dashboard.dashboardState.spaces.length > 1
            icon: "\uf1f8"
            text: "Remove Space"
            onClicked: root.requestSpaceRemoval(dashboard.activeSpace.id)
          }

          Row {
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            spacing: Style.spacing.sm

            Row {
              visible: toolbar.controlsVisible && dashboard.mode === "edit"
              spacing: Style.spacing.xs

              Text {
                anchors.verticalCenter: parent.verticalCenter
                text: "Appearance"
                color: Color.popups.text
                opacity: 0.62
                font.family: Style.font.family
                font.pixelSize: Style.font.caption
              }
              DashboardActionButton {
                icon: "\uf2d0"
                text: "Framed"
                active: dashboard.surfaceMode === "framed"
                onClicked: dashboard.setSurfaceMode("Framed")
              }
              DashboardActionButton {
                icon: "\uf065"
                text: "Glass"
                active: dashboard.surfaceMode === "glass"
                onClicked: dashboard.setSurfaceMode("Glass")
              }
            }

            DashboardActionButton {
              visible: toolbar.controlsVisible && dashboard.mode === "edit"
              icon: "\uf12e"
              text: "Add Plugin"
              enabled: !dashboard.placingPlugin && !dashboard.placingDivider
              onClicked: dashboard.overlay = "catalog"
            }
            DashboardActionButton {
              visible: toolbar.controlsVisible && dashboard.mode === "edit"
              icon: "\uf068"
              text: "Draw Divider"
              enabled: !dashboard.placingPlugin && !dashboard.placingDivider
              onClicked: dashboard.beginDividerPlacement()
            }
            DashboardActionButton {
              visible: toolbar.controlsVisible && dashboard.mode === "edit"
              icon: "T"
              text: "Add Text"
              enabled: !dashboard.placingPlugin && !dashboard.placingDivider
              onClicked: root.beginNewText()
            }
            DashboardActionButton {
              visible: toolbar.controlsVisible
              icon: dashboard.mode === "edit" ? "\uf00c" : "\uf044"
              text: dashboard.mode === "edit" ? "Done" : "Edit"
              active: dashboard.mode === "edit"
              onClicked: {
                dashboard.toggleEditMode()
                keyCatcher.forceActiveFocus()
              }
            }
            DashboardActionButton {
              visible: toolbar.controlsVisible
              icon: "?"
              text: "Shortcuts"
              onClicked: dashboard.overlay = "help"
            }
            DashboardActionButton {
              visible: toolbar.controlsVisible
              icon: "\uf00d"
              text: "Close"
              expandOnHover: false
              onClicked: dashboard.close()
            }
          }
        }

        Item {
          id: canvasArea
          width: parent.width
          height: parent.height - toolbar.height - parent.spacing
          clip: true

          Rectangle {
            anchors.top: parent.top
            anchors.topMargin: Style.spacing.sm
            anchors.horizontalCenter: parent.horizontalCenter
            width: placementControls.implicitWidth + Style.spacing.lg * 2
            height: Style.space(42)
            visible: dashboard.placingPlugin || dashboard.placingDivider
            radius: Style.cornerRadius > 0 ? height / 2 : 0
            color: Color.popups.background
            border.width: 1
            border.color: dashboard.placingDivider || dashboard.placementValid
              ? Color.accent : Qt.rgba(0.95, 0.25, 0.30, 1)
            z: 60

            Row {
              id: placementControls
              anchors.centerIn: parent
              spacing: Style.spacing.sm

              Text {
                anchors.verticalCenter: parent.verticalCenter
                text: dashboard.placingDivider
                  ? "Drag between two grid points; the axis locks automatically"
                  : (dashboard.placementValid
                    ? "Move or resize, then place"
                    : "No room here — resize it or move another tile")
                color: dashboard.placingDivider || dashboard.placementValid
                  ? Color.popups.text : Qt.rgba(0.95, 0.45, 0.48, 1)
                font.family: Style.font.family
                font.pixelSize: Style.font.caption
              }
              DashboardActionButton {
                visible: dashboard.placingPlugin
                text: "Place"
                accent: true
                enabled: dashboard.placementValid
                onClicked: dashboard.confirmPluginPlacement()
              }
              DashboardActionButton {
                text: "Cancel"
                onClicked: {
                  if (dashboard.placingDivider) dashboard.cancelDividerPlacement()
                  else dashboard.cancelPluginPlacement()
                }
              }
            }
          }

          Item {
            id: gridCanvas
            objectName: "gridCanvas"
            readonly property var fittedBounds: GridEngine.centeredBounds(
              canvasArea.width, canvasArea.height,
              dashboard.dashboardState.gridSpacing, dashboard.dashboardState.spaces)
            width: fittedBounds.width
            height: fittedBounds.height
            anchors.centerIn: parent
            clip: true

            onWidthChanged: if (root.visible) dashboard.updateGridBounds(width, height)
            onHeightChanged: if (root.visible) dashboard.updateGridBounds(width, height)

            Canvas {
              id: dotGrid
              anchors.fill: parent
              visible: dashboard.mode === "edit"
              opacity: 0.34
              property real gridSpacing: dashboard.dashboardState.gridSpacing
              onVisibleChanged: if (visible) requestPaint()
              onGridSpacingChanged: requestPaint()
              onWidthChanged: requestPaint()
              onHeightChanged: requestPaint()
              onPaint: {
                var context = getContext("2d")
                context.reset()
                context.fillStyle = Color.popups.text
                var spacing = Math.max(5, gridSpacing)
                var radius = 0.8

                function axisPoints(limit) {
                  var points = []
                  for (var value = 0; value <= limit; value += spacing) points.push(value)
                  if (points.length === 0 || points[points.length - 1] !== limit) points.push(limit)
                  return points
                }

                var columns = axisPoints(width)
                var rows = axisPoints(height)
                for (var row = 0; row < rows.length; row++)
                  for (var column = 0; column < columns.length; column++) {
                    var x = columns[column] === 0 ? radius
                      : (columns[column] === width ? width - radius : columns[column])
                    var y = rows[row] === 0 ? radius
                      : (rows[row] === height ? height - radius : rows[row])
                    context.beginPath()
                    context.arc(x, y, radius, 0, Math.PI * 2)
                    context.fill()
                  }
              }
            }

            Repeater {
              id: tileRepeater
              model: dashboard.activeTiles
              delegate: TileHost {
                required property var modelData
                dashboard: root.dashboard
                tile: modelData
                canvas: gridCanvas
                gridWidth: gridCanvas.width
                gridHeight: gridCanvas.height
                surfaceActive: root.visible
              }
            }

            Repeater {
              id: graphicElementRepeater
              model: dashboard.activeElements
              delegate: DashboardGraphicElement {
                required property var modelData
                dashboard: root.dashboard
                element: modelData
                canvas: gridCanvas
                gridWidth: gridCanvas.width
                gridHeight: gridCanvas.height
                onEditTextRequested: function(elementId, text) {
                  root.beginTextEdit(elementId, text)
                }
              }
            }

            Item {
              id: dividerDraft
              anchors.fill: parent
              visible: dashboard.placingDivider && dashboard.dividerDraft.started
              z: 54
              readonly property var draft: dashboard.dividerDraft || ({ x1: 0, y1: 0, x2: 0, y2: 0 })
              readonly property bool horizontal: draft.y1 === draft.y2

              Rectangle {
                x: dividerDraft.horizontal
                  ? Math.min(dividerDraft.draft.x1, dividerDraft.draft.x2)
                  : dividerDraft.draft.x1 - width / 2
                y: dividerDraft.horizontal
                  ? dividerDraft.draft.y1 - height / 2
                  : Math.min(dividerDraft.draft.y1, dividerDraft.draft.y2)
                width: dividerDraft.horizontal
                  ? Math.abs(dividerDraft.draft.x2 - dividerDraft.draft.x1)
                  : Math.max(2, Style.space(2))
                height: dividerDraft.horizontal
                  ? Math.max(2, Style.space(2))
                  : Math.abs(dividerDraft.draft.y2 - dividerDraft.draft.y1)
                radius: Math.min(width, height) / 2
                color: Color.accent
              }
            }

            MouseArea {
              id: dividerDrawArea
              anchors.fill: parent
              enabled: dashboard.placingDivider
              visible: enabled
              z: 55
              cursorShape: Qt.CrossCursor
              preventStealing: true

              function gridPoint(mouse) {
                var step = dashboard.dashboardState.gridSpacing
                return {
                  x: Math.max(0, Math.min(width, GridEngine.snap(mouse.x, step))),
                  y: Math.max(0, Math.min(height, GridEngine.snap(mouse.y, step)))
                }
              }

              onPressed: function(mouse) {
                var point = gridPoint(mouse)
                dashboard.updateDividerDraft(point.x, point.y, point.x, point.y, true)
              }
              onPositionChanged: function(mouse) {
                if (!pressed || !dashboard.dividerDraft) return
                var point = gridPoint(mouse)
                var draft = dashboard.dividerDraft
                if (Math.abs(point.x - draft.x1) >= Math.abs(point.y - draft.y1))
                  dashboard.updateDividerDraft(draft.x1, draft.y1, point.x, draft.y1, true)
                else dashboard.updateDividerDraft(draft.x1, draft.y1, draft.x1, point.y, true)
              }
              onReleased: {
                if (!dashboard.confirmDividerPlacement()) dashboard.cancelDividerPlacement()
                keyCatcher.forceActiveFocus()
              }
              onCanceled: dashboard.cancelDividerPlacement()
            }

            PlacementGhost {
              dashboard: root.dashboard
              canvas: gridCanvas
            }

            Row {
              id: gridStepControls
              anchors.right: parent.right
              anchors.bottom: parent.bottom
              visible: dashboard.mode === "edit"
              spacing: Style.spacing.xs
              z: 10

              Text {
                anchors.verticalCenter: parent.verticalCenter
                text: "Grid step"
                color: Color.popups.text
                opacity: 0.72
                font.family: Style.font.family
                font.pixelSize: Style.font.caption
              }
              DashboardActionButton {
                icon: "\uf068"
                text: "Denser grid"
                enabled: dashboard.dashboardState.gridSpacing > 5
                onClicked: dashboard.adjustGridSpacing(-5)
              }
              Rectangle {
                width: Style.space(58)
                height: Style.space(28)
                radius: Style.cornerRadius > 0 ? height / 2 : 0
                color: Qt.rgba(Color.popups.text.r, Color.popups.text.g, Color.popups.text.b, 0.06)
                Text {
                  anchors.centerIn: parent
                  text: dashboard.dashboardState.gridSpacing + " px"
                  color: Color.popups.text
                  font.family: Style.font.family
                  font.pixelSize: Style.font.caption
                }
              }
              DashboardActionButton {
                icon: "\uf067"
                text: "Wider grid"
                enabled: dashboard.dashboardState.gridSpacing < 80
                onClicked: dashboard.adjustGridSpacing(5)
              }
            }

            Column {
              anchors.centerIn: parent
              visible: dashboard.activeTiles.length === 0
                && dashboard.activeElements.length === 0
                && !dashboard.placingPlugin && !dashboard.placingDivider
              spacing: Style.spacing.md
              Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: "󰕮"
                color: Color.popups.text
                opacity: 0.25
                font.family: Style.font.family
                font.pixelSize: Style.space(64)
              }
              Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: "This Space is empty"
                color: Color.popups.text
                font.family: Style.font.family
                font.pixelSize: Style.font.subtitle
              }
              DashboardActionButton {
                anchors.horizontalCenter: parent.horizontalCenter
                visible: dashboard.mode === "edit"
                icon: "\uf067"
                text: "Add Plugin"
                onClicked: dashboard.overlay = "catalog"
              }
              Row {
                anchors.horizontalCenter: parent.horizontalCenter
                visible: dashboard.mode === "edit"
                spacing: Style.spacing.sm
                DashboardActionButton {
                  text: "Divider"
                  onClicked: dashboard.beginDividerPlacement()
                }
                DashboardActionButton {
                  text: "Text"
                  onClicked: root.beginNewText()
                }
              }
            }
          }
        }
      }
    }

    DashboardConfirmationDialog {
      anchors.fill: parent
      visible: dashboard.overlay === "remove-space"
      z: 20
      title: "Remove Space?"
      message: "Remove “" + root.spaceName(root.pendingRemovalSpaceId)
        + "” and all of its plugins? This cannot be undone."
      confirmText: "Remove"
      onAccepted: root.confirmSpaceRemoval()
      onRejected: root.cancelSpaceRemoval()
    }

    DashboardTextEditor {
      anchors.fill: parent
      visible: dashboard.overlay === "text-editor"
      z: 24
      value: root.textEditorValue
      title: root.textEditorElementId ? "Edit text" : "Add text"
      acceptText: root.textEditorElementId ? "Save" : "Add"
      onAccepted: function(value) { root.finishTextEditor(value) }
      onRejected: root.cancelTextEditor()
    }

    PluginCatalog {
      anchors.fill: parent
      visible: dashboard.overlay === "catalog"
      z: 20
      plugins: dashboard.plugins.availablePlugins
      onCloseRequested: {
        dashboard.overlay = ""
        keyCatcher.forceActiveFocus()
      }
      onPluginRequested: function(pluginId) {
        dashboard.beginPluginPlacement(pluginId)
        keyCatcher.forceActiveFocus()
      }
    }

    ShortcutsOverlay {
      anchors.fill: parent
      visible: dashboard.overlay === "help"
      z: 25
      onCloseRequested: {
        dashboard.overlay = ""
        keyCatcher.forceActiveFocus()
      }
    }

    DashboardPopout {
      anchors.fill: parent
      visible: dashboard.overlay === "plugin"
      z: 30
      dashboard: root.dashboard
      tile: dashboard.popoutTile
      onCloseRequested: {
        dashboard.closePluginPopout()
        keyCatcher.forceActiveFocus()
      }
    }

  }

  Component.onCompleted: if (visible) dashboard.updateGridBounds(gridCanvas.width, gridCanvas.height)
}
