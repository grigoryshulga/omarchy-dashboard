pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls as Controls
import qs.Commons

Item {
  id: root

  property bool adding: false
  property bool canAdd: true
  property bool dimContent: true
  property string title: ""
  property string detail: ""
  property string presentationLabel: "Auto"
  property real edgeInset: Style.space(12)
  signal removeRequested()
  signal presentationRequested()
  signal addRequested()

  readonly property int actionCount: adding ? 3 : 2
  readonly property real availableWidth: Math.max(0, width - edgeInset * 2)
  readonly property real actionGap: Math.min(Style.space(6), availableWidth / (actionCount * 2))
  readonly property real actionWidth: Math.min(Style.space(32),
    Math.max(0, (availableWidth - actionGap * (actionCount - 1)) / actionCount))

  Rectangle {
    objectName: "editScrim"
    anchors.fill: parent
    visible: root.dimContent
    radius: Style.cornerRadius
    color: Qt.rgba(0, 0, 0, 0.32)
  }

  Text {
    textFormat: Text.PlainText
    anchors.bottom: actions.top
    anchors.bottomMargin: Style.spacing.sm
    anchors.horizontalCenter: parent.horizontalCenter
    width: root.availableWidth
    visible: root.title !== "" && root.height >= Style.space(110)
    text: root.title
    color: Color.popups.text
    font.family: Style.font.family
    font.pixelSize: Style.font.body
    font.bold: true
    horizontalAlignment: Text.AlignHCenter
    elide: Text.ElideRight
  }

  component Action: Rectangle {
    id: action
    required property string icon
    required property string label
    property bool primary: false
    property bool destructive: false
    signal clicked()
    width: root.actionWidth
    height: Math.min(Style.space(32), Math.max(0, root.height - root.edgeInset * 2))
    radius: Style.cornerRadius
    clip: true
    opacity: enabled ? 1 : 0.4
    color: primary ? Color.accent : Color.popups.background
    border.width: 1
    border.color: mouse.containsMouse ? Color.accent
      : Qt.rgba(Color.popups.text.r, Color.popups.text.g, Color.popups.text.b, 0.18)
    Accessible.role: Accessible.Button
    Accessible.name: label
    Accessible.onPressAction: if (enabled) clicked()

    Text {
      textFormat: Text.PlainText
      anchors.centerIn: parent
      text: action.icon
      color: action.primary ? Color.background
        : (action.destructive ? Qt.rgba(0.95, 0.45, 0.48, 1) : Color.popups.text)
      font.family: Style.font.family
      font.pixelSize: Style.font.bodySmall
    }

    Controls.ToolTip {
      id: tooltip
      objectName: "editActionTooltip"
      visible: root.visible && mouse.containsMouse
      delay: 400
      text: action.label
      padding: Style.spacing.sm
      contentItem: Text {
        textFormat: Text.PlainText
        text: tooltip.text
        color: Color.popups.text
        font.family: Style.font.family
        font.pixelSize: Style.font.caption
      }
      background: Rectangle {
        radius: Style.cornerRadius
        color: Color.popups.background
        border.width: 1
        border.color: Color.accent
      }
    }

    MouseArea {
      id: mouse
      anchors.fill: parent
      hoverEnabled: true
      cursorShape: Qt.PointingHandCursor
      onClicked: action.clicked()
    }
  }

  Row {
    id: actions
    objectName: "tileEditActions"
    anchors.centerIn: parent
    spacing: root.actionGap
    Action {
      objectName: "deleteTileButton"
      icon: "\uf1f8"
      label: "Delete · Del"
      destructive: true
      onClicked: root.removeRequested()
    }
    Action {
      objectName: "tilePresentationButton"
      icon: "⇄"
      label: "Change display mode · " + root.presentationLabel
      Accessible.description: "Change display mode"
      onClicked: root.presentationRequested()
    }
    Action {
      objectName: "addTileButton"
      visible: root.adding
      enabled: root.canAdd
      icon: "+"
      label: "Add · Enter"
      primary: true
      onClicked: root.addRequested()
    }
  }

  Text {
    textFormat: Text.PlainText
    anchors.top: actions.bottom
    anchors.topMargin: Style.spacing.sm
    anchors.horizontalCenter: parent.horizontalCenter
    width: root.availableWidth
    visible: root.height >= Style.space(90)
    text: root.detail
    color: root.canAdd ? Color.popups.text : Qt.rgba(0.95, 0.45, 0.48, 1)
    font.family: Style.font.family
    font.pixelSize: Style.font.caption
    horizontalAlignment: Text.AlignHCenter
    elide: Text.ElideRight
  }
}
