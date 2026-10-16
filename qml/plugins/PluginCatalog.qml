pragma ComponentBehavior: Bound

import QtQuick
import "../system"
import "../ui" as Ui

Item {
  id: root

  HostChrome { id: hostChrome }

  property var plugins: []
  property string filterText: ""
  signal closeRequested()
  signal pluginRequested(string pluginId)

  function activateCurrent() {
    if (filteredPlugins.length === 0) return
    var index = Math.max(0, Math.min(pluginList.currentIndex, filteredPlugins.length - 1))
    pluginRequested(filteredPlugins[index].id)
  }

  function moveCurrent(delta) {
    if (filteredPlugins.length === 0) return
    var current = pluginList.currentIndex < 0 ? 0 : pluginList.currentIndex
    pluginList.currentIndex = (current + delta + filteredPlugins.length) % filteredPlugins.length
    pluginList.positionViewAtIndex(pluginList.currentIndex, ListView.Contain)
  }

  readonly property var filteredPlugins: {
    var query = filterText.toLowerCase().trim()
    if (!query) return plugins
    return plugins.filter(function(plugin) {
      return String(plugin.name || "").toLowerCase().indexOf(query) >= 0
        || String(plugin.id || "").toLowerCase().indexOf(query) >= 0
        || String(plugin.description || "").toLowerCase().indexOf(query) >= 0
    })
  }

  Rectangle {
    anchors.fill: parent
    color: Qt.rgba(hostChrome.background.r, hostChrome.background.g, hostChrome.background.b, 0.78)
  }
  MouseArea { anchors.fill: parent; onClicked: root.closeRequested() }

  Rectangle {
    anchors.centerIn: parent
    width: Math.min(parent.width - hostChrome.space(48), hostChrome.space(680))
    height: Math.min(parent.height - hostChrome.space(48), hostChrome.space(720))
    radius: hostChrome.cornerRadius
    color: hostChrome.popupBackground
    border.width: hostChrome.borderWidth
    border.color: hostChrome.popupBorder
    MouseArea { anchors.fill: parent; onClicked: {} }

    Column {
      anchors.fill: parent
      anchors.margins: hostChrome.spaceLg
      spacing: hostChrome.spaceMd

      Item {
        width: parent.width
        height: hostChrome.space(34)
        Text {
          textFormat: Text.PlainText
          anchors.left: parent.left
          anchors.verticalCenter: parent.verticalCenter
          text: "Add Plugin"
          color: hostChrome.popupText
          font.family: hostChrome.fontFamily
          font.pixelSize: hostChrome.fontTitle
          font.bold: true
        }
        Ui.DashboardActionButton {
          anchors.right: parent.right
          anchors.verticalCenter: parent.verticalCenter
          icon: "\uf00d"
          text: "Close"
          onClicked: root.closeRequested()
        }
      }

      Rectangle {
        width: parent.width
        height: hostChrome.space(42)
        radius: hostChrome.cornerRadius
        color: Qt.rgba(hostChrome.popupText.r, hostChrome.popupText.g, hostChrome.popupText.b, 0.06)
        border.width: 1
        border.color: filterInput.activeFocus ? hostChrome.accent : hostChrome.popupBorder
        TextInput {
          id: filterInput
          anchors.fill: parent
          anchors.margins: hostChrome.spaceSm
          color: hostChrome.popupText
          selectionColor: hostChrome.accent
          font.family: hostChrome.fontFamily
          font.pixelSize: hostChrome.fontBody
          maximumLength: 160
          focus: root.visible
          onTextChanged: root.filterText = text
          Keys.onEscapePressed: root.closeRequested()
          Keys.onDownPressed: root.moveCurrent(1)
          Keys.onUpPressed: root.moveCurrent(-1)
          Keys.onReturnPressed: root.activateCurrent()
          Keys.onEnterPressed: root.activateCurrent()
        }
        Text {
          textFormat: Text.PlainText
          anchors.left: parent.left
          anchors.leftMargin: hostChrome.spaceSm
          anchors.verticalCenter: parent.verticalCenter
          visible: filterInput.text.length === 0
          text: "Search installed plugins…"
          color: hostChrome.popupText
          opacity: 0.4
          font.family: hostChrome.fontFamily
          font.pixelSize: hostChrome.fontBody
        }
      }

      ListView {
        id: pluginList
        width: parent.width
        height: parent.height - hostChrome.space(34) - hostChrome.space(42) - parent.spacing * 2
        clip: true
        spacing: hostChrome.spaceSm
        model: root.filteredPlugins
        currentIndex: count > 0 ? 0 : -1
        highlightMoveDuration: 80
        highlight: Rectangle {
          radius: hostChrome.cornerRadius
          color: Qt.rgba(hostChrome.accent.r, hostChrome.accent.g, hostChrome.accent.b, 0.16)
          border.width: 1
          border.color: hostChrome.accent
        }
        delegate: Rectangle {
          id: pluginRow
          required property var modelData
          required property int index
          width: ListView.view.width
          height: hostChrome.space(76)
          radius: hostChrome.cornerRadius
          color: rowMouse.containsMouse || ListView.isCurrentItem
            ? hostChrome.hoverFill(hostChrome.popupText, hostChrome.accent)
            : Qt.rgba(hostChrome.popupText.r, hostChrome.popupText.g, hostChrome.popupText.b, 0.035)
          border.width: 1
          border.color: Qt.rgba(hostChrome.popupText.r, hostChrome.popupText.g, hostChrome.popupText.b, 0.1)

          Column {
            anchors.left: parent.left
            anchors.right: addButton.left
            anchors.verticalCenter: parent.verticalCenter
            anchors.leftMargin: hostChrome.spaceMd
            anchors.rightMargin: hostChrome.spaceMd
            spacing: hostChrome.spaceXs
            Text {
              textFormat: Text.PlainText
              width: parent.width
              text: pluginRow.modelData.name
              color: hostChrome.popupText
              font.family: hostChrome.fontFamily
              font.pixelSize: hostChrome.fontBody
              font.bold: true
              elide: Text.ElideRight
            }
            Text {
              textFormat: Text.PlainText
              width: parent.width
              text: pluginRow.modelData.description || pluginRow.modelData.id
              color: hostChrome.popupText
              opacity: 0.58
              font.family: hostChrome.fontFamily
              font.pixelSize: hostChrome.fontCaption
              elide: Text.ElideRight
            }
            Text {
              textFormat: Text.PlainText
              width: parent.width
              text: pluginRow.modelData.pending
                ? "Pending placement · " + pluginRow.modelData.compatibility
                : pluginRow.modelData.compatibility
              color: hostChrome.accent
              font.family: hostChrome.fontFamily
              font.pixelSize: hostChrome.fontCaption
              elide: Text.ElideRight
            }
          }

          Ui.DashboardActionButton {
            id: addButton
            anchors.right: parent.right
            anchors.rightMargin: hostChrome.spaceMd
            anchors.verticalCenter: parent.verticalCenter
            icon: "\uf067"
            text: pluginRow.modelData.pending ? "Place" : "Add"
            accent: true
            onClicked: root.pluginRequested(pluginRow.modelData.id)
          }
          MouseArea {
            id: rowMouse
            anchors.fill: parent
            anchors.rightMargin: addButton.width + hostChrome.spaceLg
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onDoubleClicked: root.pluginRequested(pluginRow.modelData.id)
            onClicked: pluginList.currentIndex = pluginRow.index
          }
        }

        Text {
          textFormat: Text.PlainText
          anchors.centerIn: parent
          visible: parent.count === 0
          text: root.plugins.length === 0 ? "No plugins are installed" : "No matching plugins"
          color: hostChrome.popupText
          opacity: 0.55
          font.family: hostChrome.fontFamily
          font.pixelSize: hostChrome.fontBody
        }
      }
    }
  }

  onVisibleChanged: if (visible) {
    filterText = ""
    pluginList.currentIndex = filteredPlugins.length > 0 ? 0 : -1
    Qt.callLater(function() { filterInput.forceActiveFocus() })
  }
  onFilteredPluginsChanged: pluginList.currentIndex = filteredPlugins.length > 0 ? 0 : -1
}
