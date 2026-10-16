pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls as Controls
import "../system"
import "../state/DashboardModel.js" as DashboardModel

Row {
  id: root

  HostChrome { id: hostChrome }

  property var element: null
  readonly property bool textSelected: element !== null && element.kind === "text"
  readonly property bool dividerSelected: element !== null && element.kind === "divider"
  signal alignmentRequested(string alignment)
  signal thicknessRequested(int thickness)

  spacing: hostChrome.spaceSm

  Text {
    textFormat: Text.PlainText
    anchors.verticalCenter: parent.verticalCenter
    visible: root.textSelected || root.dividerSelected
    text: root.textSelected ? "Align" : "Thickness"
    color: hostChrome.popupText
    opacity: 0.62
    font.family: hostChrome.fontFamily
    font.pixelSize: hostChrome.fontCaption
  }

  Row {
    objectName: "textAlignmentControls"
    visible: root.textSelected
    spacing: hostChrome.spaceXs
    Repeater {
      model: [
        { alignment: "left", icon: "\uf036", label: "Align left" },
        { alignment: "center", icon: "\uf037", label: "Align center" },
        { alignment: "right", icon: "\uf038", label: "Align right" }
      ]
      delegate: Rectangle {
        id: button
        required property var modelData
        readonly property bool checked: root.textSelected
          && DashboardModel.normalizeTextAlignment(root.element.alignment) === modelData.alignment
        objectName: "align-" + modelData.alignment
        width: hostChrome.space(28)
        height: width
        radius: hostChrome.cornerRadius
        color: checked ? hostChrome.selectedFill(hostChrome.popupText, hostChrome.accent)
          : (mouse.containsMouse ? hostChrome.hoverFill(hostChrome.popupText, hostChrome.accent)
            : Qt.rgba(hostChrome.popupText.r, hostChrome.popupText.g, hostChrome.popupText.b, 0.06))
        Accessible.role: Accessible.RadioButton
        Accessible.name: modelData.label
        Accessible.checked: checked
        Accessible.onPressAction: if (enabled) root.alignmentRequested(modelData.alignment)

        Text {
          textFormat: Text.PlainText
          anchors.centerIn: parent
          text: button.modelData.icon
          color: hostChrome.popupText
          font.family: hostChrome.fontFamily
          font.pixelSize: hostChrome.fontBodySmall
        }
        MouseArea {
          id: mouse
          anchors.fill: parent
          hoverEnabled: true
          cursorShape: Qt.PointingHandCursor
          onClicked: root.alignmentRequested(button.modelData.alignment)
        }
        Controls.ToolTip {
          id: tooltip
          visible: button.visible && mouse.containsMouse
          delay: 400
          text: button.modelData.label
          padding: hostChrome.spaceSm
          contentItem: Text {
            textFormat: Text.PlainText
            text: tooltip.text
            color: hostChrome.popupText
            font.family: hostChrome.fontFamily
            font.pixelSize: hostChrome.fontCaption
          }
          background: Rectangle {
            radius: hostChrome.cornerRadius
            color: hostChrome.popupBackground
            border.width: 1
            border.color: hostChrome.accent
          }
        }
      }
    }
  }

  Controls.Slider {
    id: thicknessSlider
    objectName: "dividerThicknessSlider"
    visible: root.dividerSelected
    width: hostChrome.space(120)
    height: hostChrome.space(28)
    from: DashboardModel.MIN_DIVIDER_THICKNESS
    to: DashboardModel.MAX_DIVIDER_THICKNESS
    stepSize: 1
    snapMode: Controls.Slider.SnapAlways
    value: root.dividerSelected ? DashboardModel.normalizeDividerThickness(root.element.thickness) : 2
    Accessible.name: "Divider thickness"
    // Only user input writes state. Selecting a different element simply
    // updates the binding, without changing that element's saved thickness.
    onMoved: root.thicknessRequested(Math.round(value))
    background: Rectangle {
      x: thicknessSlider.leftPadding
      y: (thicknessSlider.height - height) / 2
      width: thicknessSlider.availableWidth
      height: hostChrome.space(4)
      radius: height / 2
      color: Qt.rgba(hostChrome.popupText.r, hostChrome.popupText.g, hostChrome.popupText.b, 0.18)
      Rectangle {
        width: thicknessSlider.visualPosition * parent.width
        height: parent.height
        radius: parent.radius
        color: hostChrome.accent
      }
    }
    handle: Rectangle {
      x: thicknessSlider.leftPadding + thicknessSlider.visualPosition * (thicknessSlider.availableWidth - width)
      y: (thicknessSlider.height - height) / 2
      width: hostChrome.space(14)
      height: width
      radius: width / 2
      color: hostChrome.popupText
      border.width: thicknessSlider.activeFocus || thicknessSlider.pressed ? 2 : 1
      border.color: hostChrome.accent
    }
  }

  Text {
    textFormat: Text.PlainText
    objectName: "dividerThicknessValue"
    anchors.verticalCenter: parent.verticalCenter
    visible: root.dividerSelected
    width: hostChrome.space(34)
    text: Math.round(thicknessSlider.value) + " px"
    color: hostChrome.popupText
    font.family: hostChrome.fontFamily
    font.pixelSize: hostChrome.fontCaption
  }
}
