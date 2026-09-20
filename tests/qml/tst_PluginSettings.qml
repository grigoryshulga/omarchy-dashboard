import QtQuick
import QtTest
import "../../qml/plugins/PluginSettings.js" as PluginSettings

TestCase {
  name: "PluginSettings"

  function test_reads_own_entry_from_the_public_bar_layout() {
    var config = {
      layout: {
        left: [{ id: "omarchy.clock" }, { id: "gshulga.dashboard", surfaceMode: "Framed" }],
        center: [],
        right: [{ id: "omarchy.tray" }]
      }
    }
    var entry = PluginSettings.fromBarLayout(config, "gshulga.dashboard")
    compare(entry.surfaceMode, "Framed")
    compare(PluginSettings.fromBarLayout(config, "omarchy.tray").id, "omarchy.tray")
    compare(PluginSettings.fromBarLayout(config, "missing"), null)
    compare(PluginSettings.fromBarLayout(null, "gshulga.dashboard"), null)
    compare(PluginSettings.fromBarLayout({}, "gshulga.dashboard"), null)
  }

  function test_accepts_a_bare_id_entry() {
    var config = { layout: { left: ["gshulga.dashboard"] } }
    var entry = PluginSettings.fromBarLayout(config, "gshulga.dashboard")
    compare(entry.id, "gshulga.dashboard")
    compare(entry.surfaceMode, undefined)
  }

  function test_write_keeps_the_other_options() {
    var current = {
      id: "gshulga.dashboard",
      surfaceMode: "Glass",
      dimBackground: true,
      blurBackground: true
    }
    var next = PluginSettings.withSetting(current, "surfaceMode", "Framed")
    compare(next.surfaceMode, "Framed")
    compare(next.dimBackground, true)
    compare(next.blurBackground, true)
    compare(next.id, undefined)
    // The source object is untouched so a failed write cannot corrupt it.
    compare(current.surfaceMode, "Glass")
    compare(PluginSettings.withSetting(null, "surfaceMode", "Framed").surfaceMode, "Framed")
  }
}
