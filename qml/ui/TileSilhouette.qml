pragma ComponentBehavior: Bound

import QtQuick
import qs.Commons

Rectangle {
  id: root

  property bool valid: true
  property string title: ""
  property string detail: ""

  readonly property color feedbackColor: valid ? Color.accent : Qt.rgba(0.95, 0.25, 0.30, 1)

  radius: Style.cornerRadius
  color: Qt.rgba(feedbackColor.r, feedbackColor.g, feedbackColor.b, 0.18)
  border.width: 2
  border.color: feedbackColor

  Column {
    anchors.centerIn: parent
    width: Math.max(0, parent.width - Style.spacing.lg * 2)
    spacing: Style.spacing.xs

    Text {
      width: parent.width
      visible: root.width >= Style.space(90) && root.height >= Style.space(54)
      text: root.title
      color: root.feedbackColor
      font.family: Style.font.family
      font.pixelSize: Style.font.body
      font.bold: true
      horizontalAlignment: Text.AlignHCenter
      elide: Text.ElideRight
    }
    Text {
      width: parent.width
      visible: root.width >= Style.space(90) && root.height >= Style.space(78)
      text: root.detail
      color: root.feedbackColor
      opacity: 0.82
      font.family: Style.font.family
      font.pixelSize: Style.font.caption
      horizontalAlignment: Text.AlignHCenter
      elide: Text.ElideRight
    }
  }
}
