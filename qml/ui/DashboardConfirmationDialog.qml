pragma ComponentBehavior: Bound

import QtQuick
import qs.Commons

Item {
  id: root

  property string title: "Confirm action"
  property string message: ""
  property string confirmText: "Confirm"
  signal accepted()
  signal rejected()

  Rectangle {
    anchors.fill: parent
    color: Qt.rgba(Color.background.r, Color.background.g, Color.background.b, 0.78)
  }
  MouseArea { anchors.fill: parent; onClicked: root.rejected() }

  Rectangle {
    anchors.centerIn: parent
    width: Math.min(parent.width - Style.space(48), Style.space(440))
    height: confirmationContent.implicitHeight + Style.spacing.lg * 2
    radius: Style.cornerRadius
    color: Color.popups.background
    border.width: 1
    border.color: Color.popups.border
    MouseArea { anchors.fill: parent; onClicked: {} }

    Column {
      id: confirmationContent
      anchors.left: parent.left
      anchors.right: parent.right
      anchors.verticalCenter: parent.verticalCenter
      anchors.margins: Style.spacing.lg
      spacing: Style.spacing.md

      Text {
        textFormat: Text.PlainText
        width: parent.width
        text: root.title
        color: Color.popups.text
        font.family: Style.font.family
        font.pixelSize: Style.font.title
        font.bold: true
      }
      Text {
        textFormat: Text.PlainText
        width: parent.width
        text: root.message
        wrapMode: Text.Wrap
        color: Color.popups.text
        opacity: 0.76
        font.family: Style.font.family
        font.pixelSize: Style.font.body
      }
      Row {
        anchors.right: parent.right
        spacing: Style.spacing.sm

        DashboardActionButton {
          text: "Cancel"
          onClicked: root.rejected()
        }
        DashboardActionButton {
          icon: "\uf1f8"
          text: root.confirmText
          accent: true
          onClicked: root.accepted()
        }
      }
    }
  }
}
