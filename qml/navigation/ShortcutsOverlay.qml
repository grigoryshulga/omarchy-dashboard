pragma ComponentBehavior: Bound

import QtQuick
import qs.Commons
import "../ui" as Ui

Item {
  id: root

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
    { key: "Placement", action: "Arrows or H J K L move; Shift resizes; Enter places; Esc cancels" },
    { key: "Alt+C / Alt+R", action: "Create or rename a Space" },
    { key: "Alt+X", action: "Remove a Space (confirmation required)" },
    { key: "Delete", action: "Remove the selected tile or graphic element" },
    { key: "?", action: "Show or hide this guide" }
  ]

  Rectangle {
    anchors.fill: parent
    color: Qt.rgba(Color.background.r, Color.background.g, Color.background.b, 0.78)
  }
  MouseArea { anchors.fill: parent; onClicked: root.closeRequested() }

  Rectangle {
    anchors.centerIn: parent
    width: Math.min(parent.width - Style.space(48), Style.space(620))
    height: Math.min(parent.height - Style.space(48), shortcutsColumn.implicitHeight + Style.spacing.lg * 2)
    radius: Style.cornerRadius
    color: Color.popups.background
    border.width: 1
    border.color: Color.popups.border
    MouseArea { anchors.fill: parent; onClicked: {} }

    Column {
      id: shortcutsColumn
      anchors.left: parent.left
      anchors.right: parent.right
      anchors.top: parent.top
      anchors.margins: Style.spacing.lg
      spacing: Style.spacing.sm

      Item {
        width: parent.width
        height: Style.space(34)
        Text {
          textFormat: Text.PlainText
          anchors.left: parent.left
          anchors.verticalCenter: parent.verticalCenter
          text: "Keyboard shortcuts"
          color: Color.popups.text
          font.family: Style.font.family
          font.pixelSize: Style.font.title
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
          height: Math.max(Style.space(30), actionText.implicitHeight + Style.spacing.xs * 2)
          Rectangle {
            anchors.left: parent.left
            anchors.top: parent.top
            anchors.topMargin: Style.spacing.xs
            width: Style.space(180)
            height: Math.max(Style.space(25), parent.height - Style.spacing.xs * 2)
            radius: Style.cornerRadius
            color: Qt.rgba(Color.popups.text.r, Color.popups.text.g, Color.popups.text.b, 0.07)
            Text {
              textFormat: Text.PlainText
              anchors.centerIn: parent
              text: modelData.key
              color: Color.accent
              font.family: Style.font.family
              font.pixelSize: Style.font.caption
              elide: Text.ElideRight
            }
          }
          Text {
            textFormat: Text.PlainText
            id: actionText
            anchors.left: parent.left
            anchors.leftMargin: Style.space(196)
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            text: modelData.action
            color: Color.popups.text
            font.family: Style.font.family
            font.pixelSize: Style.font.bodySmall
            wrapMode: Text.WordWrap
          }
        }
      }
    }
  }
}
