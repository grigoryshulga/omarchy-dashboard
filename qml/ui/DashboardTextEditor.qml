pragma ComponentBehavior: Bound

import QtQuick
import "../system"
import "../state/DashboardModel.js" as DashboardModel

Item {
  id: root

  HostChrome { id: hostChrome }

  signal accepted(string value)
  signal rejected()

  onVisibleChanged: if (visible) Qt.callLater(function() {
    input.text = "Text"
    input.forceActiveFocus()
    input.selectAll()
  })

  function accept() {
    var text = String(input.text || "").trim()
    if (text) accepted(text)
  }

  Rectangle {
    anchors.fill: parent
    color: Qt.rgba(hostChrome.background.r, hostChrome.background.g, hostChrome.background.b, 0.78)
  }
  MouseArea { anchors.fill: parent; onClicked: root.rejected() }

  Rectangle {
    anchors.centerIn: parent
    width: Math.min(parent.width - hostChrome.space(48), hostChrome.space(520))
    height: hostChrome.space(154)
    radius: hostChrome.cornerRadius
    color: hostChrome.popupBackground
    border.width: hostChrome.borderWidth
    border.color: hostChrome.popupBorder
    MouseArea { anchors.fill: parent; onClicked: {} }

    Column {
      anchors.fill: parent
      anchors.margins: hostChrome.spaceLg
      spacing: hostChrome.spaceMd

      Text {
        textFormat: Text.PlainText
        text: "Add text"
        color: hostChrome.popupText
        font.family: hostChrome.fontFamily
        font.pixelSize: hostChrome.fontTitle
        font.bold: true
      }

      Rectangle {
        width: parent.width
        height: hostChrome.space(38)
        radius: hostChrome.cornerRadius
        color: hostChrome.normalFill(hostChrome.popupText, hostChrome.accent)
        border.width: 1
        border.color: input.activeFocus ? hostChrome.accent : hostChrome.popupBorder

        TextInput {
          id: input
          anchors.fill: parent
          anchors.leftMargin: hostChrome.spaceMd
          anchors.rightMargin: hostChrome.spaceMd
          color: hostChrome.popupText
          selectionColor: hostChrome.accent
          verticalAlignment: TextInput.AlignVCenter
          font.family: hostChrome.fontFamily
          font.pixelSize: hostChrome.fontBody
          maximumLength: DashboardModel.MAX_TEXT_LENGTH
          onAccepted: root.accept()
          Keys.onEscapePressed: root.rejected()
        }
      }

      Row {
        anchors.right: parent.right
        spacing: hostChrome.spaceSm
        DashboardActionButton {
          text: "Cancel"
          onClicked: root.rejected()
        }
        DashboardActionButton {
          text: "Add"
          accent: true
          enabled: String(input.text || "").trim().length > 0
          onClicked: root.accept()
        }
      }
    }
  }
}
