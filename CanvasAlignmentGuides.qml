pragma ComponentBehavior: Bound

import QtQuick
import qs.Commons

Item {
  id: root

  property bool verticalGuideVisible: false
  property bool horizontalGuideVisible: false

  anchors.fill: parent
  visible: verticalGuideVisible || horizontalGuideVisible
  z: 49

  Rectangle {
    x: Math.round((parent.width - width) / 2)
    width: Math.max(1, Style.space(1))
    height: parent.height
    visible: root.verticalGuideVisible
    color: Color.accent
    opacity: 0.58
  }

  Rectangle {
    y: Math.round((parent.height - height) / 2)
    width: parent.width
    height: Math.max(1, Style.space(1))
    visible: root.horizontalGuideVisible
    color: Color.accent
    opacity: 0.58
  }
}
