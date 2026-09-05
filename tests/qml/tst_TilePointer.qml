import QtQuick
import QtTest
import "../../qml/ui" as DashboardUi

TestCase {
  id: test
  name: "TilePointer"
  when: windowShown
  visible: true
  width: 900
  height: 600

  QtObject {
    id: fakePlugins
    property string kind: "embedded"
    function presentation(tile) {
      return { kind: kind, state: "ready", canLaunch: true, active: false, name: "Test", icon: "x",
        contentLayout: "edge-to-edge", available: ["embedded", "launcher"],
        source: kind === "embedded" ? Qt.resolvedUrl("../fixtures/InteractivePage.qml") : "" }
    }
    function inject(page, tile) { return true }
    function deactivate(page, reason) {}
    function focusPage(page) { page.forceActiveFocus() }
    function sizeHints(id, width, height) { return { minW: 120, minH: 100 } }
    function requestAdaptation(id) {}
  }

  QtObject {
    id: fakeDashboard
    property var plugins: fakePlugins
    property string selectedTileId: ""
    property string mode: "browse"
    property string overlay: ""
    property bool placingPlugin: false
    property bool placingDivider: false
    property bool shortcutHintsVisible: false
    property var dashboardState: ({ gridSpacing: 30 })
    property var activeTiles: []
    property int activations: 0
    function keyboardShortcutForTile(id) { return "1" }
    function selectTileId(id) { selectedTileId = id }
    function activateTile(tile) {
      selectedTileId = tile.id
      activations += 1
      if (fakePlugins.kind === "embedded") mode = "interact"
      return true
    }
    function placeTile(id, rect) {}
  }

  Component {
    id: tileComponent
    DashboardUi.TileHost {
      dashboard: fakeDashboard
      canvas: test
      tileId: "one"
      tilePluginId: "plugin.one"
      tileLabel: "Test"
      tileEmbedding: "auto"
      tileX: 30
      tileY: 30
      tileW: 300
      tileH: 240
      gridWidth: test.width
      gridHeight: test.height
      surfaceActive: true
    }
  }

  Shortcut {
    sequence: "Escape"
    enabled: fakeDashboard.mode === "interact"
    onActivated: fakeDashboard.mode = "browse"
  }

  function init() {
    fakePlugins.kind = "embedded"
    fakeDashboard.mode = "browse"
    fakeDashboard.selectedTileId = ""
    fakeDashboard.overlay = ""
    fakeDashboard.placingPlugin = false
    fakeDashboard.placingDivider = false
    fakeDashboard.activations = 0
    mouseMove(test, 880, 580)
  }

  function createTile(properties) {
    var tile = createTemporaryObject(tileComponent, test, properties || {})
    verify(tile !== null)
    if (fakePlugins.kind === "embedded") tryVerify(function() { return tile.loadedPage !== null })
    return tile
  }

  function test_hover_selects_and_one_click_enters_interaction_without_firing_plugin_action() {
    var tile = createTile()
    mouseMove(tile, 100, 100)
    compare(fakeDashboard.selectedTileId, "one")
    compare(fakeDashboard.mode, "browse")
    verify(!tile.loadedPage.activeFocus)
    mouseClick(tile, 100, 100)
    compare(fakeDashboard.mode, "interact")
    tryVerify(function() { return tile.loadedPage.activeFocus })
    compare(tile.loadedPage.clicks, 0)
    compare(tile.frameWidth, 3)
    mouseClick(tile, 100, 100)
    compare(tile.loadedPage.clicks, 1)
    keyClick(Qt.Key_Escape)
    compare(fakeDashboard.mode, "browse")
    compare(tile.frameWidth, 1)
  }

  function test_hover_another_tile_exits_previous_interaction_without_activating_next() {
    var one = createTile()
    var two = createTile({ tileId: "two", tilePluginId: "plugin.two", tileX: 380 })
    mouseClick(one, 100, 100)
    mouseMove(two, 100, 100)
    compare(fakeDashboard.selectedTileId, "two")
    compare(fakeDashboard.mode, "browse")
    verify(!one.interacting)
    verify(!two.interacting)
    mouseClick(two, 100, 100)
    tryVerify(function() { return two.loadedPage.activeFocus })
    verify(two.interacting)
  }

  function test_hover_during_plugin_drag_does_not_steal_selection() {
    var one = createTile()
    var two = createTile({ tileId: "two", tilePluginId: "plugin.two", tileX: 380 })
    mouseClick(one, 100, 100)
    mousePress(one, 100, 100)
    mouseMove(two, 100, 100)
    compare(fakeDashboard.selectedTileId, "one")
    compare(fakeDashboard.mode, "interact")
    mouseRelease(two, 100, 100)
  }

  function test_stationary_pointer_does_not_undo_keyboard_selection() {
    var one = createTile()
    var two = createTile({ tileId: "two", tilePluginId: "plugin.two", tileX: 380 })
    mouseMove(one, 100, 100)
    compare(fakeDashboard.selectedTileId, "one")
    fakeDashboard.selectTileId("two")
    wait(20)
    compare(fakeDashboard.selectedTileId, "two")
    mouseMove(one, 110, 110)
    compare(fakeDashboard.selectedTileId, "one")
  }

  function test_edit_overlay_and_placement_do_not_activate_on_hover() {
    var tile = createTile()
    fakeDashboard.mode = "edit"
    mouseMove(tile, 100, 100)
    compare(fakeDashboard.selectedTileId, "")
    fakeDashboard.mode = "browse"
    fakeDashboard.overlay = "plugin"
    mouseMove(tile, 120, 120)
    mouseClick(tile, 120, 120)
    compare(fakeDashboard.activations, 0)
    fakeDashboard.overlay = ""
    fakeDashboard.placingPlugin = true
    mouseMove(tile, 140, 140)
    mouseClick(tile, 140, 140)
    compare(fakeDashboard.activations, 0)
  }

  function test_launcher_keeps_its_single_click_action() {
    fakePlugins.kind = "launcher"
    var tile = createTile()
    mouseMove(tile, 100, 100)
    compare(fakeDashboard.activations, 0)
    mouseClick(tile, 100, 100)
    compare(fakeDashboard.activations, 1)
    compare(fakeDashboard.mode, "browse")
  }

  function test_control_click_exits_previous_interaction_even_without_hover() {
    fakePlugins.kind = "control"
    var tile = createTile()
    fakeDashboard.mode = "interact"
    fakeDashboard.selectedTileId = "another"
    mouseClick(tile, 100, 100)
    compare(fakeDashboard.activations, 1)
    compare(fakeDashboard.mode, "browse")
    verify(!tile.interacting)
    mouseClick(tile, 100, 100)
    compare(fakeDashboard.activations, 2)
  }
}
