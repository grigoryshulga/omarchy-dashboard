import QtQuick
import QtTest
import "../../qml/plugins" as Plugins

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
    property string failedTileId: ""
    property string waitingControlId: ""
    function presentation(tile) {
      if (tile.id === waitingControlId) return {
        kind: "control", state: "preparing", name: "Waiting service", active: false,
        icon: "x", contentLayout: "padded", available: ["control"]
      }
      return { kind: "embedded", state: "ready", name: "Test", icon: "x",
        contentLayout: "padded", available: ["embedded"],
        source: Qt.resolvedUrl("../fixtures/InteractivePage.qml") }
    }
    function inject(page, tile) { initialized += 1; return tile.id !== failedTileId }
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

  Plugins.DashboardSessionTiles {
    id: session
    opened: fakeDashboard.opened
    spaces: test.spaces
    activeSpaceId: test.activeSpaceId
  }

  Plugins.DashboardTileCollection {
    id: collection
    tiles: session.tiles
  }

  Repeater {
    id: tiles
    model: collection.model
    delegate: Plugins.TileHost {
      required property string tileSpaceId
      dashboard: fakeDashboard
      canvas: test
      gridWidth: test.width
      gridHeight: test.height
      visible: tileSpaceId === test.activeSpaceId
      surfaceActive: fakeDashboard.opened && visible
      keepLoaded: fakeDashboard.opened
      onLoadSettledChanged: session.reportSettled(tileId, loadSettled)
      Component.onCompleted: session.reportSettled(tileId, loadSettled)
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
    session.preloadInterval = 100000
    fakeDashboard.mode = "browse"
    test.activeSpaceId = "one"
    test.spaces = [
      { id: "one", tiles: [tile("a")] },
      { id: "two", tiles: [tile("b")] },
      { id: "three", tiles: [tile("c")] }
    ]
    fakePlugins.initialized = 0
    fakePlugins.deactivated = 0
    fakePlugins.failedTileId = ""
    fakePlugins.waitingControlId = ""
    mouseMove(test, 880, 580)
  }

  function cleanup() { fakeDashboard.opened = false }

  function test_foreground_pages_keep_their_instances_until_close() {
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

  function test_background_preloads_every_space_and_keeps_hidden_pages_passive() {
    session.preloadInterval = 1
    fakeDashboard.opened = true
    tryCompare(fakePlugins, "initialized", 3)
    compare(session.queuedCount, 0)
    compare(session.loadingCount, 0)
    var second = loaded("b")
    var secondPage = second.loadedPage
    secondPage.clicks = 42
    verify(!second.visible)
    verify(!second.interacting)
    verify(!second.pointerEnabled)
    test.activeSpaceId = "two"
    compare(hosted("b"), second)
    compare(second.loadedPage, secondPage)
    compare(second.loadedPage.clicks, 42)
    compare(fakePlugins.initialized, 3)
    fakeDashboard.opened = false
    compare(tiles.count, 0)
    compare(fakePlugins.deactivated, 3)
    compare(session.queuedCount, 0)
    compare(session.loadingCount, 0)
  }

  function test_failed_page_does_not_block_preloading_remaining_spaces() {
    fakePlugins.failedTileId = "a"
    session.preloadInterval = 1
    fakeDashboard.opened = true
    tryCompare(fakePlugins, "initialized", 3)
    verify(hosted("a").pageError !== "")
    loaded("b")
    loaded("c")
    compare(session.loadingCount, 0)
  }

  function test_service_readiness_does_not_hold_the_page_loading_queue() {
    fakePlugins.waitingControlId = "a"
    session.preloadInterval = 1
    fakeDashboard.opened = true
    loaded("b")
    loaded("c")
    compare(fakePlugins.initialized, 2)
    compare(session.loadingCount, 0)
  }

  function test_layout_edits_preserve_instances_and_enqueue_new_hidden_plugins() {
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
    compare(session.queuedCount, 1)
    session.preloadNext()
    var added = loaded("new")
    verify(!added.visible)
    compare(session.queuedCount, 0)
  }

  function test_close_during_async_load_leaves_no_resident_tiles() {
    fakeDashboard.opened = true
    fakeDashboard.opened = false
    wait(30)
    compare(tiles.count, 0)
    compare(fakePlugins.initialized, fakePlugins.deactivated)
  }
}
