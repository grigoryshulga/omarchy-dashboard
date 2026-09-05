import QtQuick
import QtTest
import "../../qml/ui" as DashboardUi

TestCase {
  id: test
  name: "DashboardSession"
  when: windowShown
  visible: true
  width: 900
  height: 600
  property var spaces: []
  property string activeSpaceId: "one"

  QtObject {
    id: fakePlugins
    property int initialized: 0
    property int deactivated: 0
    function presentation(tile) {
      return { kind: "embedded", state: "ready", name: "Test", icon: "x",
        contentLayout: "padded", available: ["embedded"],
        source: Qt.resolvedUrl("../fixtures/InteractivePage.qml") }
    }
    function inject(page, tile) { initialized += 1; return true }
    function deactivate(page, reason) { deactivated += 1 }
    function focusPage(page) { page.forceActiveFocus() }
    function requestAdaptation(id) {}
  }

  QtObject {
    id: fakeDashboard
    property var plugins: fakePlugins
    property bool opened: false
    property string selectedTileId: "a"
    property string mode: "browse"
    property string overlay: ""
    property bool placingPlugin: false
    property bool placingDivider: false
    property bool shortcutHintsVisible: false
    property var activeTiles: []
    function keyboardShortcutForTile(id) { return "1" }
    function selectTileId(id) { selectedTileId = id }
  }

  DashboardUi.DashboardSessionTiles {
    id: session
    opened: fakeDashboard.opened
    spaces: test.spaces
    activeSpaceId: test.activeSpaceId
  }

  DashboardUi.DashboardTileCollection {
    id: collection
    tiles: session.tiles
  }

  Repeater {
    id: tiles
    model: collection.model
    delegate: DashboardUi.TileHost {
      required property string tileSpaceId
      dashboard: fakeDashboard
      canvas: test
      gridWidth: test.width
      gridHeight: test.height
      visible: tileSpaceId === test.activeSpaceId
      surfaceActive: fakeDashboard.opened && visible
      keepLoaded: fakeDashboard.opened
    }
  }

  function tile(id) { return { id: id, pluginId: "plugin." + id, x: 30, y: 30, w: 300, h: 240 } }
  function hosted(id) {
    for (var index = 0; index < tiles.count; index++)
      if (tiles.itemAt(index).tileId === id) return tiles.itemAt(index)
    return null
  }
  function loaded(id) {
    tryVerify(function() { return hosted(id) && hosted(id).loadedPage !== null })
    return hosted(id)
  }

  function init() {
    fakeDashboard.opened = false
    fakeDashboard.mode = "browse"
    test.activeSpaceId = "one"
    test.spaces = [
      { id: "one", tiles: [tile("a")] },
      { id: "two", tiles: [tile("b")] },
      { id: "three", tiles: [tile("c")] }
    ]
    fakePlugins.initialized = 0
    fakePlugins.deactivated = 0
    mouseMove(test, 880, 580)
  }

  function cleanup() { fakeDashboard.opened = false }

  function test_loads_only_visited_pages_and_preserves_plugin_state_until_close() {
    compare(tiles.count, 0)
    fakeDashboard.opened = true
    var first = loaded("a")
    var firstPage = first.loadedPage
    firstPage.clicks = 42
    compare(tiles.count, 1)
    compare(fakePlugins.initialized, 1)
    test.activeSpaceId = "two"
    loaded("b")
    compare(tiles.count, 2)
    compare(hosted("c"), null)
    compare(first.loadedPage, firstPage)
    verify(!first.visible)
    verify(!first.pointerEnabled)
    fakeDashboard.mode = "interact"
    verify(!first.interacting)
    compare(fakePlugins.deactivated, 0)
    test.activeSpaceId = "one"
    compare(hosted("a"), first)
    compare(first.loadedPage, firstPage)
    compare(first.loadedPage.clicks, 42)
    compare(fakePlugins.initialized, 2)
    fakeDashboard.opened = false
    compare(tiles.count, 0)
    compare(fakePlugins.deactivated, 2)
    fakeDashboard.opened = true
    var reopened = loaded("a")
    compare(reopened.loadedPage.clicks, 0)
    compare(tiles.count, 1)
    compare(fakePlugins.initialized, 3)
  }

  function test_layout_edits_preserve_other_instances_and_keep_new_hidden_plugins_lazy() {
    fakeDashboard.opened = true
    var first = loaded("a")
    test.activeSpaceId = "two"
    var second = loaded("b")
    test.activeSpaceId = "one"
    test.spaces = [
      { id: "two", tiles: [tile("b"), tile("new")] },
      { id: "one", tiles: [tile("a")] },
      { id: "three", tiles: [tile("c")] }
    ]
    compare(hosted("a"), first)
    compare(hosted("b"), second)
    compare(hosted("new"), null)
    compare(fakePlugins.initialized, 2)
    test.spaces = [
      { id: "two", tiles: [tile("b"), tile("new")] },
      { id: "one", tiles: [] },
      { id: "three", tiles: [tile("a"), tile("c")] }
    ]
    compare(hosted("a"), first)
    compare(first.tileSpaceId, "three")
    verify(!first.visible)
    compare(fakePlugins.deactivated, 0)
    test.activeSpaceId = "three"
    loaded("c")
    compare(hosted("a"), first)
    test.spaces = [
      { id: "two", tiles: [tile("b"), tile("new")] },
      { id: "three", tiles: [tile("c")] }
    ]
    compare(hosted("a"), null)
    compare(hosted("b"), second)
    compare(fakePlugins.deactivated, 1)
    compare(hosted("new"), null)
  }

  function test_close_during_async_load_leaves_no_resident_tiles() {
    fakeDashboard.opened = true
    fakeDashboard.opened = false
    wait(30)
    compare(tiles.count, 0)
    compare(fakePlugins.initialized, fakePlugins.deactivated)
  }
}
