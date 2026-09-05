import QtQuick
import QtTest
import "../../qml/plugins/HostPlacements.js" as HostPlacements
import "../../qml/plugins/PopoutGeometry.js" as PopoutGeometry
import "../../qml/plugins/PluginControls.js" as PluginControls
import "../../qml/plugins/PluginIconResolver.js" as PluginIconResolver
import "../../qml/plugins/PluginPresentation.js" as PluginPresentation
import "../../qml/plugins" as Plugins

TestCase {
  name: "PluginCompatibility"
  when: windowShown

  function tile(id, x, y, w, h) {
    return { id: id, pluginId: "plugin." + id, x: x, y: y, w: w, h: h }
  }

  Plugins.DashboardTileCollection {
    id: tileCollection
  }

  Repeater {
    id: tileCollectionRepeater
    model: tileCollection.model
    delegate: Item {
      required property string tileId
      required property real tileW
    }
  }

  function test_host_placements_follow_dashboard_tiles_and_preserve_settings() {
    var config = { hosts: { "gshulga.dashboard": { placements: [{
      id: "example.weather", instanceId: "old-tile", slot: "old",
      settings: { units: "metric" }
    }] } } }
    var document = { spaces: [
      { id: "work", tiles: [
        { id: "weather-tile", pluginId: "example.weather" },
        { id: "mail-tile", pluginId: "example.mail" }
      ] }
    ] }

    var references = HostPlacements.references(document)
    compare(references.length, 2)
    verify(HostPlacements.synchronize(config, "gshulga.dashboard", references))
    var entries = HostPlacements.entries(config, "gshulga.dashboard")
    compare(entries.length, 2)
    compare(entries[0].instanceId, "weather-tile")
    compare(entries[0].slot, "work")
    compare(entries[0].settings.units, "metric")
    compare(HostPlacements.settingsFor(
      config, "gshulga.dashboard", "example.weather", "").units, "metric")
  }

  function test_host_placements_remove_stale_references_and_reject_duplicates() {
    var config = ({})
    var desired = [
      { id: "example.one", instanceId: "one", slot: "main" },
      { id: "example.one", instanceId: "duplicate", slot: "other" },
      { id: "example.two", instanceId: "one", slot: "other" }
    ]
    verify(HostPlacements.synchronize(config, "gshulga.dashboard", desired))
    compare(HostPlacements.entries(config, "gshulga.dashboard").length, 1)
    verify(HostPlacements.synchronize(config, "gshulga.dashboard", []))
    verify(config.hosts === undefined)
  }

  function test_tile_collection_keeps_unchanged_delegate_instances() {
    tileCollection.synchronize([
      tile("one", 0, 0, 100, 100), tile("two", 100, 0, 100, 100)
    ])
    var first = tileCollectionRepeater.itemAt(0)
    var second = tileCollectionRepeater.itemAt(1)
    compare(first.tileId, "one")
    compare(second.tileId, "two")

    tileCollection.synchronize([
      tile("one", 0, 0, 100, 100), tile("two", 100, 0, 130, 100)
    ])
    compare(tileCollectionRepeater.itemAt(0), first)
    compare(tileCollectionRepeater.itemAt(1), second)
    compare(tileCollectionRepeater.itemAt(1).tileW, 130)
  }

  function test_universal_presentation_prefers_safe_declared_surfaces() {
    var explicit = {
      entryPoints: { dashboardPage: "DashboardPage.qml", dashboardWidget: "Widget.qml", barWidget: "Bar.qml" },
      __sourceDir: "/plugin"
    }
    var capabilities = PluginPresentation.capabilities(explicit)
    compare(capabilities.preferred, "embedded")
    compare(capabilities.available.join(","), "embedded,widget,launcher")

    var resolved = PluginPresentation.resolve(explicit, "auto", {
      explicit: "file:///DashboardPage.qml", widget: "file:///Widget.qml"
    })
    compare(resolved.kind, "embedded")
    compare(resolved.state, "ready")
    compare(resolved.source, "file:///DashboardPage.qml")
  }

  function test_adaptation_tries_all_distinct_declared_surfaces_before_the_bar() {
    var manifest = { entryPoints: {
      panel: "Panel.qml", overlay: "Overlay.qml", barWidget: "Bar.qml", menu: "Panel.qml"
    }, __sourceDir: "/plugin" }
    compare(PluginPresentation.adaptationEntryPoints(manifest), ["Panel.qml", "Overlay.qml", "Bar.qml"])
    compare(PluginPresentation.adaptationEntryPoints({ entryPoints: { panel: {}, menu: "Menu.qml" } }),
      ["Menu.qml"])
    compare(PluginPresentation.capabilities(manifest).adaptationEntryPoint, "Panel.qml")
    verify(PluginPresentation.capabilities({ entryPoints: { menu: "Menu.qml" }, __sourceDir: "/plugin" }).canAdapt)
  }

  function test_declared_pages_and_widgets_can_launch_without_a_bar_widget() {
    var manifest = { entryPoints: { dashboardPage: "Page.qml", dashboardWidget: "Widget.qml" } }
    var result = PluginPresentation.resolve(manifest, "launcher", { explicit: "file:///Page.qml" })
    verify(result.canLaunch)
    compare(result.launchTarget, "popout")
    compare(result.source, "file:///Page.qml")
    result = PluginPresentation.resolve(manifest, "launcher", { widget: "file:///Widget.qml" })
    verify(result.canLaunch)
    compare(result.source, "file:///Widget.qml")
    result = PluginPresentation.resolve(manifest, "launcher", { explicit: "file:///Page.qml" },
      { nativeAvailable: true })
    compare(result.launchTarget, "popout")
  }

  function test_universal_presentation_adapts_then_falls_back_to_launcher() {
    var standard = {
      entryPoints: { barWidget: "BarWidget.qml" },
      __sourceDir: "/plugin"
    }
    var preparing = PluginPresentation.resolve(standard, "auto", {})
    compare(preparing.kind, "embedded")
    compare(preparing.state, "preparing")

    var adapted = PluginPresentation.resolve(standard, "auto", { adapted: "file:///Panel.qml" })
    compare(adapted.kind, "embedded")
    compare(adapted.state, "ready")

    var fallback = PluginPresentation.resolve(standard, "auto", { adaptationError: "unsafe panel" })
    compare(fallback.kind, "launcher")
    compare(fallback.state, "fallback")
    verify(!fallback.canLaunch)

    var popout = PluginPresentation.resolve(standard, "launcher", { adapted: "file:///Panel.qml" })
    verify(popout.canLaunch)
    compare(popout.launchTarget, "popout")
    compare(popout.source, "file:///Panel.qml")

    var nativeLauncher = PluginPresentation.resolve(standard, "launcher", {}, { nativeAvailable: true })
    verify(nativeLauncher.canLaunch)
    compare(nativeLauncher.launchTarget, "popout")
    compare(nativeLauncher.state, "preparing")
    var unsupported = PluginPresentation.resolve(standard, "launcher", { adaptationError: "unsupported" },
      { nativeAvailable: true })
    compare(unsupported.launchTarget, "native")
  }

  function test_popout_size_uses_manifest_then_intrinsic_hints_and_user_override() {
    var metadata = { preferredWidth: 500, preferredHeight: 300,
      popout: { preferredWidth: 600, preferredHeight: 400 } }
    var natural = { width: 700, height: 500 }
    var bounds = { width: 1200, height: 900 }
    var chrome = { width: 20, height: 60 }
    var size = PopoutGeometry.resolve(metadata, natural, null, bounds, chrome)
    compare(size.width, 620)
    compare(size.height, 460)
    size = PopoutGeometry.resolve({}, natural, null, bounds, chrome)
    compare(size.width, 720)
    compare(size.height, 560)
    size = PopoutGeometry.resolve(metadata, natural, { width: 800, height: 600 }, bounds, chrome)
    compare(size.width, 800)
    compare(size.height, 600)
    size = PopoutGeometry.resolve({ preferredWidth: 550 }, natural, null, bounds, chrome)
    compare(size.width, 570)
    compare(size.height, 560)
  }

  function test_popout_size_respects_surround_even_with_large_minimum_or_saved_size() {
    var size = PopoutGeometry.resolve({ popout: { minWidth: 1800, minHeight: 1600 } }, {},
      { width: 4000, height: 3000 }, { width: 900, height: 600 }, { width: 20, height: 60 })
    compare(size.width, 900)
    compare(size.height, 600)
    size = PopoutGeometry.resolve({ preferredWidth: -1, preferredHeight: Infinity }, {},
      { width: NaN, height: -50 }, { width: 1000, height: 800 }, {})
    compare(size.width, 860)
    compare(size.height, 680)
    size = PopoutGeometry.resolve({}, {}, null, { width: 0, height: 0 }, {})
    compare(size.width, 0)
    compare(size.height, 0)
  }

  function test_popout_size_survives_placement_moves_and_can_reset_independently() {
    var config = {}
    HostPlacements.synchronize(config, "dashboard", [
      { id: "plugin.one", instanceId: "one", slot: "work" },
      { id: "plugin.two", instanceId: "two", slot: "work" }
    ])
    verify(HostPlacements.setPopoutSize(config, "dashboard", "plugin.one", { width: 700, height: 450 }))
    verify(!HostPlacements.setPopoutSize(config, "dashboard", "missing", { width: 700, height: 450 }))
    verify(!HostPlacements.setPopoutSize(config, "dashboard", "plugin.one", { width: Infinity, height: 450 }))
    HostPlacements.synchronize(config, "dashboard", [
      { id: "plugin.one", instanceId: "replacement", slot: "home" },
      { id: "plugin.two", instanceId: "two", slot: "pending" }
    ])
    var entries = HostPlacements.entries(config, "dashboard")
    compare(entries[0].popoutSize.width, 700)
    compare(entries[0].popoutSize.height, 450)
    compare(entries[1].popoutSize, null)
    compare(Object.keys(entries[0].settings).length, 0)
    verify(HostPlacements.setPopoutSize(config, "dashboard", "plugin.one", null))
    compare(HostPlacements.entries(config, "dashboard")[0].popoutSize, null)
  }

  function test_dashboard_owned_service_controls_are_explicit_and_toggle_safely() {
    var idle = { stayAwakeStateLoaded: true, stayAwake: false, requested: null }
    idle.setIdleEnabled = function(value) { idle.requested = value }
    var snapshot = PluginControls.snapshot("omarchy.idle", idle)
    verify(snapshot.ready)
    verify(!snapshot.active)
    verify(PluginControls.activate("omarchy.idle", idle))
    compare(idle.requested, false)

    var serviceManifest = { id: "omarchy.idle", entryPoints: { service: "Service.qml" }, kinds: ["service"] }
    var resolved = PluginPresentation.resolve(serviceManifest, "auto", {}, {
      hasControl: true,
      control: snapshot
    })
    compare(resolved.kind, "control")
    compare(resolved.statusText, "Off")
    compare(resolved.available.join(","), "control,launcher")
    compare(PluginPresentation.capabilityLabel(serviceManifest, { hasControl: true }), "Dashboard control")
  }

  function test_plugin_icon_resolver_prefers_explicit_sources_and_has_semantic_fallbacks() {
    var manifest = { id: "omarchy.bluetooth", name: "Bluetooth", kinds: ["bar-widget"] }
    var scanned = { kind: "image", value: "file:///plugin/icon.png" }
    var result = PluginIconResolver.resolve(manifest, scanned, null)
    compare(result.kind, "image")
    compare(result.value, "file:///plugin/icon.png")

    result = PluginIconResolver.resolve({
      id: "custom.plugin", dashboard: { icon: "󰍹" }
    }, scanned, null)
    compare(result.kind, "glyph")
    compare(result.value, "󰍹")

    result = PluginIconResolver.resolve(manifest, null, null)
    compare(result.kind, "glyph")
    compare(result.value, "󰂯")
  }

  function test_service_only_plugin_becomes_information_launcher() {
    var service = { entryPoints: { service: "Service.qml" }, kinds: ["service"] }
    compare(PluginPresentation.capabilityLabel(service), "Information tile")
    var resolved = PluginPresentation.resolve(service, "auto", {})
    compare(resolved.kind, "launcher")
    verify(!resolved.canLaunch)
  }
}
