import QtQuick

Item {
  id: root

  required property var dashboard
  required property var surface
  property bool active: false

  function available() {
    return active && dashboard && surface && dashboard.overlay === "" && !dashboard.placingDivider
  }

  function move(direction) {
    if (!available() || dashboard.placingPlugin) return
    if (direction === "left" || direction === "right") {
      if (dashboard.mode === "edit" && (dashboard.selectedTileId || dashboard.selectedElementId))
        dashboard.moveSelectedItemByGrid(direction === "left" ? -1 : 1, 0)
      else dashboard.moveSpace(direction === "left" ? -1 : 1)
    } else if (dashboard.mode === "edit") {
      dashboard.moveSelectedItemByGrid(0, direction === "up" ? -1 : 1)
    } else return
    surface.retainKeyboardFocus()
  }

  function resize(direction) {
    if (!available() || dashboard.placingPlugin || dashboard.mode !== "edit") return
    dashboard.resizeSelectedItemByGrid(
      direction === "left" ? -1 : (direction === "right" ? 1 : 0),
      direction === "up" ? -1 : (direction === "down" ? 1 : 0)
    )
    surface.retainKeyboardFocus()
  }

  function place(direction, resizeMode) {
    if (!available() || !dashboard.placingPlugin) return
    dashboard[resizeMode ? "resizePlacementByGrid" : "movePlacementByGrid"](
      direction === "left" ? -1 : (direction === "right" ? 1 : 0),
      direction === "up" ? -1 : (direction === "down" ? 1 : 0)
    )
    surface.retainKeyboardFocus()
  }

  function removeSelected() {
    if (!available() || dashboard.mode !== "edit") return
    if (dashboard.placingPlugin) dashboard.cancelPluginPlacement()
    else if (dashboard.selectedElementId) dashboard.removeElement(dashboard.selectedElementId)
    else if (dashboard.selectedTileId) dashboard.removeTile(dashboard.selectedTileId)
    surface.retainKeyboardFocus()
  }

  function accept() {
    if (!available()) return
    if (dashboard.placingPlugin && dashboard.mode === "edit") {
      if (dashboard.placementValid) dashboard.confirmPluginPlacement()
      surface.retainKeyboardFocus()
    } else if (!dashboard.placingPlugin && dashboard.mode === "browse") surface.enterInteract()
  }

  component DirectionShortcut: Shortcut {
    required property string direction
    required property string modifier
    required property string action
    sequence: modifier + (direction === "left" ? "Left" : direction === "right" ? "Right"
      : direction === "up" ? "Up" : "Down")
    context: Qt.WindowShortcut
    enabled: root.available() && (action === "place" ? root.dashboard.placingPlugin
      : !root.dashboard.placingPlugin)
    autoRepeat: true
    onActivated: {
      if (action === "move") root.move(direction)
      else if (action === "resize") root.resize(direction)
      else root.place(direction, modifier === "Shift+")
    }
    onActivatedAmbiguously: onActivated()
  }

  component LetterShortcut: Shortcut {
    required property string direction
    required property string modifier
    required property string action
    sequence: modifier + (direction === "left" ? "H" : direction === "right" ? "L"
      : direction === "up" ? "K" : "J")
    context: Qt.WindowShortcut
    enabled: root.available() && (action === "place" ? root.dashboard.placingPlugin
      : !root.dashboard.placingPlugin)
    autoRepeat: true
    onActivated: {
      if (action === "move") root.move(direction)
      else if (action === "resize") root.resize(direction)
      else root.place(direction, modifier === "Shift+")
    }
    onActivatedAmbiguously: onActivated()
  }

  DirectionShortcut { direction: "left"; modifier: "Alt+"; action: "move" }
  DirectionShortcut { direction: "right"; modifier: "Alt+"; action: "move" }
  DirectionShortcut { direction: "up"; modifier: "Alt+"; action: "move" }
  DirectionShortcut { direction: "down"; modifier: "Alt+"; action: "move" }
  LetterShortcut { direction: "left"; modifier: "Alt+"; action: "move" }
  LetterShortcut { direction: "right"; modifier: "Alt+"; action: "move" }
  LetterShortcut { direction: "up"; modifier: "Alt+"; action: "move" }
  LetterShortcut { direction: "down"; modifier: "Alt+"; action: "move" }

  DirectionShortcut { direction: "left"; modifier: "Shift+"; action: "resize" }
  DirectionShortcut { direction: "right"; modifier: "Shift+"; action: "resize" }
  DirectionShortcut { direction: "up"; modifier: "Shift+"; action: "resize" }
  DirectionShortcut { direction: "down"; modifier: "Shift+"; action: "resize" }
  LetterShortcut { direction: "left"; modifier: "Shift+"; action: "resize" }
  LetterShortcut { direction: "right"; modifier: "Shift+"; action: "resize" }
  LetterShortcut { direction: "up"; modifier: "Shift+"; action: "resize" }
  LetterShortcut { direction: "down"; modifier: "Shift+"; action: "resize" }

  DirectionShortcut { direction: "left"; modifier: ""; action: "place" }
  DirectionShortcut { direction: "right"; modifier: ""; action: "place" }
  DirectionShortcut { direction: "up"; modifier: ""; action: "place" }
  DirectionShortcut { direction: "down"; modifier: ""; action: "place" }
  LetterShortcut { direction: "left"; modifier: ""; action: "place" }
  LetterShortcut { direction: "right"; modifier: ""; action: "place" }
  LetterShortcut { direction: "up"; modifier: ""; action: "place" }
  LetterShortcut { direction: "down"; modifier: ""; action: "place" }
  DirectionShortcut { direction: "left"; modifier: "Shift+"; action: "place" }
  DirectionShortcut { direction: "right"; modifier: "Shift+"; action: "place" }
  DirectionShortcut { direction: "up"; modifier: "Shift+"; action: "place" }
  DirectionShortcut { direction: "down"; modifier: "Shift+"; action: "place" }
  LetterShortcut { direction: "left"; modifier: "Shift+"; action: "place" }
  LetterShortcut { direction: "right"; modifier: "Shift+"; action: "place" }
  LetterShortcut { direction: "up"; modifier: "Shift+"; action: "place" }
  LetterShortcut { direction: "down"; modifier: "Shift+"; action: "place" }

  Shortcut {
    sequence: "Alt+E"; context: Qt.WindowShortcut; enabled: root.available() && !root.dashboard.placingPlugin
    onActivated: { root.dashboard.toggleEditMode(); root.surface.retainKeyboardFocus() }
  }
  Shortcut {
    sequence: "Alt+V"; context: Qt.WindowShortcut
    enabled: root.available() && !root.dashboard.placingPlugin && root.dashboard.mode === "edit"
    onActivated: { root.dashboard.toggleSurfaceMode(); root.surface.retainKeyboardFocus() }
  }
  Shortcut {
    sequence: "Alt++"; context: Qt.WindowShortcut
    enabled: root.available() && !root.dashboard.placingPlugin && root.dashboard.mode === "edit"
    onActivated: { root.dashboard.overlay = "catalog"; root.surface.retainKeyboardFocus() }
  }
  Shortcut {
    sequence: "Alt+C"; context: Qt.WindowShortcut
    enabled: root.available() && !root.dashboard.placingPlugin && root.dashboard.mode === "edit"
    onActivated: root.surface.beginCreate()
  }
  Shortcut {
    sequence: "Alt+R"; context: Qt.WindowShortcut
    enabled: root.available() && !root.dashboard.placingPlugin && root.dashboard.mode === "edit"
    onActivated: root.surface.beginRename()
  }
  Shortcut {
    sequence: "Alt+X"; context: Qt.WindowShortcut
    enabled: root.available() && !root.dashboard.placingPlugin && root.dashboard.mode === "edit"
    onActivated: root.surface.requestSpaceRemoval(root.dashboard.activeSpace.id)
  }
  Shortcut {
    sequence: "Delete"; context: Qt.WindowShortcut
    enabled: root.available() && root.dashboard.mode === "edit"
      && (root.dashboard.placingPlugin || root.dashboard.selectedTileId || root.dashboard.selectedElementId)
    autoRepeat: false
    onActivated: root.removeSelected()
    onActivatedAmbiguously: root.removeSelected()
  }
  component AcceptShortcut: Shortcut {
    context: Qt.WindowShortcut
    enabled: root.available() && (root.dashboard.placingPlugin
      ? root.dashboard.mode === "edit" : root.dashboard.mode === "browse")
    autoRepeat: false
    onActivated: root.accept()
    onActivatedAmbiguously: root.accept()
  }
  AcceptShortcut { sequence: "Return" }
  AcceptShortcut { sequence: "Enter" }
  Shortcut {
    sequence: "Ctrl+Tab"; context: Qt.WindowShortcut
    enabled: root.available() && !root.dashboard.placingPlugin
    onActivated: { root.dashboard.cycleTile(1); root.dashboard.mode = "browse"; root.surface.retainKeyboardFocus() }
  }
  Shortcut {
    sequence: "Ctrl+Shift+Tab"; context: Qt.WindowShortcut
    enabled: root.available() && !root.dashboard.placingPlugin
    onActivated: { root.dashboard.cycleTile(-1); root.dashboard.mode = "browse"; root.surface.retainKeyboardFocus() }
  }
  Shortcut {
    sequence: "PageUp"; context: Qt.WindowShortcut; enabled: root.available() && !root.dashboard.placingPlugin
    onActivated: { root.dashboard.moveSpace(-1); root.surface.retainKeyboardFocus() }
  }
  Shortcut {
    sequence: "PageDown"; context: Qt.WindowShortcut; enabled: root.available() && !root.dashboard.placingPlugin
    onActivated: { root.dashboard.moveSpace(1); root.surface.retainKeyboardFocus() }
  }
}
