pragma ComponentBehavior: Bound

import QtQuick
import "../system"

Item {
  id: root

  HostChrome { id: hostChrome }

  property bool verticalGuideVisible: false
  property bool horizontalGuideVisible: false
  property real verticalGuidePosition: width / 2
  property real horizontalGuidePosition: height / 2

  anchors.fill: parent
  visible: verticalGuideVisible || horizontalGuideVisible
  z: 49

  Rectangle {
    x: Math.round(root.verticalGuidePosition - width / 2)
    width: Math.max(1, hostChrome.space(1))
    height: parent.height
    visible: root.verticalGuideVisible
    color: hostChrome.accent
    opacity: 0.58
  }

  Rectangle {
    y: Math.round(root.horizontalGuidePosition - height / 2)
    width: parent.width
    height: Math.max(1, hostChrome.space(1))
    visible: root.horizontalGuideVisible
    color: hostChrome.accent
    opacity: 0.58
  }
}
