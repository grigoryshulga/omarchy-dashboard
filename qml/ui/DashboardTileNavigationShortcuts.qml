import QtQuick

Item {
  id: root

  required property var dashboard
  property bool active: false

  function navigationEnabled() {
    return active && dashboard && dashboard.mode === "browse" && dashboard.overlay === ""
      && !dashboard.placingPlugin && !dashboard.placingDivider
  }

  function select(direction) {
    if (navigationEnabled()) dashboard.selectTile(direction)
  }

  component DirectionShortcut: Shortcut {
    required property string direction
    sequence: direction === "left" ? "Left"
      : direction === "right" ? "Right"
      : direction === "up" ? "Up" : "Down"
    context: Qt.WindowShortcut
    enabled: root.navigationEnabled()
    autoRepeat: true
    onActivated: root.select(direction)
    onActivatedAmbiguously: root.select(direction)
  }

  DirectionShortcut { direction: "left" }
  DirectionShortcut { direction: "right" }
  DirectionShortcut { direction: "up" }
  DirectionShortcut { direction: "down" }
}
