pragma ComponentBehavior: Bound

import QtQuick
import qs.Commons

Item {
  id: root

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
    color: Qt.rgba(Color.background.r, Color.background.g, Color.background.b, 0.78)
  }
  MouseArea { anchors.fill: parent; onClicked: root.closeRequested() }

  Rectangle {
    anchors.centerIn: parent
    width: Math.min(parent.width - Style.space(48), Style.space(680))
    height: Math.min(parent.height - Style.space(48), Style.space(720))
    radius: Style.cornerRadius
    color: Color.popups.background
    border.width: 1
    border.color: Color.popups.border
    MouseArea { anchors.fill: parent; onClicked: {} }

    Column {
      anchors.fill: parent
      anchors.margins: Style.spacing.lg
      spacing: Style.spacing.md

      Item {
        width: parent.width
        height: Style.space(34)
        Text {
          anchors.left: parent.left
          anchors.verticalCenter: parent.verticalCenter
          text: "Add Plugin"
          color: Color.popups.text
          font.family: Style.font.family
          font.pixelSize: Style.font.title
          font.bold: true
        }
        DashboardActionButton {
          anchors.right: parent.right
          anchors.verticalCenter: parent.verticalCenter
          icon: "\uf00d"
          text: "Close"
          onClicked: root.closeRequested()
        }
      }

      Rectangle {
        width: parent.width
        height: Style.space(42)
        radius: Style.cornerRadius
        color: Qt.rgba(Color.popups.text.r, Color.popups.text.g, Color.popups.text.b, 0.06)
        border.width: 1
        border.color: filterInput.activeFocus ? Color.accent : Color.popups.border
        TextInput {
          id: filterInput
          anchors.fill: parent
          anchors.margins: Style.spacing.sm
          color: Color.popups.text
          selectionColor: Color.accent
          font.family: Style.font.family
          font.pixelSize: Style.font.body
          focus: root.visible
          onTextChanged: root.filterText = text
          Keys.onEscapePressed: root.closeRequested()
          Keys.onDownPressed: root.moveCurrent(1)
          Keys.onUpPressed: root.moveCurrent(-1)
          Keys.onReturnPressed: root.activateCurrent()
          Keys.onEnterPressed: root.activateCurrent()
        }
        Text {
          anchors.left: parent.left
          anchors.leftMargin: Style.spacing.sm
          anchors.verticalCenter: parent.verticalCenter
          visible: filterInput.text.length === 0
          text: "Search installed plugins…"
          color: Color.popups.text
          opacity: 0.4
          font.family: Style.font.family
          font.pixelSize: Style.font.body
        }
      }

      ListView {
        id: pluginList
        width: parent.width
        height: parent.height - Style.space(34) - Style.space(42) - parent.spacing * 2
        clip: true
        spacing: Style.spacing.sm
        model: root.filteredPlugins
        currentIndex: count > 0 ? 0 : -1
        highlightMoveDuration: 80
        highlight: Rectangle {
          radius: Style.cornerRadius
          color: Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.16)
          border.width: 1
          border.color: Color.accent
        }
        delegate: Rectangle {
          id: pluginRow
          required property var modelData
          required property int index
          width: ListView.view.width
          height: Style.space(76)
          radius: Style.cornerRadius
          color: rowMouse.containsMouse || ListView.isCurrentItem
            ? Style.hoverFillFor(Color.popups.text, Color.accent)
            : Qt.rgba(Color.popups.text.r, Color.popups.text.g, Color.popups.text.b, 0.035)
          border.width: 1
          border.color: Qt.rgba(Color.popups.text.r, Color.popups.text.g, Color.popups.text.b, 0.1)

          Column {
            anchors.left: parent.left
            anchors.right: addButton.left
            anchors.verticalCenter: parent.verticalCenter
            anchors.leftMargin: Style.spacing.md
            anchors.rightMargin: Style.spacing.md
            spacing: Style.spacing.xs
            Text {
              width: parent.width
              text: pluginRow.modelData.name
              color: Color.popups.text
              font.family: Style.font.family
              font.pixelSize: Style.font.body
              font.bold: true
              elide: Text.ElideRight
            }
            Text {
              width: parent.width
              text: pluginRow.modelData.description || pluginRow.modelData.id
              color: Color.popups.text
              opacity: 0.58
              font.family: Style.font.family
              font.pixelSize: Style.font.caption
              elide: Text.ElideRight
            }
            Text {
              width: parent.width
              text: pluginRow.modelData.compatibility
              color: Color.accent
              font.family: Style.font.family
              font.pixelSize: Style.font.caption
              elide: Text.ElideRight
            }
          }

          DashboardActionButton {
            id: addButton
            anchors.right: parent.right
            anchors.rightMargin: Style.spacing.md
            anchors.verticalCenter: parent.verticalCenter
            icon: "\uf067"
            text: "Add"
            accent: true
            onClicked: root.pluginRequested(pluginRow.modelData.id)
          }
          MouseArea {
            id: rowMouse
            anchors.fill: parent
            anchors.rightMargin: addButton.width + Style.spacing.lg
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onDoubleClicked: root.pluginRequested(pluginRow.modelData.id)
            onClicked: pluginList.currentIndex = pluginRow.index
          }
        }

        Text {
          anchors.centerIn: parent
          visible: parent.count === 0
          text: root.plugins.length === 0 ? "No plugins are installed" : "No matching plugins"
          color: Color.popups.text
          opacity: 0.55
          font.family: Style.font.family
          font.pixelSize: Style.font.body
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
