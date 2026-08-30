import QtQuick

Item {
  id: root

  required property var dashboard
  property bool active: false

  function activateSpace(index) {
    if (!active || !dashboard || dashboard.overlay !== "") return
    var document = dashboard.dashboardState
    var spaces = document && Array.isArray(document.spaces) ? document.spaces : []
    if (index >= 0 && index < spaces.length) dashboard.selectSpace(spaces[index].id)
  }

  component SpaceShortcut: Shortcut {
    required property int spaceIndex
    sequence: "Alt+" + (spaceIndex + 1)
    context: Qt.WindowShortcut
    enabled: root.active && root.dashboard && root.dashboard.overlay === ""
    autoRepeat: false
    onActivated: root.activateSpace(spaceIndex)
    onActivatedAmbiguously: root.activateSpace(spaceIndex)
  }

  SpaceShortcut { spaceIndex: 0 }
  SpaceShortcut { spaceIndex: 1 }
  SpaceShortcut { spaceIndex: 2 }
  SpaceShortcut { spaceIndex: 3 }
  SpaceShortcut { spaceIndex: 4 }
  SpaceShortcut { spaceIndex: 5 }
  SpaceShortcut { spaceIndex: 6 }
  SpaceShortcut { spaceIndex: 7 }
  SpaceShortcut { spaceIndex: 8 }
}
