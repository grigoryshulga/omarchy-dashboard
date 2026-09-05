import QtQuick
import QtTest
import "../../qml/layout" as Layout

TestCase {
  id: test
  name: "PlacementActions"
  when: windowShown
  visible: true
  width: 800
  height: 600

  QtObject {
    id: dashboard
    property var placementDraft: null
    property bool placingPlugin: placementDraft !== null
    property bool placementValid: true
    property string mode: "edit"
    property var dashboardState: ({ gridSpacing: 10 })
    property int added: 0
    property int removed: 0
    property int presentationChanges: 0
    function confirmPluginPlacement() { added += 1 }
    function cancelPluginPlacement() { removed += 1 }
    function cyclePlacementPresentation() { presentationChanges += 1 }
    function updatePlacementRect(rect) {
      placementDraft = Object.assign({}, placementDraft, { rect: rect })
    }
  }

  Layout.PlacementGhost {
    id: ghost
    dashboard: dashboard
    canvas: test
  }

  function init() {
    dashboard.placementDraft = {
      pluginId: "test.plugin", label: "Test plugin", embedding: "auto", minW: 100, minH: 100,
      rect: { x: 40, y: 40, w: 400, h: 240 }
    }
    dashboard.placementValid = true
    dashboard.added = 0
    dashboard.removed = 0
    dashboard.presentationChanges = 0
    mouseMove(test, 780, 580)
    waitForRendering(ghost)
  }

  function clickAction(name) {
    waitForPolish(findChild(ghost, "tileEditActions"))
    var button = findChild(ghost, name)
    verify(button !== null)
    mouseClick(button, button.width / 2, button.height / 2)
  }

  function cleanup() { dashboard.placementDraft = null }

  function test_icon_tooltip_names_the_action_without_expanding_the_button() {
    var button = findChild(ghost, "tilePresentationButton")
    var tooltip = findChild(button, "editActionTooltip")
    var originalWidth = button.width
    mouseMove(button, button.width / 2, button.height / 2)
    tryCompare(tooltip, "opened", true)
    compare(tooltip.text, "Change display mode · Auto")
    compare(button.width, originalWidth)
    compare(dashboard.presentationChanges, 0)
    dashboard.placementDraft = Object.assign({}, dashboard.placementDraft, { embedding: "launcher" })
    compare(tooltip.text, "Change display mode · Launcher")
    mouseMove(test, 780, 580)
    tryCompare(tooltip, "opened", false)
  }

  function test_silhouette_has_centered_actions_without_starting_a_drag() {
    var actions = findChild(ghost, "tileEditActions")
    var center = actions.mapToItem(ghost, actions.width / 2, actions.height / 2)
    compare(center.x, ghost.width / 2)
    compare(center.y, ghost.height / 2)
    clickAction("tilePresentationButton")
    compare(dashboard.presentationChanges, 1)
    compare(ghost.startRect, null)
    clickAction("addTileButton")
    compare(dashboard.added, 1)
    compare(ghost.startRect, null)
    clickAction("deleteTileButton")
    compare(dashboard.removed, 1)
    compare(dashboard.mode, "edit")
  }

  function test_invalid_placement_cannot_be_added_but_can_be_changed_or_discarded() {
    dashboard.placementValid = false
    verify(!findChild(ghost, "addTileButton").enabled)
    clickAction("addTileButton")
    compare(dashboard.added, 0)
    clickAction("tilePresentationButton")
    compare(dashboard.presentationChanges, 1)
    clickAction("deleteTileButton")
    compare(dashboard.removed, 1)
  }

  function test_actions_fit_compact_silhouettes_and_keep_resize_edges_free() {
    dashboard.updatePlacementRect({ x: 40, y: 40, w: 100, h: 100 })
    waitForPolish(findChild(ghost, "tileEditActions"))
    var names = ["deleteTileButton", "tilePresentationButton", "addTileButton"]
    for (var index = 0; index < names.length; index++) {
      var button = findChild(ghost, names[index])
      var position = button.mapToItem(ghost, 0, 0)
      verify(position.x >= ghost.resizeHandleWidth)
      verify(position.x + button.width <= ghost.width - ghost.resizeHandleWidth)
      verify(position.y >= ghost.resizeHandleWidth)
      verify(position.y + button.height <= ghost.height - ghost.resizeHandleWidth)
    }
    clickAction("addTileButton")
    compare(dashboard.added, 1)
  }

  function test_draft_can_still_be_moved_by_its_background() {
    mousePress(ghost, 40, 30)
    verify(ghost.startRect !== null)
    mouseMove(ghost, 70, 60)
    mouseRelease(ghost, 70, 60)
    verify(dashboard.placementDraft.rect.x > 40)
    compare(ghost.startRect, null)
  }
}
