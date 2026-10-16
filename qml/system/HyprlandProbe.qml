import QtQuick
import Quickshell.Hyprland

// The only place Dashboard touches Quickshell.Hyprland. Loaded by
// HostSession's `hyprlandProbe` Loader, so a missing Hyprland module fails
// this file alone and HostSession keeps working without a focused monitor.
Item {
  id: root

  signal configReloaded()

  // Focused monitor name, or "" when Hyprland is unreachable.
  function focusedScreenName() {
    try {
      var monitor = Hyprland.focusedMonitor
      if (monitor && monitor.name !== undefined && monitor.name !== null) {
        return String(monitor.name)
      }
    } catch (e) {
      // No active monitor / no Hyprland; report the empty name.
    }
    return ""
  }

  Connections {
    target: Hyprland
    function onRawEvent(event) {
      try {
        if (event && String(event.name) === "configreloaded") root.configReloaded()
      } catch (e) {
        // Guard the event read; reloads are best-effort.
      }
    }
  }
}
