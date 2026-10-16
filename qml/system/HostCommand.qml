import QtQuick
import Quickshell.Io

// hyprctl command runner for the host session. HostSession loads this file
// through a Loader so a missing Quickshell.Io module fails only here; every
// entry point catches, so a missing hyprctl or a non-zero exit is reported
// through the exited signal and never throws into the caller.
Item {
  id: root

  // Emitted with the process exit code, whatever it is.
  signal exited(int code)

  property bool _busy: false

  Process {
    id: proc

    onExited: function (code) {
      root._busy = false
      try {
        root.exited(code)
      } catch (e) {
        // A broken listener must not affect runner state.
      }
    }
  }

  // True while the underlying process is running.
  function running() {
    try {
      return root._busy === true || proc.running === true
    } catch (e) {
      return root._busy === true
    }
  }

  // Start argv. False (never throw) for a non-array/empty argv or while a
  // command is already running; otherwise sets the command and returns true.
  function start(argv) {
    try {
      if (!Array.isArray(argv) || argv.length === 0) return false
      if (running()) return false
      proc.command = argv
      proc.running = true
      root._busy = true
      return true
    } catch (e) {
      root._busy = false
      return false
    }
  }
}
