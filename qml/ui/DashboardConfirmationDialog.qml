pragma ComponentBehavior: Bound

import QtQuick
import "../system"

Item {
  id: root

  HostChrome { id: hostChrome }

  property string title: "Confirm action"
  property string message: ""
  property string confirmText: "Confirm"
  signal accepted()
  signal rejected()

  Rectangle {
    anchors.fill: parent
    color: Qt.rgba(hostChrome.background.r, hostChrome.background.g, hostChrome.background.b, 0.78)
  }
  MouseArea { anchors.fill: parent; onClicked: root.rejected() }

  Rectangle {
    anchors.centerIn: parent
    width: Math.min(parent.width - hostChrome.space(48), hostChrome.space(440))
    height: confirmationContent.implicitHeight + hostChrome.spaceLg * 2
    radius: hostChrome.cornerRadius
    color: hostChrome.popupBackground
    border.width: hostChrome.borderWidth
    border.color: hostChrome.popupBorder
    MouseArea { anchors.fill: parent; onClicked: {} }

    Column {
      id: confirmationContent
      anchors.left: parent.left
      anchors.right: parent.right
      anchors.verticalCenter: parent.verticalCenter
      anchors.margins: hostChrome.spaceLg
      spacing: hostChrome.spaceMd

      Text {
        textFormat: Text.PlainText
        width: parent.width
        text: root.title
        color: hostChrome.popupText
        font.family: hostChrome.fontFamily
        font.pixelSize: hostChrome.fontTitle
        font.bold: true
      }
      Text {
        textFormat: Text.PlainText
        width: parent.width
        text: root.message
        wrapMode: Text.Wrap
        color: hostChrome.popupText
        opacity: 0.76
        font.family: hostChrome.fontFamily
        font.pixelSize: hostChrome.fontBody
      }
      Row {
        anchors.right: parent.right
        spacing: hostChrome.spaceSm

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
