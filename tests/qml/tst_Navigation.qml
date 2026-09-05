import QtQuick
import QtTest
import "../../qml/navigation/SpatialNavigation.js" as SpatialNavigation
import "../../qml/navigation/SpaceSwipe.js" as SpaceSwipe
import "../../qml/navigation" as Navigation

TestCase {
  name: "Navigation"
  when: windowShown

  function tile(id, x, y, w, h) {
    return { id: id, pluginId: "plugin." + id, x: x, y: y, w: w, h: h }
  }

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

  QtObject {
    id: tileShortcutDashboard
    property string overlay: ""
    property string mode: "browse"
    property bool placingPlugin: false
    property bool placingDivider: false
    property string selectedDirection: ""
    function selectTile(direction) { selectedDirection = direction }
  }

  QtObject {
    id: globalShortcutDashboard
    property string overlay: ""
    property string mode: "edit"
    property bool placingPlugin: false
    property bool placingDivider: false
    property string selectedTileId: "tile"
    property string selectedElementId: ""
    property bool placementValid: true
    property int addedTiles: 0
    property int discardedDrafts: 0
    property int removedTiles: 0
    property int moveCalls: 0
    property int resizeCalls: 0
    function moveSelectedItemByGrid(dx, dy) { moveCalls += 1 }
    function resizeSelectedItemByGrid(dw, dh) { resizeCalls += 1 }
    function moveSpace(delta) { moveCalls += 1 }
    function confirmPluginPlacement() { addedTiles += 1; placingPlugin = false; selectedTileId = "added" }
    function cancelPluginPlacement() { discardedDrafts += 1; placingPlugin = false }
    function removeTile(id) { removedTiles += 1; selectedTileId = "" }
  }

  QtObject {
    id: globalShortcutSurface
    property int focusRequests: 0
    function retainKeyboardFocus() { focusRequests += 1 }
    function beginCreate() {}
    function beginRename() {}
    function requestSpaceRemoval() {}
  }

  Navigation.DashboardSpaceShortcuts {
    id: spaceShortcuts
    dashboard: shortcutDashboard
    active: true
  }

  Navigation.DashboardTileNavigationShortcuts {
    id: tileNavigationShortcuts
    dashboard: tileShortcutDashboard
    active: true
  }

  Navigation.DashboardGlobalShortcuts {
    id: globalShortcuts
    dashboard: globalShortcutDashboard
    surface: globalShortcutSurface
    active: true
  }

  Item {
    id: shortcutFocusSink
    focus: true
    Keys.onPressed: function(event) { event.accepted = true }
  }

  function test_space_swipe_requires_a_deliberate_horizontal_motion() {
    compare(SpaceSwipe.directionForTranslation(95, 0), 0)
    compare(SpaceSwipe.directionForTranslation(96, 96), 0)
    compare(SpaceSwipe.directionForTranslation(160, 170), 0)
    compare(SpaceSwipe.directionForTranslation(-140, 20), 1)
    compare(SpaceSwipe.directionForTranslation(140, 20), -1)
  }

  function test_space_shortcut_dispatcher_selects_the_requested_space() {
    shortcutDashboard.overlay = ""
    shortcutDashboard.selectedSpaceId = ""
    spaceShortcuts.activateSpace(1)
    compare(shortcutDashboard.selectedSpaceId, "two")
  }

  function test_tile_navigation_shortcut_dispatches_in_browse_mode() {
    tileShortcutDashboard.selectedDirection = ""
    tileNavigationShortcuts.select("left")
    compare(tileShortcutDashboard.selectedDirection, "left")
  }

  function test_global_shortcuts_dispatch_repeated_edit_commands_without_item_focus() {
    globalShortcutDashboard.moveCalls = 0
    globalShortcutDashboard.resizeCalls = 0
    globalShortcutSurface.focusRequests = 0
    globalShortcuts.move("left")
    globalShortcuts.move("left")
    globalShortcuts.resize("right")
    globalShortcuts.resize("right")
    compare(globalShortcutDashboard.moveCalls, 2)
    compare(globalShortcutDashboard.resizeCalls, 2)
    compare(globalShortcutSurface.focusRequests, 4)
  }

  function test_enter_places_and_delete_removes_without_leaving_edit_mode() {
    globalShortcutDashboard.mode = "edit"
    globalShortcutDashboard.placingPlugin = true
    globalShortcutDashboard.placementValid = true
    globalShortcutDashboard.addedTiles = 0
    globalShortcutDashboard.removedTiles = 0
    shortcutFocusSink.forceActiveFocus()
    keyClick(Qt.Key_Return)
    compare(globalShortcutDashboard.addedTiles, 1)
    verify(!globalShortcutDashboard.placingPlugin)
    compare(globalShortcutDashboard.mode, "edit")
    keyClick(Qt.Key_Delete)
    compare(globalShortcutDashboard.removedTiles, 1)
    compare(globalShortcutDashboard.mode, "edit")
    globalShortcutDashboard.selectedTileId = "tile"
  }

  function test_delete_discards_draft_and_enter_rejects_collisions_and_dialogs() {
    globalShortcutDashboard.mode = "edit"
    globalShortcutDashboard.placingPlugin = true
    globalShortcutDashboard.placementValid = false
    globalShortcutDashboard.addedTiles = 0
    globalShortcutDashboard.discardedDrafts = 0
    globalShortcutDashboard.removedTiles = 0
    shortcutFocusSink.forceActiveFocus()
    keyClick(Qt.Key_Return)
    compare(globalShortcutDashboard.addedTiles, 0)
    verify(globalShortcutDashboard.placingPlugin)
    globalShortcutDashboard.overlay = "text-editor"
    keyClick(Qt.Key_Delete)
    compare(globalShortcutDashboard.discardedDrafts, 0)
    globalShortcutDashboard.overlay = ""
    keyClick(Qt.Key_Delete)
    compare(globalShortcutDashboard.discardedDrafts, 1)
    compare(globalShortcutDashboard.removedTiles, 0)
    compare(globalShortcutDashboard.mode, "edit")
    globalShortcutDashboard.placementValid = true
    globalShortcutDashboard.placingPlugin = true
    keyClick(Qt.Key_Enter)
    compare(globalShortcutDashboard.addedTiles, 1)
    compare(globalShortcutDashboard.mode, "edit")
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
    compare(SpatialNavigation.sequential(tiles, "down", 1), "up")
    compare(SpatialNavigation.next(tiles, "left", "left"), "left")
    compare(SpatialNavigation.sequential([], "", 1), "")
  }

  function test_spatial_navigation_prefers_an_actual_neighbour_in_the_direction() {
    var tiles = [
      tile("current", 400, 300, 100, 100),
      tile("direct-left", 0, 300, 100, 100),
      tile("nearby-diagonal", 350, 0, 100, 100),
      tile("direct-right", 800, 300, 100, 100),
      tile("nearby-right-diagonal", 450, 650, 100, 100)
    ]
    compare(SpatialNavigation.next(tiles, "current", "left"), "direct-left")
    compare(SpatialNavigation.next(tiles, "current", "right"), "direct-right")
  }

  function test_keyboard_shortcuts_follow_reading_order() {
    var tiles = [
      tile("second", 400, 0, 100, 100),
      tile("fourth", 400, 200, 100, 100),
      tile("first", 0, 0, 100, 100),
      tile("third", 0, 200, 100, 100)
    ]
    var ordered = SpatialNavigation.readingOrder(tiles)
    compare(ordered.map(function(entry) { return entry.id }).join(","), "first,second,third,fourth")
    compare(SpatialNavigation.shortcutLabel(0), "1")
    compare(SpatialNavigation.shortcutLabel(8), "9")
    compare(SpatialNavigation.shortcutLabel(9), "A")
    compare(SpatialNavigation.shortcutLabel(34), "Z")
    compare(SpatialNavigation.shortcutIndexForKey("3".charCodeAt(0)), 2)
    compare(SpatialNavigation.shortcutIndexForKey("C".charCodeAt(0)), 11)
  }
}
