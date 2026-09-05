import QtQuick
import QtTest
import "../../qml/state/DashboardModel.js" as DashboardModel
import "../../qml/layout/GridEngine.js" as GridEngine
import "../../qml/plugins/HostPlacements.js" as HostPlacements

TestCase {
  name: "DashboardModel"
  when: windowShown

  function tile(id, x, y, w, h) {
    return { id: id, pluginId: "plugin." + id, x: x, y: y, w: w, h: h }
  }

  function test_tile_background_defaults_on_and_survives_storage_and_placement_changes() {
    var state = DashboardModel.apply(DashboardModel.defaultState(), {
      type: "addTile", id: "one", pluginId: "plugin.one",
      rect: { x: 0, y: 0, w: 120, h: 100 }
    }, 800, 600)
    compare(state.spaces[0].tiles[0].background, true)
    state = DashboardModel.apply(state, {
      type: "setTileBackground", tileId: "one", background: false
    }, 800, 600)
    state = DashboardModel.normalize(JSON.parse(DashboardModel.serialize(state)))
    compare(state.spaces[0].tiles[0].background, false)
    var pending = DashboardModel.managePlacement(state, {
      operation: "pending", pluginId: "plugin.one"
    }, 800, 600)
    verify(pending.ok)
    compare(pending.placement.background, false)
    var placed = DashboardModel.managePlacement(pending.state, {
      operation: "place", pluginId: "plugin.one", spaceId: "space-main",
      rect: { x: 150, y: 0, w: 120, h: 100 }
    }, 800, 600)
    verify(placed.ok)
    compare(placed.placement.background, false)
    state = DashboardModel.apply(placed.state, {
      type: "setTileBackground", tileId: "one", background: true
    }, 800, 600)
    compare(state.spaces[0].tiles[0].background, true)
  }

  function test_reserved_and_structurally_unsafe_ids_are_rejected() {
    var state = DashboardModel.normalize({
      version: DashboardModel.VERSION,
      activeSpaceId: "space-main",
      spaces: [
        { id: "constructor", name: "Unsafe", tiles: [], elements: [] },
        { id: "space-main", name: "Main", tiles: [
          { id: "valid-tile", pluginId: "../escape", x: 0, y: 0, w: 100, h: 100 },
          { id: "__proto__", pluginId: "valid.plugin", x: 0, y: 0, w: 100, h: 100 }
        ], elements: [] }
      ]
    })
    compare(state.spaces.length, 1)
    compare(state.spaces[0].id, "space-main")
    compare(state.spaces[0].tiles.length, 0)

    var config = ({})
    verify(HostPlacements.synchronize(config, "gshulga.dashboard", [
      { id: "constructor", instanceId: "valid-instance", slot: "space-main" },
      { id: "valid.plugin", instanceId: "__proto__", slot: "space-main" }
    ]))
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

  function test_tile_can_resize_from_left_and_top_edges() {
    var state = DashboardModel.normalize({
      version: DashboardModel.VERSION,
      activeSpaceId: "main",
      spaces: [{ id: "main", name: "Main", tiles: [tile("resizable", 100, 100, 200, 200)] }]
    })
    state = DashboardModel.apply(state, {
      type: "placeTile", spaceId: "main", tileId: "resizable",
      rect: { x: 50, y: 70, w: 250, h: 230 }
    }, 800, 600)
    compare(state.spaces[0].tiles[0].x, 50)
    compare(state.spaces[0].tiles[0].y, 70)
    compare(state.spaces[0].tiles[0].w, 250)
    compare(state.spaces[0].tiles[0].h, 230)
  }

  function test_launcher_tiles_can_resize_to_the_grid_minimum() {
    var state = DashboardModel.normalize({
      version: DashboardModel.VERSION,
      activeSpaceId: "main",
      spaces: [{ id: "main", name: "Main", tiles: [tile("launcher", 0, 0, 120, 120)] }]
    })
    state = DashboardModel.apply(state, {
      type: "resizeTile", spaceId: "main", tileId: "launcher", dw: -1000, dh: -1000,
      minW: GridEngine.MIN_WIDTH, minH: GridEngine.MIN_HEIGHT
    }, 800, 600)
    compare(state.spaces[0].tiles[0].w, GridEngine.MIN_WIDTH)
    compare(state.spaces[0].tiles[0].h, GridEngine.MIN_HEIGHT)
  }

  function test_control_tiles_can_resize_to_the_grid_minimum() {
    var state = DashboardModel.normalize({
      version: DashboardModel.VERSION,
      activeSpaceId: "main",
      spaces: [{ id: "main", name: "Main", tiles: [tile("control", 0, 0, 120, 120)] }]
    })
    state = DashboardModel.apply(state, {
      type: "resizeTile", spaceId: "main", tileId: "control", dw: -1000, dh: -1000,
      minW: GridEngine.MIN_WIDTH, minH: GridEngine.MIN_HEIGHT
    }, 800, 600)
    compare(state.spaces[0].tiles[0].w, GridEngine.MIN_WIDTH)
    compare(state.spaces[0].tiles[0].h, GridEngine.MIN_HEIGHT)
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
}
