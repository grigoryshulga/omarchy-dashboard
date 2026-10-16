pragma ComponentBehavior: Bound

import QtQuick
import "../system"

Rectangle {
  id: root

  HostChrome { id: hostChrome }

  property bool valid: true
  property string title: ""
  property string detail: ""

  readonly property color feedbackColor: valid ? hostChrome.accent : Qt.rgba(0.95, 0.25, 0.30, 1)

  radius: hostChrome.cornerRadius
  color: Qt.rgba(feedbackColor.r, feedbackColor.g, feedbackColor.b, 0.18)
  border.width: 2
  border.color: feedbackColor

  Column {
    anchors.centerIn: parent
    width: Math.max(0, parent.width - hostChrome.spaceLg * 2)
    spacing: hostChrome.spaceXs

    Text {
      textFormat: Text.PlainText
      width: parent.width
      visible: root.width >= hostChrome.space(90) && root.height >= hostChrome.space(54)
      text: root.title
      color: root.feedbackColor
      font.family: hostChrome.fontFamily
      font.pixelSize: hostChrome.fontBody
      font.bold: true
      horizontalAlignment: Text.AlignHCenter
      elide: Text.ElideRight
    }
    Text {
      textFormat: Text.PlainText
      width: parent.width
      visible: root.width >= hostChrome.space(90) && root.height >= hostChrome.space(78)
      text: root.detail
      color: root.feedbackColor
      opacity: 0.82
      font.family: hostChrome.fontFamily
      font.pixelSize: hostChrome.fontCaption
      horizontalAlignment: Text.AlignHCenter
      elide: Text.ElideRight
    }
  }
}
