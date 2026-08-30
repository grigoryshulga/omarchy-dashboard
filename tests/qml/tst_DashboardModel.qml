import QtQuick
import QtTest
import "../.." as Dashboard
import "../../DashboardAppearance.js" as DashboardAppearance
import "../../DashboardModel.js" as DashboardModel
import "../../GridEngine.js" as GridEngine
import "../../HostPlacements.js" as HostPlacements
import "../../HyprlandBlur.js" as HyprlandBlur
import "../../PluginControls.js" as PluginControls
import "../../PluginIconResolver.js" as PluginIconResolver
import "../../PluginPresentation.js" as PluginPresentation
import "../../SpatialNavigation.js" as SpatialNavigation

TestCase {
  name: "DashboardModel"
  when: windowShown

  QtObject {
    id: shortcutDashboard
    property string overlay: ""
    property string selectedSpaceId: ""
    property var dashboardState: ({ spaces: [
      { id: "one", name: "One" },
      { id: "two", name: "Two" },
      { id: "three", name: "Three" }
    ] })
    function selectSpace(id) { selectedSpaceId = id }
  }

  Dashboard.DashboardSpaceShortcuts {
    id: spaceShortcuts
    dashboard: shortcutDashboard
    active: true
  }

  Item {
    id: shortcutFocusSink
    focus: true
    Keys.onPressed: function(event) { event.accepted = true }
  }

  function tile(id, x, y, w, h) {
    return { id: id, pluginId: "plugin." + id, x: x, y: y, w: w, h: h }
  }

  function test_surface_modes_normalize_legacy_push_to_glass() {
    compare(DashboardAppearance.surfaceMode("Framed"), "framed")
    compare(DashboardAppearance.surfaceMode("glass"), "glass")
    compare(DashboardAppearance.surfaceMode("Push"), "glass")
    compare(DashboardAppearance.surfaceMode("unknown"), "glass")
    verify(!DashboardAppearance.usesGlass("Framed"))
    verify(DashboardAppearance.usesGlass("Glass"))
    verify(DashboardAppearance.usesGlass("Push"))
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

  function test_pending_placement_is_hosted_without_tile_geometry() {
    var state = DashboardModel.defaultState()
    var result = DashboardModel.managePlacement(state, {
      operation: "pending", pluginId: "example.weather",
      instanceId: "placement-weather", label: "Weather", embedding: "widget"
    }, 800, 600)
    verify(result.ok)
    verify(result.changed)
    compare(result.placement.state, "pending")
    compare(result.state.pendingPlacements.length, 1)
    compare(result.state.spaces[0].tiles.length, 0)

    var references = HostPlacements.references(result.state)
    compare(references.length, 1)
    compare(references[0].id, "example.weather")
    compare(references[0].slot, "pending")
  }

  function test_pending_placement_can_be_placed_exactly_and_returned_to_pending() {
    var pending = DashboardModel.managePlacement(DashboardModel.defaultState(), {
      operation: "pending", pluginId: "example.weather",
      instanceId: "placement-weather", label: "Weather", embedding: "widget"
    }, 800, 600)
    var placed = DashboardModel.managePlacement(pending.state, {
      operation: "place", pluginId: "example.weather", spaceId: "space-main",
      strategy: "exact", rect: { x: 40, y: 20, w: 360, h: 260 },
      hints: { minW: 160, minH: 120 }
    }, 800, 600)
    verify(placed.ok)
    compare(placed.placement.id, "placement-weather")
    compare(placed.placement.state, "placed")
    compare(placed.placement.rect.x, 40)
    compare(placed.state.pendingPlacements.length, 0)

    var returned = DashboardModel.managePlacement(placed.state, {
      operation: "pending", pluginId: "example.weather"
    }, 800, 600)
    verify(returned.ok)
    compare(returned.placement.id, "placement-weather")
    compare(returned.placement.embedding, "widget")
    compare(returned.state.spaces[0].tiles.length, 0)
  }

  function test_ui_add_tile_consumes_pending_without_changing_identity() {
    var pending = DashboardModel.managePlacement(DashboardModel.defaultState(), {
      operation: "pending", pluginId: "example.weather",
      instanceId: "placement-weather", label: "Weather"
    }, 800, 600)
    var placed = DashboardModel.apply(pending.state, {
      type: "addTile", id: "placement-weather", pluginId: "example.weather",
      label: "Weather", rect: { x: 0, y: 0, w: 360, h: 260 }
    }, 800, 600)
    compare(placed.pendingPlacements.length, 0)
    compare(placed.spaces[0].tiles.length, 1)
    compare(placed.spaces[0].tiles[0].id, "placement-weather")
  }

  function test_exact_placement_rejects_collision_atomically() {
    var state = DashboardModel.apply(DashboardModel.defaultState(), {
      type: "addTile", id: "occupied", pluginId: "example.occupied",
      rect: { x: 0, y: 0, w: 300, h: 200 }
    }, 800, 600)
    var before = DashboardModel.serialize(state)
    var result = DashboardModel.managePlacement(state, {
      operation: "place", pluginId: "example.weather", instanceId: "weather",
      spaceId: "space-main", strategy: "exact",
      rect: { x: 100, y: 100, w: 300, h: 200 }, hints: { minW: 160, minH: 120 }
    }, 800, 600)
    verify(!result.ok)
    compare(result.code, "invalid-or-colliding-rect")
    compare(DashboardModel.serialize(result.state), before)
  }

  function test_placed_plugin_moves_between_spaces_atomically() {
    var state = DashboardModel.apply(DashboardModel.defaultState(), {
      type: "addSpace", id: "work", name: "Work"
    }, 800, 600)
    var placed = DashboardModel.managePlacement(state, {
      operation: "place", pluginId: "example.weather", instanceId: "weather",
      spaceId: "space-main", strategy: "exact",
      rect: { x: 0, y: 0, w: 300, h: 200 }, hints: { minW: 160, minH: 120 }
    }, 800, 600)
    var moved = DashboardModel.managePlacement(placed.state, {
      operation: "move", pluginId: "example.weather", spaceId: "work",
      strategy: "exact", rect: { x: 400, y: 100, w: 300, h: 200 },
      hints: { minW: 160, minH: 120 }
    }, 800, 600)
    verify(moved.ok)
    compare(moved.state.spaces[0].tiles.length, 0)
    compare(moved.state.spaces[1].tiles.length, 1)
    compare(moved.placement.spaceId, "work")
    compare(moved.placement.rect.x, 400)
  }

  function test_space_shortcut_works_when_focused_plugin_accepts_the_key() {
    shortcutDashboard.overlay = ""
    shortcutDashboard.selectedSpaceId = ""
    shortcutFocusSink.forceActiveFocus()
    verify(shortcutFocusSink.activeFocus)
    keyClick(Qt.Key_2, Qt.AltModifier)
    tryCompare(shortcutDashboard, "selectedSpaceId", "two")
  }

  function test_space_shortcut_is_suspended_while_an_overlay_is_open() {
    shortcutDashboard.overlay = "catalog"
    shortcutDashboard.selectedSpaceId = ""
    shortcutFocusSink.forceActiveFocus()
    keyClick(Qt.Key_3, Qt.AltModifier)
    wait(20)
    compare(shortcutDashboard.selectedSpaceId, "")
    shortcutDashboard.overlay = ""
  }

  function test_hyprland_blur_options_map_to_a_bounded_wallpaper_effect() {
    var parsed = HyprlandBlur.parse(
      '{"option":"decoration:blur:enabled","bool":true}\n' +
      '{"option":"decoration:blur:size","int":10}\n' +
      '{"option":"decoration:blur:passes","int":3}\n' +
      '{"option":"decoration:blur:brightness","float":0.8}\n' +
      '{"option":"decoration:blur:contrast","float":1.0}\n' +
      '{"option":"decoration:blur:vibrancy","float":0.5}')
    var effect = HyprlandBlur.effect(parsed)
    verify(effect.enabled)
    compare(effect.blurMax, 120)
    compare(effect.brightness, -0.2)
    compare(effect.contrast, 0)
    compare(effect.saturation, 0.5)

    effect = HyprlandBlur.effect({ enabled: false, size: 100, passes: 20 })
    verify(!effect.enabled)
    compare(effect.blurMax, 128)
  }

  function test_grid_uses_five_pixel_snap() {
    compare(GridEngine.snap(0), 0)
    compare(GridEngine.snap(7), 5)
    compare(GridEngine.snap(8), 10)
    var normalized = GridEngine.normalizeRect({ x: 13, y: 18, w: 203, h: 197 }, 100, 100, 800, 600)
    compare(normalized.x, 15)
    compare(normalized.y, 20)
    compare(normalized.w, 205)
    compare(normalized.h, 195)
  }

  function test_grid_rejects_collisions_bounds_and_unsnapped_values() {
    var tiles = [tile("a", 0, 0, 300, 200)]
    verify(!GridEngine.canPlace({ x: 295, y: 195, w: 100, h: 100 }, tiles, "", 800, 600))
    verify(GridEngine.canPlace({ x: 300, y: 0, w: 100, h: 100 }, tiles, "", 800, 600))
    verify(!GridEngine.canPlace({ x: 750, y: 0, w: 100, h: 100 }, tiles, "", 800, 600))
    verify(!GridEngine.canPlace({ x: 302, y: 0, w: 100, h: 100 }, tiles, "", 800, 600))
    verify(!GridEngine.canPlace({ x: "300", y: 0, w: 100, h: 100 }, tiles, "", 800, 600))
  }

  function test_first_free_is_deterministic() {
    var rect = GridEngine.firstFree(300, 200, [tile("a", 0, 0, 300, 200)], 800, 600)
    compare(rect.x, 300)
    compare(rect.y, 0)
  }

  function test_best_free_keeps_preferred_size_when_it_fits() {
    var rect = GridEngine.bestFree(360, 260, 160, 120,
                                   [tile("a", 0, 0, 360, 260)], 800, 600, 20)
    compare(rect.x, 360)
    compare(rect.y, 0)
    compare(rect.w, 360)
    compare(rect.h, 260)
  }

  function test_best_free_shrinks_to_use_a_narrow_gap() {
    var rect = GridEngine.bestFree(360, 260, 160, 120,
                                   [tile("a", 0, 0, 600, 600)], 800, 600, 20)
    verify(rect !== null)
    compare(rect.x, 600)
    compare(rect.y, 0)
    compare(rect.w, 200)
    compare(rect.h, 260)
    verify(GridEngine.canPlace(rect, [tile("a", 0, 0, 600, 600)], "", 800, 600))
  }

  function test_best_free_can_use_minimum_size_between_coarse_grid_lines() {
    var rect = GridEngine.bestFree(360, 260, 160, 120,
                                   [tile("a", 0, 0, 630, 600)], 800, 600, 30)
    verify(rect !== null)
    compare(rect.x, 630)
    compare(rect.w, 170)
    compare(rect.h, 260)
  }

  function test_best_free_returns_null_when_minimum_size_does_not_fit() {
    var rect = GridEngine.bestFree(360, 260, 160, 120,
                                   [tile("a", 0, 0, 800, 600)], 800, 600, 20)
    verify(rect === null)
  }

  function test_model_normalizes_duplicate_plugins_and_overlaps() {
    var state = DashboardModel.normalize({
      version: DashboardModel.VERSION,
      activeSpaceId: "one",
      spaces: [{ id: "one", name: "One", tiles: [
        tile("a", 0, 0, 300, 200),
        { id: "b", pluginId: "plugin.a", x: 300, y: 0, w: 300, h: 200 },
        tile("c", 200, 100, 300, 200)
      ] }]
    })
    compare(state.spaces.length, 1)
    compare(state.spaces[0].tiles.length, 1)
    compare(state.spaces[0].tiles[0].id, "a")
  }

  function test_commands_manage_spaces_and_tiles() {
    var state = DashboardModel.defaultState()
    state = DashboardModel.apply(state, { type: "addSpace", id: "work", name: "Work" }, 800, 600)
    compare(state.activeSpaceId, "work")
    state = DashboardModel.apply(state, {
      type: "addTile", spaceId: "work", id: "audio", pluginId: "omarchy.audio", w: 300, h: 200
    }, 800, 600)
    compare(state.spaces[1].tiles.length, 1)
    state = DashboardModel.apply(state, {
      type: "moveTile", spaceId: "work", tileId: "audio", dx: 10, dy: 5
    }, 800, 600)
    compare(state.spaces[1].tiles[0].x, 10)
    compare(state.spaces[1].tiles[0].y, 5)
    state = DashboardModel.apply(state, {
      type: "resizeTile", spaceId: "work", tileId: "audio", dw: 5, dh: 10
    }, 800, 600)
    compare(state.spaces[1].tiles[0].w, 305)
    compare(state.spaces[1].tiles[0].h, 210)
  }

  function test_commands_manage_graphic_elements_without_tile_collisions() {
    var state = DashboardModel.defaultState()
    state = DashboardModel.apply(state, {
      type: "addTile", id: "plugin", pluginId: "example.plugin",
      rect: { x: 0, y: 0, w: 300, h: 200 }
    }, 800, 600)
    state = DashboardModel.apply(state, {
      type: "addDivider", id: "divider", x1: 0, y1: 100, x2: 300, y2: 100
    }, 800, 600)
    state = DashboardModel.apply(state, {
      type: "addText", id: "heading", text: "System status",
      rect: { x: 20, y: 20, w: 240, h: 60 }
    }, 800, 600)

    compare(state.spaces[0].elements.length, 2)
    compare(state.spaces[0].elements[0].kind, "divider")
    compare(state.spaces[0].elements[1].text, "System status")

    state = DashboardModel.apply(state, {
      type: "placeElement", elementId: "divider",
      geometry: { x1: 400, y1: 0, x2: 400, y2: 300 }
    }, 800, 600)
    compare(state.spaces[0].elements[0].x1, 400)
    compare(state.spaces[0].elements[0].x2, 400)
    compare(state.spaces[0].elements[0].y2, 300)

    state = DashboardModel.apply(state, {
      type: "updateText", elementId: "heading", text: "Updated"
    }, 800, 600)
    compare(state.spaces[0].elements[1].text, "Updated")

    state = DashboardModel.apply(state, {
      type: "removeElement", elementId: "divider"
    }, 800, 600)
    compare(state.spaces[0].elements.length, 1)
    compare(state.spaces[0].elements[0].id, "heading")
  }

  function test_graphic_elements_are_axis_aligned_bounded_and_normalized() {
    var state = DashboardModel.normalize({
      version: DashboardModel.VERSION,
      activeSpaceId: "main",
      spaces: [{ id: "main", name: "Main", tiles: [], elements: [
        { id: "diagonal", kind: "divider", x1: 0, y1: 0, x2: 100, y2: 50 },
        { id: "zero", kind: "divider", x1: 20, y1: 20, x2: 20, y2: 20 },
        { id: "line", kind: "divider", x1: 2, y1: 18, x2: 102, y2: 18 },
        { id: "empty", kind: "text", text: " ", x: 0, y: 0, w: 100, h: 30 },
        { id: "label", kind: "text", text: " Label ", x: 12, y: 17, w: 81, h: 29 }
      ] }]
    })
    compare(state.spaces[0].elements.length, 2)
    compare(state.spaces[0].elements[0].id, "line")
    compare(state.spaces[0].elements[0].x1, 0)
    compare(state.spaces[0].elements[0].y1, 20)
    compare(state.spaces[0].elements[0].x2, 100)
    compare(state.spaces[0].elements[1].text, "Label")
    compare(state.spaces[0].elements[1].x, 10)
    compare(state.spaces[0].elements[1].w, 80)

    var unchanged = DashboardModel.apply(state, {
      type: "placeElement", elementId: "line",
      geometry: { x1: 0, y1: 20, x2: 900, y2: 20 }
    }, 800, 600)
    compare(unchanged.spaces[0].elements[0].x2, 100)
  }

  function test_tile_presentation_preference_is_normalized_and_mutable() {
    var state = DashboardModel.defaultState()
    state = DashboardModel.apply(state, {
      type: "addTile", id: "plugin", pluginId: "example.plugin",
      w: 300, h: 200, embedding: "widget"
    }, 800, 600)
    compare(state.spaces[0].tiles[0].embedding, "widget")

    state = DashboardModel.apply(state, {
      type: "setTileEmbedding", tileId: "plugin", embedding: "launcher"
    }, 800, 600)
    compare(state.spaces[0].tiles[0].embedding, "launcher")

    state.spaces[0].tiles[0].embedding = "standard"
    compare(DashboardModel.normalize(state).spaces[0].tiles[0].embedding, "embedded")

    state.spaces[0].tiles[0].embedding = "control"
    compare(DashboardModel.normalize(state).spaces[0].tiles[0].embedding, "control")
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
    compare(nativeLauncher.launchTarget, "native")
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

  function test_invalid_moves_and_resizes_are_atomic() {
    var state = DashboardModel.normalize({
      version: DashboardModel.VERSION,
      activeSpaceId: "main",
      spaces: [{ id: "main", name: "Main", tiles: [
        tile("a", 0, 0, 300, 200), tile("b", 350, 0, 200, 200)
      ] }]
    })
    state = DashboardModel.apply(state, {
      type: "moveTile", spaceId: "main", tileId: "a", dx: 100, dy: 0
    }, 800, 600)
    compare(state.spaces[0].tiles[0].x, 0)
    state = DashboardModel.apply(state, {
      type: "resizeTile", spaceId: "main", tileId: "a", dw: 100, dh: 0
    }, 800, 600)
    compare(state.spaces[0].tiles[0].w, 300)
    state = DashboardModel.apply(state, {
      type: "resizeTile", spaceId: "main", tileId: "a", dw: -900, dh: -900, minW: 160, minH: 120
    }, 800, 600)
    compare(state.spaces[0].tiles[0].w, 160)
    compare(state.spaces[0].tiles[0].h, 120)
  }

  function test_plugins_are_unique_across_spaces() {
    var state = DashboardModel.defaultState()
    state = DashboardModel.apply(state, {
      type: "addTile", id: "audio-a", pluginId: "omarchy.audio", w: 300, h: 200
    }, 800, 600)
    state = DashboardModel.apply(state, { type: "addSpace", id: "other", name: "Other" }, 800, 600)
    state = DashboardModel.apply(state, {
      type: "addTile", spaceId: "other", id: "audio-b", pluginId: "omarchy.audio", w: 300, h: 200
    }, 800, 600)
    compare(state.spaces[0].tiles.length, 1)
    compare(state.spaces[1].tiles.length, 0)
  }

  function test_removing_spaces_preserves_a_valid_active_space() {
    var state = DashboardModel.defaultState()
    state = DashboardModel.apply(state, { type: "addSpace", id: "two", name: "Two" })
    state = DashboardModel.apply(state, { type: "removeSpace", spaceId: "two" })
    compare(state.spaces.length, 1)
    compare(state.activeSpaceId, "space-main")
    state = DashboardModel.apply(state, { type: "removeSpace", spaceId: "space-main" })
    compare(state.spaces.length, 1)
  }

  function test_reordering_spaces_keeps_the_active_space() {
    var state = DashboardModel.defaultState()
    state = DashboardModel.apply(state, { type: "addSpace", id: "two", name: "Two" })
    state = DashboardModel.apply(state, { type: "addSpace", id: "three", name: "Three" })
    compare(state.activeSpaceId, "three")

    state = DashboardModel.apply(state, { type: "reorderSpace", spaceId: "three", toIndex: 0 })
    compare(state.spaces[0].id, "three")
    compare(state.spaces[1].id, "space-main")
    compare(state.spaces[2].id, "two")
    compare(state.activeSpaceId, "three")

    state = DashboardModel.apply(state, { type: "reorderSpace", spaceId: "three", toIndex: 99 })
    compare(state.spaces[2].id, "three")
    state = DashboardModel.apply(state, { type: "reorderSpace", spaceId: "three", toIndex: "not-an-index" })
    compare(state.spaces[2].id, "three")
  }

  function test_v2_pixel_state_is_upgraded_without_moving_tiles() {
    var parsed = DashboardModel.parse(JSON.stringify({
      version: 2,
      activeSpaceId: "main",
      spaces: [{ id: "main", name: "Main", tiles: [tile("a", 10, 20, 400, 300)] }]
    }))
    verify(parsed !== null)
    compare(parsed.version, DashboardModel.VERSION)
    compare(parsed.gridSpacing, 10)
    compare(parsed.spaces[0].tiles[0].x, 10)
    compare(parsed.spaces[0].tiles[0].y, 20)
    compare(parsed.spaces[0].tiles[0].w, 400)
    compare(parsed.spaces[0].tiles[0].h, 300)
  }

  function test_v3_state_is_upgraded_with_an_empty_element_collection() {
    var parsed = DashboardModel.parse(JSON.stringify({
      version: 3,
      activeSpaceId: "main",
      spaces: [{ id: "main", name: "Main", tiles: [tile("a", 10, 20, 400, 300)] }]
    }))
    verify(parsed !== null)
    compare(parsed.version, DashboardModel.VERSION)
    compare(parsed.spaces[0].elements.length, 0)
  }

  function test_grid_spacing_is_configurable_and_bounded() {
    var state = DashboardModel.defaultState()
    state = DashboardModel.apply(state, { type: "setGridSpacing", value: 25 })
    compare(state.gridSpacing, 25)
    state = DashboardModel.apply(state, { type: "setGridSpacing", value: 2 })
    compare(state.gridSpacing, DashboardModel.MIN_GRID_SPACING)
    state = DashboardModel.apply(state, { type: "setGridSpacing", value: 999 })
    compare(state.gridSpacing, DashboardModel.MAX_GRID_SPACING)
  }

  function test_canvas_bounds_persist_and_never_clip_existing_content() {
    var state = DashboardModel.defaultState()
    state = DashboardModel.apply(state, {
      type: "setCanvasBounds", width: 2010, height: 1050
    }, 2010, 1050)
    compare(state.canvasWidth, 2010)
    compare(state.canvasHeight, 1050)

    state = DashboardModel.apply(state, {
      type: "addTile", id: "wide", pluginId: "example.wide",
      rect: { x: 1800, y: 900, w: 200, h: 100 }
    }, 2010, 1050)
    state = DashboardModel.apply(state, {
      type: "setCanvasBounds", width: 1600, height: 800
    }, 1600, 800)
    compare(state.canvasWidth, 2000)
    compare(state.canvasHeight, 1000)

    var roundTrip = DashboardModel.parse(DashboardModel.serialize(state))
    compare(roundTrip.canvasWidth, 2000)
    compare(roundTrip.canvasHeight, 1000)
  }

  function test_grid_spacing_controls_geometry() {
    compare(GridEngine.snap(13, 20), 20)

    var state = DashboardModel.defaultState()
    state = DashboardModel.apply(state, { type: "setGridSpacing", value: 20 }, 800, 600)
    state = DashboardModel.apply(state, {
      type: "addTile", id: "audio", pluginId: "omarchy.audio", w: 300, h: 200
    }, 800, 600)
    state = DashboardModel.apply(state, {
      type: "nudgeTile", tileId: "audio", dx: 1, dy: 1
    }, 800, 600)
    compare(state.spaces[0].tiles[0].x, 20)
    compare(state.spaces[0].tiles[0].y, 20)

    state = DashboardModel.apply(state, {
      type: "resizeTileByGrid", tileId: "audio", dw: 1, dh: 1,
      minW: 160, minH: 120
    }, 800, 600)
    compare(state.spaces[0].tiles[0].w, 320)
    compare(state.spaces[0].tiles[0].h, 220)

    var placed = GridEngine.firstFree(50, 50, [tile("occupied", 0, 0, 95, 50)], 800, 600, 40)
    compare(placed.x, 120)
  }

  function test_centered_canvas_uses_dotted_bounds_without_clipping_layout() {
    var spaces = [{ tiles: [
      { x: 0, y: 0, w: 2010, h: 1050 }
    ] }]
    var fitted = GridEngine.centeredBounds(2020, 1065, 30, spaces)
    compare(fitted.width, 2010)
    compare(fitted.height, 1050)

    var fallback = GridEngine.centeredBounds(2020, 1065, 80, spaces)
    compare(fallback.width, 2020)
    compare(fallback.height, 1065)

    var empty = GridEngine.centeredBounds(2020, 1065, 80, [])
    compare(empty.width, 2000)
    compare(empty.height, 1040)

    var decorated = GridEngine.centeredBounds(800, 600, 40, [{
      tiles: [], elements: [
        { kind: "divider", x1: 0, y1: 560, x2: 760, y2: 560 },
        { kind: "text", x: 600, y: 400, w: 200, h: 160 }
      ]
    }])
    compare(decorated.width, 800)
    compare(decorated.height, 600)
  }

  function test_rect_snaps_to_canvas_center_axes_within_threshold() {
    var vertical = GridEngine.snapRectToCenter(
      { x: 344, y: 40, w: 300, h: 200 }, 1000, 600, 12)
    compare(vertical.rect.x, 350)
    compare(vertical.rect.y, 40)
    verify(vertical.vertical)
    verify(!vertical.horizontal)

    var both = GridEngine.snapRectToCenter(
      { x: 345, y: 205, w: 300, h: 200 }, 1000, 600, 12)
    compare(both.rect.x, 350)
    compare(both.rect.y, 200)
    verify(both.vertical)
    verify(both.horizontal)

    var outside = GridEngine.snapRectToCenter(
      { x: 330, y: 180, w: 300, h: 200 }, 1000, 600, 12)
    compare(outside.rect.x, 330)
    compare(outside.rect.y, 180)
    verify(!outside.vertical)
    verify(!outside.horizontal)
  }

  function test_center_snap_keeps_origin_on_five_pixel_lattice() {
    var aligned = GridEngine.snapRectToCenter(
      { x: 300, y: 200, w: 200, h: 100 }, 805, 505, 5)
    compare(aligned.rect.x, 305)
    compare(aligned.rect.y, 205)
    compare(aligned.rect.x % GridEngine.STEP, 0)
    compare(aligned.rect.y % GridEngine.STEP, 0)
    verify(aligned.vertical)
    verify(aligned.horizontal)
  }

  function test_center_snap_keeps_origin_on_active_grid() {
    var aligned = GridEngine.snapRectToCenter(
      { x: 870, y: 390, w: 300, h: 300 }, 2010, 1050, 15, 30)
    verify(aligned.vertical)
    verify(aligned.horizontal)
    compare(aligned.rect.x % 30, 0)
    compare(aligned.rect.y % 30, 0)
    compare(aligned.verticalPosition, 1020)
    compare(aligned.horizontalPosition, 540)
  }

  function test_center_snap_skips_axis_when_size_cannot_stay_on_grid() {
    var aligned = GridEngine.snapRectToCenter(
      { x: 810, y: 0, w: 390, h: 300 }, 2010, 1050, 15, 30)
    verify(!aligned.vertical)
    compare(aligned.rect.x, 810)
    compare(aligned.rect.x % 30, 0)
    compare(aligned.verticalPosition % 30, 0)
  }

  function test_first_grid_operation_aligns_existing_geometry() {
    compare(GridEngine.snapFrom(395, 1, 50), 400)
    compare(GridEngine.snapFrom(395, -1, 50), 395)
    compare(GridEngine.snapFrom(395, -30, 50), 350)

    function stateWithUnalignedTile() {
      return DashboardModel.normalize({
        version: DashboardModel.VERSION,
        gridSpacing: 50,
        activeSpaceId: "main",
        spaces: [{ id: "main", name: "Main", tiles: [tile("audio", 80, 80, 395, 720)] }]
      })
    }

    var state = DashboardModel.apply(stateWithUnalignedTile(), {
      type: "resizeTileByGrid", tileId: "audio", dw: 1, dh: 1,
      minW: 160, minH: 120
    }, 1800, 900)
    compare(state.spaces[0].tiles[0].w, 400)
    compare(state.spaces[0].tiles[0].h, 750)

    state = DashboardModel.apply(state, {
      type: "resizeTileByGrid", tileId: "audio", dw: 1, dh: 0,
      minW: 160, minH: 120
    }, 1800, 900)
    compare(state.spaces[0].tiles[0].w, 450)

    state = DashboardModel.apply(stateWithUnalignedTile(), {
      type: "resizeTileByGrid", tileId: "audio", dw: -1, dh: 0,
      minW: 160, minH: 120
    }, 1800, 900)
    compare(state.spaces[0].tiles[0].w, 350)

    state = DashboardModel.apply(stateWithUnalignedTile(), {
      type: "nudgeTile", tileId: "audio", dx: 1, dy: 0
    }, 1800, 900)
    compare(state.spaces[0].tiles[0].x, 100)
  }

  function test_parse_rejects_invalid_or_oversized_state() {
    verify(DashboardModel.parse("not json") === null)
    verify(DashboardModel.parse(JSON.stringify({ version: 1, spaces: [] })) === null)
    verify(DashboardModel.parse(JSON.stringify({ version: 99, spaces: [] })) === null)
    var oversized = new Array(DashboardModel.MAX_STATE_BYTES + 2).join("x")
    verify(DashboardModel.parse(oversized) === null)
  }

  function test_serialization_round_trip_is_stable() {
    var state = DashboardModel.defaultState()
    state = DashboardModel.apply(state, {
      type: "addTile", id: "network", pluginId: "omarchy.network", w: 300, h: 200
    }, 800, 600)
    var parsed = DashboardModel.parse(DashboardModel.serialize(state))
    verify(parsed !== null)
    compare(parsed.spaces[0].tiles[0].pluginId, "omarchy.network")
    compare(DashboardModel.serialize(parsed), DashboardModel.serialize(state))
  }

  function test_spatial_navigation_uses_geometry() {
    var tiles = [
      tile("center", 400, 300, 100, 100), tile("left", 0, 300, 100, 100),
      tile("right", 800, 300, 100, 100), tile("up", 400, 0, 100, 100),
      tile("down", 400, 600, 100, 100)
    ]
    compare(SpatialNavigation.next(tiles, "center", "left"), "left")
    compare(SpatialNavigation.next(tiles, "center", "right"), "right")
    compare(SpatialNavigation.next(tiles, "center", "up"), "up")
    compare(SpatialNavigation.next(tiles, "center", "down"), "down")
    compare(SpatialNavigation.sequential(tiles, "down", 1), "center")
    compare(SpatialNavigation.next(tiles, "left", "left"), "left")
    compare(SpatialNavigation.sequential([], "", 1), "")
  }
}
