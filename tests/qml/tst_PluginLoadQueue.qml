import QtQuick
import QtTest
import "../../qml/plugins" as Plugins
import "../../qml/plugins/PluginLoadOrder.js" as PluginLoadOrder

TestCase {
  name: "PluginLoadQueue"

  Plugins.DashboardSessionTiles {
    id: queue
    preloadInterval: 100000
  }

  function tile(id) { return { id: id, pluginId: "plugin." + id } }
  function ids(tiles) { return tiles.map(function(tile) { return tile.id }).join(",") }

  function init() {
    queue.opened = false
    queue.spaces = [
      { id: "one", tiles: [tile("a")] },
      { id: "two", tiles: [tile("b"), tile("b2")] },
      { id: "three", tiles: [tile("c"), tile("c2")] }
    ]
    queue.activeSpaceId = "one"
    queue.opened = true
  }

  function cleanup() { queue.opened = false }

  function test_background_admits_one_page_only_after_current_work_settles() {
    compare(ids(queue.tiles), "a")
    queue.preloadNext()
    compare(ids(queue.tiles), "a")
    queue.reportSettled("a", true)
    queue.preloadNext()
    compare(ids(queue.tiles), "a,b")
    compare(queue.loadingCount, 1)
    queue.preloadNext()
    compare(ids(queue.tiles), "a,b")
    queue.reportSettled("b", true)
    queue.preloadNext()
    compare(ids(queue.tiles), "a,b,b2")
  }

  function test_new_foreground_bypasses_background_work_already_in_progress() {
    queue.reportSettled("a", true)
    queue.preloadNext()
    // b has started, b2 is still waiting when the user visits the third Space.
    queue.activeSpaceId = "three"
    compare(ids(queue.tiles), "c,c2,a,b")
    compare(queue.loadingCount, 3)
    compare(queue.queuedCount, 1)
    queue.reportSettled("c", true)
    queue.reportSettled("c2", true)
    queue.preloadNext()
    compare(queue.queuedCount, 1)
    queue.reportSettled("b", true)
    queue.preloadNext()
    compare(queue.queuedCount, 0)
    compare(ids(queue.tiles), "c,c2,a,b,b2")
  }

  function test_adaptation_order_tracks_each_space_switch_without_duplicate_work() {
    compare(ids(PluginLoadOrder.prioritize(queue.spaces, "one")), "a,b,b2,c,c2")
    compare(ids(PluginLoadOrder.prioritize(queue.spaces, "three")), "c,c2,a,b,b2")
    compare(ids(PluginLoadOrder.prioritize(queue.spaces, "two")), "b,b2,a,c,c2")
    queue.activeSpaceId = "three"
    queue.activeSpaceId = "two"
    compare(queue.tiles.length, 5)
    compare(queue.queuedCount, 0)
  }

  function test_removing_an_inflight_tile_releases_queue_and_ignores_late_results() {
    queue.reportSettled("a", true)
    queue.preloadNext()
    queue.spaces = [
      { id: "one", tiles: [tile("a")] },
      { id: "three", tiles: [tile("c")] }
    ]
    compare(ids(queue.tiles), "a")
    compare(queue.loadingCount, 0)
    queue.reportSettled("b", true)
    verify(queue.settledIds.b === undefined)
    queue.preloadNext()
    compare(ids(queue.tiles), "a,c")
  }

  function test_close_clears_queue_and_reopen_uses_the_current_space_first() {
    queue.reportSettled("a", true)
    queue.preloadNext()
    queue.opened = false
    queue.preloadNext()
    queue.reportSettled("b", true)
    compare(queue.tiles.length, 0)
    compare(queue.queuedCount, 0)
    compare(queue.loadingCount, 0)
    queue.activeSpaceId = "three"
    queue.opened = true
    compare(ids(queue.tiles), "c,c2")
    compare(queue.loadingCount, 2)
  }
}
