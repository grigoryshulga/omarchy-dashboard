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

  function test_overrides_win_over_a_stale_entry() {
    var stored = { id: "gshulga.dashboard", surfaceMode: "Framed", blurBackground: true }
    var merged = PluginSettings.withOverrides(stored, { surfaceMode: "Glass" })
    compare(merged.surfaceMode, "Glass")
    compare(merged.blurBackground, true)
    compare(merged.id, undefined)
    // The persisted object is untouched.
    compare(stored.surfaceMode, "Framed")
    compare(PluginSettings.withOverrides(null, { surfaceMode: "Glass" }).surfaceMode, "Glass")
  }

  function test_unconfirmed_overrides_survive_a_stale_republish() {
    // The scoped API can republish the value we just replaced; keeping the echo
    // avoids flipping the UI back to it.
    var result = PluginSettings.settleOverrides({ surfaceMode: "Glass" }, { surfaceMode: "Framed" })
    compare(result.settled, false)
    compare(result.overrides.surfaceMode, "Glass")
  }

  function test_confirmed_overrides_are_dropped() {
    // Once the store agrees the echo is no longer needed and external edits win.
    var result = PluginSettings.settleOverrides(
      { surfaceMode: "Glass", blurBackground: true },
      { surfaceMode: "Glass", blurBackground: false })
    compare(result.settled, true)
    compare(result.overrides.surfaceMode, undefined)
    // A missing key means the write was not published yet, so keep it.
    compare(result.overrides.blurBackground, true)
  }

  function test_settle_without_overrides_is_a_noop() {
    var result = PluginSettings.settleOverrides({}, { surfaceMode: "Framed" })
    compare(result.settled, false)
    compare(Object.keys(result.overrides).length, 0)
  }
}
