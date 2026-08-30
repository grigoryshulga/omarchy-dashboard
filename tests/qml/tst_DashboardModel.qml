import QtQuick
import QtTest
import "../.." as Dashboard
import "../../DashboardAppearance.js" as DashboardAppearance
import "../../DashboardModel.js" as DashboardModel
import "../../GridEngine.js" as GridEngine
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

  function test_grid_spacing_is_configurable_and_bounded() {
    var state = DashboardModel.defaultState()
    state = DashboardModel.apply(state, { type: "setGridSpacing", value: 25 })
    compare(state.gridSpacing, 25)
    state = DashboardModel.apply(state, { type: "setGridSpacing", value: 2 })
    compare(state.gridSpacing, DashboardModel.MIN_GRID_SPACING)
    state = DashboardModel.apply(state, { type: "setGridSpacing", value: 999 })
    compare(state.gridSpacing, DashboardModel.MAX_GRID_SPACING)
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
