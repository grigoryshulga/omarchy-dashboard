pragma ComponentBehavior: Bound

import QtQuick
import qs.Commons

Item {
  id: root

  required property var dashboard
  property var tile: null
  property var loadedPage: null
  property string pageError: ""
  readonly property var presentation: tile ? dashboard.plugins.presentation(tile) : ({})
  readonly property string sourceUrl: String(presentation.source || "")

  signal closeRequested()

  function initializePage() {
    loadedPage = pageLoader.item
    pageError = ""
    if (!dashboard.plugins.injectInto(loadedPage, tile, popoutHost)) {
      pageError = "The plugin page failed during initialization."
      pageLoader.active = false
      return
    }
    Qt.callLater(function() { dashboard.plugins.focusPage(root.loadedPage) })
  }

  function unloadPage(reason) {
    if (loadedPage) dashboard.plugins.deactivate(loadedPage, reason)
    loadedPage = null
  }

  onVisibleChanged: {
    if (!visible) unloadPage("popout-hidden")
    else if (!sourceUrl && tile) dashboard.plugins.requestAdaptation(tile.pluginId)
  }
  onSourceUrlChanged: pageError = ""
  Component.onDestruction: unloadPage("popout-destroyed")

  QtObject {
    id: popoutHost
    readonly property string mode: "interact"
    readonly property var screen: root.dashboard ? root.dashboard.activeScreenName : null
    function handleEscape() { root.closeRequested() }
    function close() { root.closeRequested() }
    function focusKeyboardPlugin(delta) {
      root.closeRequested()
      root.dashboard.focusKeyboardPlugin(delta)
    }
  }

  Rectangle {
    anchors.fill: parent
    color: Qt.rgba(Color.background.r, Color.background.g, Color.background.b, 0.68)
    MouseArea {
      anchors.fill: parent
      onClicked: root.closeRequested()
    }
  }

  Rectangle {
    id: card
    anchors.centerIn: parent
    width: Math.min(parent.width - Style.gapsOut * 6, Style.space(860))
    height: Math.min(parent.height - Style.gapsOut * 6, Style.space(680))
    radius: Style.cornerRadius
    color: Color.popups.background
    border.width: 1
    border.color: Color.accent

    MouseArea { anchors.fill: parent; onClicked: {} }

    Item {
      anchors.fill: parent
      anchors.margins: root.presentation.contentLayout === "edge-to-edge"
        ? 0 : Style.spacing.panelPadding
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
        visible: root.sourceUrl === "" || pageLoader.status === Loader.Error

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

  }
}
