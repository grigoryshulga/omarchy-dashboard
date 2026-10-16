pragma ComponentBehavior: Bound

import QtQuick
import "../system"
import "../ui" as Ui

Item {
  id: root

  HostChrome { id: hostChrome }

  signal closeRequested()

  readonly property var shortcuts: [
    { key: "Ctrl (hold)", action: "Show plugin shortcuts in visual order" },
    { key: "Ctrl+1 … 9, A … Z", action: "Interact with the labelled plugin" },
    { key: "← ↑ ↓ → / H J K L", action: "Select the nearest plugin in that direction" },
    { key: "Ctrl+Tab", action: "Select the next plugin in visual order" },
    { key: "Enter", action: "Interact with the selected plugin" },
    { key: "Esc", action: "Leave interaction, edit mode, or Dashboard" },
    { key: "Page Up / Down", action: "Switch Space" },
    { key: "Alt+1 … 9", action: "Open Space by number" },
    { key: "Alt++", action: "Open plugin catalog (edit)" },
    { key: "Alt+E", action: "Toggle edit mode" },
    { key: "Alt+arrows / Alt+H J K L", action: "Move the selected tile, text, or divider" },
    { key: "Shift+arrows / Shift+H J K L", action: "Resize the selected tile, text, or divider" },
    { key: "Edit toolbar", action: "Draw a divider or add scalable text" },
    { key: "Placement", action: "Arrows or H J K L move; Shift resizes; Enter adds; Del or Esc discards" },
    { key: "Alt+C / Alt+R", action: "Create or rename a Space" },
    { key: "Alt+X", action: "Remove a Space (confirmation required)" },
    { key: "Delete", action: "Remove the tile, preview or graphic element; keep editing" },
    { key: "?", action: "Show or hide this guide" }
  ]

  Rectangle {
    anchors.fill: parent
    color: Qt.rgba(hostChrome.background.r, hostChrome.background.g, hostChrome.background.b, 0.78)
  }
  MouseArea { anchors.fill: parent; onClicked: root.closeRequested() }

  Rectangle {
    anchors.centerIn: parent
    width: Math.min(parent.width - hostChrome.space(48), hostChrome.space(620))
    height: Math.min(parent.height - hostChrome.space(48), shortcutsColumn.implicitHeight + hostChrome.spaceLg * 2)
    radius: hostChrome.cornerRadius
    color: hostChrome.popupBackground
    border.width: hostChrome.borderWidth
    border.color: hostChrome.popupBorder
    MouseArea { anchors.fill: parent; onClicked: {} }

    Column {
      id: shortcutsColumn
      anchors.left: parent.left
      anchors.right: parent.right
      anchors.top: parent.top
      anchors.margins: hostChrome.spaceLg
      spacing: hostChrome.spaceSm

      Item {
        width: parent.width
        height: hostChrome.space(34)
        Text {
          textFormat: Text.PlainText
          anchors.left: parent.left
          anchors.verticalCenter: parent.verticalCenter
          text: "Keyboard shortcuts"
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

      Repeater {
        model: root.shortcuts
        delegate: Item {
          required property var modelData
          width: shortcutsColumn.width
          height: Math.max(hostChrome.space(30), actionText.implicitHeight + hostChrome.spaceXs * 2)
          Rectangle {
            anchors.left: parent.left
            anchors.top: parent.top
            anchors.topMargin: hostChrome.spaceXs
            width: hostChrome.space(180)
            height: Math.max(hostChrome.space(25), parent.height - hostChrome.spaceXs * 2)
            radius: hostChrome.cornerRadius
            color: Qt.rgba(hostChrome.popupText.r, hostChrome.popupText.g, hostChrome.popupText.b, 0.07)
            Text {
              textFormat: Text.PlainText
              anchors.centerIn: parent
              text: modelData.key
              color: hostChrome.accent
              font.family: hostChrome.fontFamily
              font.pixelSize: hostChrome.fontCaption
              elide: Text.ElideRight
            }
          }
          Text {
            textFormat: Text.PlainText
            id: actionText
            anchors.left: parent.left
            anchors.leftMargin: hostChrome.space(196)
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            text: modelData.action
            color: hostChrome.popupText
            font.family: hostChrome.fontFamily
            font.pixelSize: hostChrome.fontBodySmall
            wrapMode: Text.WordWrap
          }
        }
      }
    }
  }
}
