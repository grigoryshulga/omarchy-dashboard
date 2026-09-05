import QtQuick
import QtTest
import "../../qml/commands" as Commands
import "../../qml/state/DashboardModel.js" as DashboardModel

TestCase {
  id: test
  name: "DashboardManagement"
  property var events: []

  QtObject {
    id: store
    property var document: DashboardModel.defaultState()
    property bool ready: true
    property bool acceptDocument: true
    function replaceDocument(next) {
      test.events.push("stage")
      if (!acceptDocument) return false
      document = DashboardModel.normalize(next)
      return true
    }
    function flush() { test.events.push("flush") }
  }

  QtObject {
    id: plugins
    property bool acceptTransaction: true
    property bool installed: true
    function descriptor(id) {
      return installed ? { id: id, name: "Test plugin", manifest: { id: id } } : null
    }
    function sizeHints(id, width, height) {
      return { minW: 100, minH: 100, preferredW: 200, preferredH: 200 }
    }
    function applyHostPlacementTransaction(document, enablingId, manifest) {
      test.events.push("host")
      return acceptTransaction
    }
  }

  Commands.DashboardManagement {
    id: management
    stateStore: store
    plugins: plugins
    gridWidth: 800
    gridHeight: 600
  }

  function init() {
    store.document = DashboardModel.normalize({
      version: DashboardModel.VERSION, canvasWidth: 800, canvasHeight: 600,
      activeSpaceId: "space-main",
      spaces: [{ id: "space-main", name: "Main", tiles: [], elements: [] }]
    })
    store.ready = true
    store.acceptDocument = true
    plugins.acceptTransaction = true
    plugins.installed = true
    events = []
  }

  function test_requests_validate_readiness_shape_and_protocol_version() {
    store.ready = false
    compare(management.execute({ operation: "list" }).code, "dashboard-loading")
    store.ready = true
    compare(management.execute(null).code, "invalid-request")
    compare(management.execute([]).code, "invalid-request")
    compare(management.execute({ schemaVersion: 2 }).code, "unsupported-schema-version")
    compare(events.length, 0)
  }

  function test_queries_and_grid_updates_use_persisted_dimensions() {
    var list = management.execute({ operation: "list" })
    verify(list.ok)
    compare(list.schemaVersion, 1)
    compare(list.placements.length, 0)
    compare(list.grid, { spacing: 10, width: 800, height: 600 })
    compare(management.execute({ operation: "spaces" }).spaces,
      [{ id: "space-main", name: "Main", active: true }])
    compare(events.length, 0)
    var updated = management.execute({ operation: "grid-set", spacing: 20 })
    verify(updated.ok)
    compare(updated.grid.spacing, 20)
    compare(management.execute({ operation: "grid" }).grid, updated.grid)
    compare(events, ["stage", "flush"])
  }

  function test_space_commands_resolve_names_and_preserve_last_space() {
    verify(management.execute({ operation: "space-create", id: "work", name: "Work" }).ok)
    compare(management.execute({ operation: "space-create", name: "work" }).code, "space-name-conflict")
    var selected = management.execute({ operation: "space-select", space: "WORK" })
    verify(selected.ok)
    compare(selected.space.id, "work")
    compare(store.document.activeSpaceId, "work")
    verify(!management.execute({ operation: "space-select", spaceId: "work" }).changed)
    verify(management.execute({ operation: "space-rename", space: "Work", name: "Tools" }).ok)
    events = []
    verify(management.execute({ operation: "space-remove", space: "Tools" }).ok)
    compare(events, ["host", "stage", "flush"])
    compare(store.document.spaces.length, 1)
    compare(management.execute({ operation: "space-remove", space: "Main" }).code, "last-space")
  }

  function test_element_commands_return_geometry_and_idempotent_removal() {
    var added = management.execute({ operation: "element-add-text", space: "Main",
      id: "label", text: "Tools", rect: { x: 0, y: 0, w: 200, h: 40 } })
    verify(added.ok)
    compare(added.element.rect, { x: 0, y: 0, w: 200, h: 40 })
    verify(management.execute({ operation: "element-add-divider", space: "Main",
      id: "line", line: { x1: 0, y1: 60, x2: 200, y2: 60 } }).ok)
    compare(management.execute({ operation: "elements" }).elements.length, 2)
    verify(management.execute({ operation: "element-remove", id: "label" }).changed)
    verify(!management.execute({ operation: "element-remove", id: "label" }).changed)
  }

  function test_plugin_placement_commits_host_before_document_and_flush() {
    var added = management.execute({ operation: "pending", pluginId: "test.plugin" })
    verify(added.ok)
    compare(added.placement.state, "pending")
    compare(events, ["host", "stage", "flush"])
    var placed = management.execute({ operation: "place", pluginId: "test.plugin",
      space: "Main", rect: { x: 0, y: 0, w: 200, h: 200 } })
    verify(placed.ok)
    compare(placed.placement.id, added.placement.id)
    compare(placed.placement.state, "placed")
    plugins.installed = false
    // A removed plugin can still leave a placement that needs to be deleted.
    verify(management.execute({ operation: "remove", selector: added.placement.id }).ok)
    compare(management.execute({ operation: "list" }).placements.length, 0)
  }

  function test_failed_host_transaction_leaves_document_untouched() {
    var before = JSON.stringify(store.document)
    plugins.acceptTransaction = false
    var result = management.execute({ operation: "pending", pluginId: "test.plugin" })
    compare(result.code, "host-transaction-failed")
    compare(events, ["host"])
    compare(JSON.stringify(store.document), before)
  }

  function test_failed_document_staging_does_not_flush() {
    var before = JSON.stringify(store.document)
    store.acceptDocument = false
    var result = management.execute({ operation: "pending", pluginId: "test.plugin" })
    compare(result.code, "persistence-stage-failed")
    compare(events, ["host", "stage"])
    compare(JSON.stringify(store.document), before)
  }
}
