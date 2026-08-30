import QtQuick
import Quickshell.Io
import "DashboardModel.js" as DashboardModel

Item {
  id: root

  required property string directoryPath
  required property string statePath
  required property string readerPath
  property var document: DashboardModel.defaultState()

  property string pendingText: ""
  property string writingText: ""
  property bool writeInProgress: false
  property int saveRetryCount: 0
  property bool readTimedOut: false
  property bool ready: false

  signal loaded()

  function commit(command, boundWidth, boundHeight) {
    if (!ready) return false
    document = DashboardModel.apply(document, command, boundWidth, boundHeight)
    scheduleSave()
    return true
  }

  function replaceDocument(nextDocument) {
    if (!ready) return false
    document = DashboardModel.normalize(nextDocument)
    scheduleSave()
    return true
  }

  function flush() {
    if (writeInProgress || !pendingText) return
    writingText = pendingText
    pendingText = ""
    writeInProgress = true
    stateFile.setText(writingText)
  }

  function scheduleSave() {
    var serialized = DashboardModel.serialize(document)
    if (!serialized) {
      console.warn("Dashboard: state exceeds the size limit")
      return
    }
    pendingText = serialized
    saveRetryCount = 0
    saveTimer.restart()
  }

  function load(raw) {
    var parsed = DashboardModel.parse(raw)
    if (!parsed) {
      console.warn("Dashboard: saved state is invalid; keeping the in-memory layout")
      ready = true
      return
    }
    document = parsed
    ready = true
    loaded()
  }

  Component.onCompleted: directoryInit.running = true
  Component.onDestruction: flush()

  Process {
    id: directoryInit
    clearEnvironment: true
    command: ["/usr/bin/mkdir", "-p", "--", root.directoryPath]
    onExited: function(exitCode) {
      if (exitCode === 0) {
        stateReader.command = [
          "/usr/bin/python3", "-I", root.readerPath,
          root.statePath, String(DashboardModel.MAX_STATE_BYTES)
        ]
        stateReader.running = true
      } else console.warn("Dashboard: could not create the state directory")
    }
  }

  FileView {
    id: stateFile
    path: root.statePath
    atomicWrites: true
    preload: false
    printErrors: false
    onSaved: {
      root.writeInProgress = false
      root.writingText = ""
      root.saveRetryCount = 0
      if (root.pendingText) saveTimer.restart()
    }
    onSaveFailed: function(error) {
      root.writeInProgress = false
      if (!root.pendingText) root.pendingText = root.writingText
      root.writingText = ""
      if (root.saveRetryCount < 2) {
        root.saveRetryCount += 1
        saveTimer.restart()
      } else console.warn("Dashboard: failed to save state:", error)
    }
  }

  Timer {
    id: saveTimer
    interval: root.saveRetryCount > 0 ? 1000 : 180
    onTriggered: root.flush()
  }

  Process {
    id: stateReader
    clearEnvironment: true
    stdout: StdioCollector { id: stateReaderOutput; waitForEnd: true }
    onStarted: stateReaderTimeout.restart()
    onExited: function(exitCode) {
      stateReaderTimeout.stop()
      stateReaderKillTimer.stop()
      if (root.readTimedOut) {
        root.readTimedOut = false
        console.warn("Dashboard: state reader timed out")
      } else if (exitCode === 0) root.load(String(stateReaderOutput.text || ""))
      else if (exitCode === 1) {
        root.ready = true
        root.scheduleSave()
      }
      else if (exitCode === 2) console.warn("Dashboard: saved state exceeds the size limit")
      else if (exitCode === 3) console.warn("Dashboard: refusing an unsafe state file")
      else console.warn("Dashboard: state could not be read")
    }
  }

  Timer {
    id: stateReaderTimeout
    interval: 3000
    onTriggered: {
      if (!stateReader.running) return
      root.readTimedOut = true
      stateReader.running = false
      stateReaderKillTimer.restart()
    }
  }

  Timer {
    id: stateReaderKillTimer
    interval: 1000
    onTriggered: if (stateReader.running) stateReader.signal(9)
  }
}
