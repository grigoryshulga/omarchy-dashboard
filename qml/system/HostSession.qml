import QtQuick
import Quickshell

// Session-level bridge to the host shell. Owns environment access, the screen
// list and its changes, the focused monitor name, config-reload events and the
// hyprctl command runner. Quickshell.Hyprland and Quickshell.Io are imported
// only inside the child Loaders, so a missing module fails that one Loader and
// leaves the rest of the session alive. Every function here catches; a broken
// host never breaks a Dashboard binding.
Item {
  id: root

  signal configReloaded()
  signal commandExited(int code)
  signal screensChanged()

  // Best-effort environment read; "" when Quickshell has no env or throws.
  function env(name) {
    try {
      var value = Quickshell.env(name)
      return typeof value === "string" ? value : ""
    } catch (e) {
      return ""
    }
  }

  // Screen list; [] when Quickshell has no screens or throws.
  function screens() {
    try {
      var list = Quickshell.screens
      return list !== undefined && list !== null ? list : []
    } catch (e) {
      return []
    }
  }

  // Name of the focused Hyprland monitor; "" when the probe is absent or fails.
  function focusedScreenName() {
    try {
      var probe = hyprlandProbe.item
      if (probe && typeof probe.focusedScreenName === "function") {
        var name = probe.focusedScreenName()
        return typeof name === "string" ? name : ""
      }
    } catch (e) {
      // Probe missing or hostile; the empty name is the answer.
    }
    return ""
  }

  // True only when the command runner is loaded and idle.
  function commandReady() {
    try {
      var runner = commandRunner.item
      if (!runner || typeof runner.running !== "function") return false
      return runner.running() !== true
    } catch (e) {
      return false
    }
  }

  // Start argv through the runner. False for non-array or empty argv, a
  // missing runner (Quickshell.Io unavailable) or a runner that is busy.
  function startCommand(argv) {
    try {
      if (!Array.isArray(argv) || argv.length === 0) return false
      var runner = commandRunner.item
      if (!runner || typeof runner.start !== "function") return false
      if (typeof runner.running === "function" && runner.running()) return false
      return runner.start(argv) === true
    } catch (e) {
      return false
    }
  }

  // Hyprland side: focused monitor and config reloads. Fails alone when
  // Quickshell.Hyprland is unavailable.
  Loader {
    id: hyprlandProbe
    source: "HyprlandProbe.qml"
    asynchronous: false

    property bool configConnected: false

    onLoaded: {
      try {
        if (!configConnected && item && item.configReloaded !== undefined) {
          item.configReloaded.connect(root.configReloaded)
          configConnected = true
        }
      } catch (e) {
        // A half-loaded probe must not break HostSession creation.
      }
    }
  }

  // hyprctl runner. Its file imports Quickshell.Io, so a missing module fails
  // only this Loader and startCommand just reports false.
  Loader {
    id: commandRunner
    source: "HostCommand.qml"

    property bool exitConnected: false

    onLoaded: {
      try {
        if (!exitConnected && item && item.exited !== undefined) {
          item.exited.connect(function(code) {
            root.commandExited(code)
          })
          exitConnected = true
        }
      } catch (e) {
        // Without exit wiring startCommand still reports readiness.
      }
    }
  }

  // Forward the shell's screen changes. An older host without the signal
  // only leaves this connection silent; loading is unaffected.
  Connections {
    target: Quickshell
    function onScreensChanged() {
      try {
        root.screensChanged()
      } catch (e) {
        // Listeners must not be able to break the session.
      }
    }
  }
}
