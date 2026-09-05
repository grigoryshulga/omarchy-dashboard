pragma ComponentBehavior: Bound

import QtQuick
import qs.Commons
import "PopoutGeometry.js" as PopoutGeometry
import "../ui" as Ui

Item {
  id: root

  required property var dashboard
  property var tile: null
  property var loadedPage: null
  property string pageError: ""
  property string sizeError: ""
  property var embeddedSurface: null
  property var resizeDraft: null
  property point resizeStart: Qt.point(0, 0)
  property size resizeStartSize: Qt.size(0, 0)
  readonly property var savedSize: tile ? dashboard.plugins.popoutSize(tile.pluginId) : null
  readonly property var pluginMetadata: {
    var entry = tile ? dashboard.plugins.descriptor(tile.pluginId) : null
    return entry && entry.manifest ? entry.manifest.dashboard || ({}) : ({})
  }
  readonly property real headerHeight: Style.space(40)
  readonly property real contentPadding: presentation.contentLayout === "edge-to-edge"
    ? 0 : Style.spacing.panelPadding
  readonly property var naturalSize: {
    var surface = embeddedSurface
    var page = loadedPage
    return {
      width: surface ? surface.dashboardPreferredWidth : (page ? page.implicitWidth : 0),
      height: surface ? surface.dashboardPreferredHeight : (page ? page.implicitHeight : 0),
      minWidth: surface ? surface.minimumSize.width : 0,
      minHeight: surface ? surface.minimumSize.height : 0
    }
  }
  readonly property var geometry: PopoutGeometry.resolve(pluginMetadata, naturalSize,
    resizeDraft || savedSize, {
      width: Math.max(0, Math.min(width * 0.90, width - Style.space(48))),
      height: Math.max(0, Math.min(height * 0.85, height - Style.space(48)))
    }, { width: contentPadding * 2, height: contentPadding * 2 + headerHeight })
  readonly property var presentation: tile ? dashboard.plugins.presentation(tile) : ({})
  readonly property string sourceUrl: String(presentation.source || "")

  signal closeRequested()

  function initializePage() {
    loadedPage = pageLoader.item
    pageError = ""
    if (!dashboard.plugins.injectInto(loadedPage, tile, popoutHost)) {
      unloadPage("initialization-failed")
      pageError = "The plugin page failed during initialization."
      return
    }
    Qt.callLater(function() { dashboard.plugins.focusPage(root.loadedPage) })
  }

  function unloadPage(reason) {
    var page = loadedPage
    loadedPage = null
    embeddedSurface = null
    if (page) dashboard.plugins.deactivate(page, reason)
  }

  function useAutomaticSize() {
    if (!tile) return
    if (dashboard.plugins.setPopoutSize(tile.pluginId, null)) {
      resizeDraft = null
      sizeError = ""
    } else sizeError = "Could not save size"
  }

  function saveSize() {
    if (!tile || !resizeDraft) return
    sizeError = dashboard.plugins.setPopoutSize(tile.pluginId,
      { width: geometry.width, height: geometry.height }) ? "" : "Could not save size"
  }

  onVisibleChanged: {
    if (!visible) unloadPage("popout-hidden")
    else if (!sourceUrl && tile) dashboard.plugins.requestAdaptation(tile.pluginId)
  }
  onSourceUrlChanged: {
    unloadPage("source-changed")
    pageError = ""
  }
  onTileChanged: { resizeDraft = null; sizeError = ""; pageError = "" }
  Component.onDestruction: unloadPage("popout-destroyed")

  QtObject {
    id: popoutHost
    readonly property string mode: "interact"
    readonly property var screen: root.dashboard ? root.dashboard.activeScreenName : null
    function handleEscape() { root.closeRequested() }
    function close() { root.closeRequested() }
    function registerSurface(surface) { root.embeddedSurface = surface }
    function focusKeyboardPlugin(delta) {
      root.closeRequested()
      root.dashboard.focusKeyboardPlugin(delta)
    }
  }

  Connections {
    target: root.embeddedSurface
    function onVisibleChanged() {
      if (root.visible && root.loadedPage && root.embeddedSurface && !root.embeddedSurface.visible)
        root.closeRequested()
    }
  }

  Rectangle {
    anchors.fill: parent
    color: Qt.rgba(Color.background.r, Color.background.g, Color.background.b, 0.24)
    MouseArea {
      anchors.fill: parent
      onClicked: root.closeRequested()
    }
  }

  Rectangle {
    id: card
    anchors.centerIn: parent
    width: root.geometry.width
    height: root.geometry.height
    radius: Style.cornerRadius
    color: Color.popups.background
    border.width: 1
    border.color: Color.accent

    MouseArea { anchors.fill: parent; onClicked: {} }

    Item {
      id: header
      anchors.left: parent.left
      anchors.right: parent.right
      anchors.top: parent.top
      height: Math.min(root.headerHeight, parent.height)
      clip: true

      Text {
        textFormat: Text.PlainText
        anchors.left: parent.left
        anchors.leftMargin: Style.spacing.md
        anchors.right: headerActions.left
        anchors.rightMargin: Style.spacing.sm
        anchors.verticalCenter: parent.verticalCenter
        text: root.presentation.name || "Plugin"
        color: Color.popups.text
        font.family: Style.font.family
        font.pixelSize: Style.font.body
        elide: Text.ElideRight
      }
      Row {
        id: headerActions
        anchors.right: parent.right
        anchors.rightMargin: Style.spacing.sm
        anchors.verticalCenter: parent.verticalCenter
        spacing: Style.spacing.sm
        Text {
          textFormat: Text.PlainText
          anchors.verticalCenter: parent.verticalCenter
          visible: root.sizeError !== "" || card.width > Style.space(460)
          text: root.sizeError || (Math.round(card.width) + " × " + Math.round(card.height))
          color: root.sizeError ? Color.accent : Color.popups.text
          opacity: 0.6
          font.family: Style.font.family
          font.pixelSize: Style.font.caption
        }
        Ui.DashboardActionButton {
          icon: "󰒠"
          text: "Auto size"
          active: !root.savedSize && !root.resizeDraft
          onClicked: root.useAutomaticSize()
        }
        Ui.DashboardActionButton {
          icon: "\uf00d"
          text: "Close"
          onClicked: root.closeRequested()
        }
      }
    }

    Item {
      anchors.left: parent.left
      anchors.right: parent.right
      anchors.top: header.bottom
      anchors.bottom: parent.bottom
      anchors.margins: root.contentPadding
      clip: true

      Loader {
        id: pageLoader
        anchors.fill: parent
        active: root.visible && root.tile !== null && root.sourceUrl !== "" && root.pageError === ""
        asynchronous: true
        source: active ? root.sourceUrl : ""
        onLoaded: root.initializePage()
        onActiveChanged: if (!active) root.unloadPage("popout-loader-inactive")
        onStatusChanged: if (status === Loader.Error) {
          root.pageError = "The adapted plugin page could not be loaded."
          root.unloadPage("popout-loader-error")
        }
      }

      Column {
        anchors.centerIn: parent
        width: Math.max(0, parent.width - Style.spacing.lg * 2)
        spacing: Style.spacing.md
        visible: root.sourceUrl === "" || root.pageError !== "" || pageLoader.status === Loader.Error

        Text {
          textFormat: Text.PlainText
          anchors.horizontalCenter: parent.horizontalCenter
          text: root.pageError ? "⚠" : "…"
          color: root.pageError ? Color.accent : Color.popups.text
          font.family: Style.font.family
          font.pixelSize: Style.space(32)
        }
        Text {
          textFormat: Text.PlainText
          width: parent.width
          text: root.pageError || root.presentation.reason || "Preparing plugin…"
          color: Color.popups.text
          opacity: 0.7
          font.family: Style.font.family
          font.pixelSize: Style.font.body
          horizontalAlignment: Text.AlignHCenter
          wrapMode: Text.WordWrap
        }
      }
    }

    Rectangle {
      anchors.right: parent.right
      anchors.bottom: parent.bottom
      width: Style.space(24)
      height: width
      radius: Style.cornerRadius
      color: Color.popups.background
      Text {
        textFormat: Text.PlainText
        anchors.centerIn: parent
        text: "◢"
        color: Color.accent
        font.pixelSize: Style.font.caption
      }
      MouseArea {
        objectName: "popoutResizeHandle"
        anchors.fill: parent
        cursorShape: Qt.SizeFDiagCursor
        preventStealing: true
        onPressed: function(mouse) {
          root.resizeStart = mapToItem(root, mouse.x, mouse.y)
          root.resizeStartSize = Qt.size(card.width, card.height)
        }
        onPositionChanged: function(mouse) {
          if (!pressed) return
          var position = mapToItem(root, mouse.x, mouse.y)
          root.resizeDraft = {
            width: Math.max(root.geometry.minWidth, Math.min(root.geometry.maxWidth,
              root.resizeStartSize.width + 2 * (position.x - root.resizeStart.x))),
            height: Math.max(root.geometry.minHeight, Math.min(root.geometry.maxHeight,
              root.resizeStartSize.height + 2 * (position.y - root.resizeStart.y)))
          }
        }
        onReleased: root.saveSize()
        onCanceled: root.resizeDraft = null
      }
    }

  }
}
