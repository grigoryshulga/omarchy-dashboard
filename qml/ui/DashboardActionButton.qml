import QtQuick
import "../system"

// Compact expanding pill, matching omarchy-side-panel's chrome language.
Rectangle {
  id: root

  HostChrome { id: hostChrome }

  property string icon: ""
  property string text: ""
  property bool accent: false
  property bool active: false
  property bool expandOnHover: true
  property bool alwaysExpanded: false
  property color foreground: hostChrome.popupText
  signal clicked()

  readonly property bool hasIcon: icon.length > 0
  readonly property bool expanded: hasIcon && text.length > 0
    && (alwaysExpanded || (expandOnHover && mouse.containsMouse))
  readonly property real compactWidth: hostChrome.space(28)
  readonly property real expandedWidth: content.implicitWidth + hostChrome.space(20)

  width: hasIcon ? (expanded ? Math.max(compactWidth, expandedWidth) : compactWidth)
    : Math.max(hostChrome.space(34), labelOnly.implicitWidth + hostChrome.spaceMd * 2)
  height: hostChrome.space(28)
  radius: hostChrome.cornerRadius > 0 ? height / 2 : 0
  clip: true
  opacity: enabled ? 1 : 0.42
  color: accent ? hostChrome.accent
    : (active ? hostChrome.selectedFill(foreground, hostChrome.accent)
      : (mouse.containsMouse ? hostChrome.hoverFill(foreground, hostChrome.accent)
        : Qt.rgba(foreground.r, foreground.g, foreground.b, 0.06)))

  Behavior on width { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }

  Row {
    id: content
    anchors.centerIn: parent
    spacing: hostChrome.space(5)
    visible: root.hasIcon
    Text {
      textFormat: Text.PlainText
      text: root.icon
      color: root.accent ? hostChrome.background : root.foreground
      font.family: hostChrome.fontFamily
      font.pixelSize: hostChrome.fontCaption
      font.bold: true
    }
    Text {
      textFormat: Text.PlainText
      visible: root.expanded
      text: root.text
      color: root.accent ? hostChrome.background : root.foreground
      font.family: hostChrome.fontFamily
      font.pixelSize: hostChrome.fontCaption
    }
  }

  Text {
    textFormat: Text.PlainText
    id: labelOnly
    anchors.centerIn: parent
    visible: !root.hasIcon
    text: root.text
  color: root.accent ? hostChrome.background : root.foreground
    font.family: hostChrome.fontFamily
    font.pixelSize: hostChrome.fontBodySmall
  }

  MouseArea {
    id: mouse
    anchors.fill: parent
    enabled: root.enabled
    hoverEnabled: true
    cursorShape: root.enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
    onClicked: root.clicked()
  }
}
