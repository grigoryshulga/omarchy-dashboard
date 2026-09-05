import QtQuick
import Quickshell.Io
import "DashboardModel.js" as DashboardModel

Item {
  id: root

  required property string statePath
  required property string readerPath
  required property string writerPath
  property var document: DashboardModel.defaultState()

  property string pendingText: ""
  property string writingText: ""
  property bool writeInProgress: false
  property int saveRetryCount: 0
  property bool readTimedOut: false
  property bool writeTimedOut: false
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
    stateWriter.command = [
      "/usr/bin/python3", "-I", root.writerPath,
      root.statePath, String(DashboardModel.utf8ByteLength(writingText)),
      String(DashboardModel.MAX_STATE_BYTES)
    ]
    stateWriter.running = true
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

  Component.onCompleted: {
    stateReader.command = [
      "/usr/bin/python3", "-I", root.readerPath,
      root.statePath, String(DashboardModel.MAX_STATE_BYTES)
    ]
    stateReader.running = true
  }
  Component.onDestruction: flush()

  Process {
    id: stateWriter
    clearEnvironment: true
    stdinEnabled: true
    onStarted: {
      stateWriterTimeout.restart()
      stateWriter.write(root.writingText)
    }
    onExited: function(exitCode) {
      stateWriterTimeout.stop()
      stateWriterKillTimer.stop()
      root.writeInProgress = false
      if (exitCode !== 0 && !root.pendingText) root.pendingText = root.writingText
      root.writingText = ""
      if (root.writeTimedOut) {
        root.writeTimedOut = false
        console.warn("Dashboard: state writer timed out")
      } else if (exitCode === 0) {
        root.saveRetryCount = 0
      } else if (exitCode === 2) {
        console.warn("Dashboard: state exceeds the size limit")
      } else if (exitCode === 3) {
        console.warn("Dashboard: refusing an unsafe state path")
      } else if (root.saveRetryCount < 2) {
        root.saveRetryCount += 1
        saveTimer.restart()
      } else console.warn("Dashboard: failed to save state")
      if (root.pendingText && exitCode === 0) saveTimer.restart()
    }
  }

  Timer {
    id: saveTimer
    interval: root.saveRetryCount > 0 ? 1000 : 180
    onTriggered: root.flush()
  }

  Timer {
    id: stateWriterTimeout
    interval: 3000
    onTriggered: {
      if (!stateWriter.running) return
      root.writeTimedOut = true
      stateWriter.running = false
      stateWriterKillTimer.restart()
    }
  }

  Timer {
    id: stateWriterKillTimer
    interval: 1000
    onTriggered: if (stateWriter.running) stateWriter.signal(9)
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
