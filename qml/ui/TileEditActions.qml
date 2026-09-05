pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls as Controls
import qs.Commons

Item {
  id: root

  property bool adding: false
  property bool canAdd: true
  property bool dimContent: true
  property bool backgroundEnabled: true
  property string shortcut: ""
  property string title: ""
  property string detail: ""
  property string presentationLabel: "Auto"
  property real edgeInset: Style.space(12)
  signal removeRequested()
  signal presentationRequested()
  signal backgroundRequested()
  signal addRequested()

  readonly property bool menuOpen: options.visible
  function closeMenu() { options.close() }

  readonly property real availableWidth: Math.max(0, width - edgeInset * 2)
  readonly property bool compact: availableWidth < Style.space(100) || height < Style.space(86)
  readonly property string modeText: (shortcut ? shortcut + " · " : "") + presentationLabel
  onVisibleChanged: if (!visible) options.close()
  onCompactChanged: options.close()

  Rectangle {
    objectName: "editScrim"
    anchors.fill: parent
    visible: root.dimContent
    radius: Style.cornerRadius
    color: Qt.rgba(0, 0, 0, 0.32)
  }

  component Action: Rectangle {
    id: action
    required property string icon
    required property string label
    property bool primary: false
    property bool destructive: false
    signal clicked()
    width: Style.space(28)
    height: Style.space(28)
    radius: Style.cornerRadius
    clip: true
    opacity: enabled ? 1 : 0.4
    color: primary ? Color.accent : (mouse.containsMouse
      ? Qt.rgba(Color.popups.text.r, Color.popups.text.g, Color.popups.text.b, 0.12) : "transparent")
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

  component Actions: Row {
    objectName: "tileEditActions"
    spacing: Style.space(2)
    Action {
      objectName: "tilePresentationButton"
      icon: "⇄"
      label: "Change display mode · " + root.presentationLabel
      onClicked: root.presentationRequested()
    }
    Action {
      objectName: "tileBackgroundButton"
      visible: !root.adding
      icon: root.backgroundEnabled ? "▣" : "▢"
      label: root.backgroundEnabled ? "Hide tile background" : "Show tile background"
      Accessible.checkable: true
      Accessible.checked: root.backgroundEnabled
      onClicked: root.backgroundRequested()
    }
    Action {
      objectName: "deleteTileButton"
      icon: "\uf1f8"
      label: "Delete · Del"
      destructive: true
      onClicked: { options.close(); root.removeRequested() }
    }
    Action {
      objectName: "addTileButton"
      visible: root.adding
      enabled: root.canAdd
      icon: "+"
      label: "Add · Enter"
      primary: true
      onClicked: { options.close(); root.addRequested() }
    }
  }

  Rectangle {
    id: plate
    anchors.centerIn: parent
    width: root.compact ? Math.min(Style.space(28), Math.max(0, root.width - Style.space(6)))
      : Style.space(100)
    height: root.compact ? Math.min(Style.space(28), Math.max(0, root.height - Style.space(6)))
      : Style.space(36)
    radius: Style.cornerRadius
    color: Color.popups.background

    Loader {
      anchors.centerIn: parent
      active: !root.compact
      sourceComponent: Actions {}
    }
    Action {
      objectName: "tileOptionsButton"
      anchors.fill: parent
      visible: root.compact
      icon: "…"
      label: "Edit plugin · " + root.modeText
      onClicked: options.opened ? options.close() : options.open()
    }
  }

  Text {
    textFormat: Text.PlainText
    objectName: "tileModeLabel"
    anchors.bottom: plate.top
    anchors.bottomMargin: Style.space(4)
    anchors.horizontalCenter: parent.horizontalCenter
    width: Math.min(Math.max(0, root.width - Style.space(6)),
      Math.max(plate.width, implicitWidth + Style.space(12)))
    visible: root.height >= Style.space(64)
    Rectangle {
      anchors.fill: parent
      anchors.margins: -Style.space(2)
      z: -1
      radius: Style.cornerRadius
      color: Color.popups.background
    }
    text: root.modeText
    color: Color.popups.text
    font.family: Style.font.family
    font.pixelSize: Style.font.caption
    horizontalAlignment: Text.AlignHCenter
    elide: Text.ElideRight
  }

  Text {
    textFormat: Text.PlainText
    anchors.bottom: plate.top
    anchors.bottomMargin: Style.space(28)
    anchors.horizontalCenter: parent.horizontalCenter
    width: root.availableWidth
    visible: root.title !== "" && !root.compact && root.height >= Style.space(140)
    text: root.title
    color: Color.popups.text
    font.family: Style.font.family
    font.pixelSize: Style.font.body
    font.bold: true
    horizontalAlignment: Text.AlignHCenter
    elide: Text.ElideRight
  }

  Text {
    textFormat: Text.PlainText
    anchors.top: plate.bottom
    anchors.topMargin: Style.space(4)
    anchors.horizontalCenter: parent.horizontalCenter
    width: root.availableWidth
    visible: !root.compact && root.height >= Style.space(90)
    text: root.detail
    color: root.canAdd ? Color.popups.text : Qt.rgba(0.95, 0.45, 0.48, 1)
    font.family: Style.font.family
    font.pixelSize: Style.font.caption
    horizontalAlignment: Text.AlignHCenter
    elide: Text.ElideRight
  }

  Controls.Popup {
    id: options
    objectName: "tileOptionsPopup"
    x: (root.width - width) / 2
    y: (root.height - height) / 2
    width: Math.max(Style.space(132), popupMode.implicitWidth + padding * 2)
    padding: Style.space(8)
    margins: Style.space(8)
    // Catch clicks around the small tile while the menu is open so that
    // dismissing it cannot start dragging or activate a different tile.
    modal: true
    focus: true
    dim: false
    closePolicy: Controls.Popup.CloseOnEscape | Controls.Popup.CloseOnPressOutside
    contentItem: Column {
      spacing: Style.space(6)
      Text {
        textFormat: Text.PlainText
        id: popupMode
        text: root.modeText
        color: Color.popups.text
        font.family: Style.font.family
        font.pixelSize: Style.font.caption
        anchors.horizontalCenter: parent.horizontalCenter
      }
      Loader {
        anchors.horizontalCenter: parent.horizontalCenter
        active: root.compact
        sourceComponent: Actions {}
      }
    }
    background: Rectangle {
      radius: Style.cornerRadius
      color: Color.popups.background
      border.width: 1
      border.color: Color.accent
    }
  }
}
