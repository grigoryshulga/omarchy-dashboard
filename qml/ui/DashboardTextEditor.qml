pragma ComponentBehavior: Bound

import QtQuick
import qs.Commons

Item {
  id: root

  property string value: ""
  property string title: "Add text"
  property string acceptText: "Add"

  signal accepted(string value)
  signal rejected()

  onVisibleChanged: if (visible) Qt.callLater(function() {
    input.forceActiveFocus()
    input.selectAll()
  })

  function accept() {
    var text = String(input.text || "").trim()
    if (text) accepted(text)
  }

  Rectangle {
    anchors.fill: parent
    color: Qt.rgba(Color.background.r, Color.background.g, Color.background.b, 0.78)
  }
  MouseArea { anchors.fill: parent; onClicked: root.rejected() }

  Rectangle {
    anchors.centerIn: parent
    width: Math.min(parent.width - Style.space(48), Style.space(520))
    height: Style.space(154)
    radius: Style.cornerRadius
    color: Color.popups.background
    border.width: 1
    border.color: Color.popups.border
    MouseArea { anchors.fill: parent; onClicked: {} }

    Column {
      anchors.fill: parent
      anchors.margins: Style.spacing.lg
      spacing: Style.spacing.md

      Text {
        text: root.title
        color: Color.popups.text
        font.family: Style.font.family
        font.pixelSize: Style.font.title
        font.bold: true
      }

      Rectangle {
        width: parent.width
        height: Style.space(38)
        radius: Style.cornerRadius
        color: Style.normalFillFor(Color.popups.text, Color.accent)
        border.width: 1
        border.color: input.activeFocus ? Color.accent : Color.popups.border

        TextInput {
          id: input
          anchors.fill: parent
          anchors.leftMargin: Style.spacing.md
          anchors.rightMargin: Style.spacing.md
          text: root.value
          color: Color.popups.text
          selectionColor: Color.accent
          verticalAlignment: TextInput.AlignVCenter
          font.family: Style.font.family
          font.pixelSize: Style.font.body
          maximumLength: 240
          onAccepted: root.accept()
          Keys.onEscapePressed: root.rejected()
        }
      }

      Row {
        anchors.right: parent.right
        spacing: Style.spacing.sm
        DashboardActionButton {
          text: "Cancel"
          onClicked: root.rejected()
        }
        DashboardActionButton {
          text: root.acceptText
          accent: true
          enabled: String(input.text || "").trim().length > 0
          onClicked: root.accept()
        }
      }
    }
  }
}
