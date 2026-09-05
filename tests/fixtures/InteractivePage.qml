import QtQuick
Item {
  id: root
  property int clicks: 0
  MouseArea {
    anchors.fill: parent
    onClicked: root.clicks += 1
  }
}
