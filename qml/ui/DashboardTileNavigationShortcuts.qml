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
    property string alternateSequence: ""
    sequence: alternateSequence || (direction === "left" ? "Left"
      : direction === "right" ? "Right"
      : direction === "up" ? "Up" : "Down")
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
  DirectionShortcut { direction: "left"; alternateSequence: "H" }
  DirectionShortcut { direction: "down"; alternateSequence: "J" }
  DirectionShortcut { direction: "up"; alternateSequence: "K" }
  DirectionShortcut { direction: "right"; alternateSequence: "L" }
}
