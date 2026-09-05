import QtQuick
import "../state/DashboardModel.js" as DashboardModel

// Versioned management protocol used by Shell and the CLI. The store stages
// documents only after plugin host transactions succeed; no UI is required.
QtObject {
  id: root

  required property var stateStore
  required property var plugins
  required property real gridWidth
  required property real gridHeight
  readonly property var dashboardState: stateStore.document
  readonly property var pendingPlacements: dashboardState.pendingPlacements || []

  function gridSnapshot() {
    return { spacing: dashboardState.gridSpacing,
      width: dashboardState.canvasWidth, height: dashboardState.canvasHeight }
  }

  function resolveSpace(selector) {
    var wanted = String(selector || "")
    var spaces = dashboardState && Array.isArray(dashboardState.spaces) ? dashboardState.spaces : []
    for (var index = 0; index < spaces.length; index++)
      if (String(spaces[index].id) === wanted) return { ok: true, space: spaces[index] }
    var matches = []
    for (var nameIndex = 0; nameIndex < spaces.length; nameIndex++)
      if (String(spaces[nameIndex].name || "").toLowerCase() === wanted.toLowerCase()) matches.push(spaces[nameIndex])
    if (matches.length === 1) return { ok: true, space: matches[0] }
    return { ok: false, code: matches.length > 1 ? "space-name-ambiguous" : "space-not-found" }
  }

  function graphicElements() {
    var entries = []
    var spaces = dashboardState && Array.isArray(dashboardState.spaces) ? dashboardState.spaces : []
    for (var spaceIndex = 0; spaceIndex < spaces.length; spaceIndex++) {
      var elements = Array.isArray(spaces[spaceIndex].elements) ? spaces[spaceIndex].elements : []
      for (var elementIndex = 0; elementIndex < elements.length; elementIndex++) {
        var element = elements[elementIndex]
        var entry = {
          id: element.id, kind: element.kind,
          spaceId: spaces[spaceIndex].id, spaceName: spaces[spaceIndex].name
        }
        if (element.kind === "text") {
          entry.text = element.text
          entry.rect = { x: element.x, y: element.y, w: element.w, h: element.h }
        } else entry.line = { x1: element.x1, y1: element.y1, x2: element.x2, y2: element.y2 }
        entries.push(entry)
      }
    }
    return entries
  }

  function resolveGraphicElement(selector) {
    var wanted = String(selector || "")
    var entries = graphicElements()
    for (var index = 0; index < entries.length; index++)
      if (entries[index].id === wanted) return entries[index]
    return null
  }

  function execute(request) {
    if (!stateStore.ready)
      return { schemaVersion: 1, ok: false, code: "dashboard-loading" }
    if (!request || typeof request !== "object" || Array.isArray(request))
      return { schemaVersion: 1, ok: false, code: "invalid-request" }
    if (Number(request.schemaVersion || 1) !== 1)
      return { schemaVersion: 1, ok: false, code: "unsupported-schema-version" }
    var operation = String(request.operation || "")
    if (operation === "list") return {
      schemaVersion: 1, ok: true, revision: dashboardState.revision,
      grid: gridSnapshot(),
      placements: DashboardModel.placements(dashboardState)
    }
    if (operation === "spaces") return {
      schemaVersion: 1, ok: true, revision: dashboardState.revision,
      spaces: dashboardState.spaces.map(function(space) {
        return { id: space.id, name: space.name, active: space.id === dashboardState.activeSpaceId }
      })
    }
    if (operation === "grid") return {
      schemaVersion: 1, ok: true, revision: dashboardState.revision,
      grid: gridSnapshot()
    }
    if (operation === "grid-set") {
      var requestedSpacing = Number(request.spacing)
      if (!isFinite(requestedSpacing))
        return { schemaVersion: 1, ok: false, code: "invalid-grid-spacing" }
      var gridState = DashboardModel.apply(dashboardState, {
        type: "setGridSpacing", value: requestedSpacing
      }, gridWidth, gridHeight)
      stateStore.replaceDocument(gridState)
      stateStore.flush()
      return {
        schemaVersion: 1, ok: true, changed: true, revision: dashboardState.revision,
        grid: gridSnapshot()
      }
    }
    if (["space-create", "space-rename", "space-remove", "space-select"].indexOf(operation) >= 0)
      return manageSpace(request, operation)
    if (["elements", "element-add-text", "element-add-divider", "element-remove"].indexOf(operation) >= 0)
      return manageElement(request, operation)
    return managePlacement(request, operation)
  }

  function manageSpace(request, operation) {
    if (operation === "space-create") {
      var newName = String(request.name || "").trim()
      if (!newName) return { schemaVersion: 1, ok: false, code: "invalid-space-name" }
      if (resolveSpace(newName).ok)
        return { schemaVersion: 1, ok: false, code: "space-name-conflict" }
      var newSpaceId = String(request.id || ("space-" + Date.now() + "-" + dashboardState.spaces.length)).trim()
      if (!newSpaceId || resolveSpace(newSpaceId).ok)
        return { schemaVersion: 1, ok: false, code: "space-id-conflict" }
      var createdState = DashboardModel.apply(dashboardState, {
        type: "addSpace", id: newSpaceId, name: newName
      }, gridWidth, gridHeight)
      if (createdState.spaces.length !== dashboardState.spaces.length + 1) return {
        schemaVersion: 1, ok: false,
        code: dashboardState.spaces.length >= DashboardModel.MAX_SPACES
          ? "space-capacity-exceeded" : "invalid-space-id"
      }
      stateStore.replaceDocument(createdState)
      stateStore.flush()
      return {
        schemaVersion: 1, ok: true, changed: true, revision: dashboardState.revision,
        space: { id: newSpaceId, name: newName }
      }
    }
    if (operation === "space-rename") {
      var renameResolution = resolveSpace(request.spaceId || request.space)
      if (!renameResolution.ok)
        return { schemaVersion: 1, ok: false, code: renameResolution.code }
      var renamedName = String(request.name || "").trim()
      if (!renamedName) return { schemaVersion: 1, ok: false, code: "invalid-space-name" }
      var duplicateResolution = resolveSpace(renamedName)
      if (duplicateResolution.ok && duplicateResolution.space.id !== renameResolution.space.id)
        return { schemaVersion: 1, ok: false, code: "space-name-conflict" }
      if (renameResolution.space.name === renamedName) return {
        schemaVersion: 1, ok: true, changed: false, revision: dashboardState.revision,
        space: { id: renameResolution.space.id, name: renameResolution.space.name }
      }
      var renamedState = DashboardModel.apply(dashboardState, {
        type: "renameSpace", spaceId: renameResolution.space.id, name: renamedName
      }, gridWidth, gridHeight)
      stateStore.replaceDocument(renamedState)
      stateStore.flush()
      return {
        schemaVersion: 1, ok: true, changed: true, revision: dashboardState.revision,
        space: { id: renameResolution.space.id, name: renamedName }
      }
    }
    if (operation === "space-remove") {
      var removeResolution = resolveSpace(request.spaceId || request.space)
      if (!removeResolution.ok)
        return { schemaVersion: 1, ok: false, code: removeResolution.code }
      if (dashboardState.spaces.length <= 1)
        return { schemaVersion: 1, ok: false, code: "last-space" }
      var removedSpace = { id: removeResolution.space.id, name: removeResolution.space.name }
      var removedState = DashboardModel.apply(dashboardState, {
        type: "removeSpace", spaceId: removeResolution.space.id
      }, gridWidth, gridHeight)
      if (!plugins.applyHostPlacementTransaction(removedState, "", null)) return {
        schemaVersion: 1, ok: false, code: "host-transaction-failed", revision: dashboardState.revision
      }
      if (!stateStore.replaceDocument(removedState)) return {
        schemaVersion: 1, ok: false, code: "persistence-stage-failed", revision: dashboardState.revision
      }
      stateStore.flush()
      return {
        schemaVersion: 1, ok: true, changed: true, revision: dashboardState.revision,
        removedSpace: removedSpace
      }
    }
    if (operation === "space-select") {
      var selectResolution = resolveSpace(request.spaceId || request.space)
      if (!selectResolution.ok)
        return { schemaVersion: 1, ok: false, code: selectResolution.code }
      if (dashboardState.activeSpaceId === selectResolution.space.id) return {
        schemaVersion: 1, ok: true, changed: false, revision: dashboardState.revision,
        space: { id: selectResolution.space.id, name: selectResolution.space.name }
      }
      var selectedState = DashboardModel.apply(dashboardState, {
        type: "selectSpace", spaceId: selectResolution.space.id
      }, gridWidth, gridHeight)
      stateStore.replaceDocument(selectedState)
      stateStore.flush()
      return {
        schemaVersion: 1, ok: true, changed: true, revision: dashboardState.revision,
        space: { id: selectResolution.space.id, name: selectResolution.space.name }
      }
    }
  }

  function manageElement(request, operation) {
    if (operation === "elements") return {
      schemaVersion: 1, ok: true, revision: dashboardState.revision,
      elements: graphicElements()
    }
    if (operation === "element-add-text" || operation === "element-add-divider") {
      var elementSpaceResolution = resolveSpace(request.spaceId || request.space)
      if (!elementSpaceResolution.ok)
        return { schemaVersion: 1, ok: false, code: elementSpaceResolution.code }
      var elementKind = operation === "element-add-text" ? "text" : "divider"
      var elementId = String(request.id || (
        "element-" + elementKind + "-" + Date.now() + "-" + graphicElements().length)).trim()
      if (!elementId || resolveGraphicElement(elementId))
        return { schemaVersion: 1, ok: false, code: "element-id-conflict" }
      var elementAction = {
        type: elementKind === "text" ? "addText" : "addDivider",
        spaceId: elementSpaceResolution.space.id,
        id: elementId
      }
      if (elementKind === "text") {
        elementAction.text = String(request.text || "")
        elementAction.rect = request.rect || null
      } else {
        var line = request.line || ({})
        elementAction.x1 = line.x1
        elementAction.y1 = line.y1
        elementAction.x2 = line.x2
        elementAction.y2 = line.y2
      }
      var elementState = DashboardModel.apply(
        dashboardState, elementAction, dashboardState.canvasWidth, dashboardState.canvasHeight)
      var addedElement = null
      var targetElements = elementState.spaces.filter(function(space) {
        return space.id === elementSpaceResolution.space.id
      })[0].elements
      for (var addedIndex = 0; addedIndex < targetElements.length; addedIndex++)
        if (targetElements[addedIndex].id === elementId) addedElement = targetElements[addedIndex]
      if (!addedElement)
        return { schemaVersion: 1, ok: false, code: "invalid-element-geometry-or-capacity" }
      stateStore.replaceDocument(elementState)
      stateStore.flush()
      return {
        schemaVersion: 1, ok: true, changed: true, revision: dashboardState.revision,
        element: resolveGraphicElement(elementId)
      }
    }
    if (operation === "element-remove") {
      var removedElement = resolveGraphicElement(request.id || request.elementId)
      if (!removedElement) return {
        schemaVersion: 1, ok: true, changed: false, revision: dashboardState.revision,
        removedElement: null
      }
      var removedElementState = DashboardModel.apply(dashboardState, {
        type: "removeElement", spaceId: removedElement.spaceId, elementId: removedElement.id
      }, dashboardState.canvasWidth, dashboardState.canvasHeight)
      stateStore.replaceDocument(removedElementState)
      stateStore.flush()
      return {
        schemaVersion: 1, ok: true, changed: true, revision: dashboardState.revision,
        removedElement: removedElement
      }
    }

  }

  function managePlacement(request, operation) {
    var selector = String(request.selector || request.pluginId || "")
    var existing = DashboardModel.placement(dashboardState, selector)
    var requestedPluginId = String(request.pluginId || (existing ? existing.pluginId : selector))
    var descriptor = plugins.descriptor(requestedPluginId)
    if (!descriptor && !(operation === "remove" && existing))
      return { schemaVersion: 1, ok: false, code: "plugin-not-installed" }

    var target = String(request.target || "pending")
    var resolvedSpace = null
    if (["place", "move"].indexOf(operation) >= 0 || (operation === "ensure" && target === "placed")) {
      var resolution = resolveSpace(request.spaceId || request.space)
      if (!resolution.ok) return { schemaVersion: 1, ok: false, code: resolution.code }
      resolvedSpace = resolution.space
    }
    var canvasWidth = Number(dashboardState.canvasWidth) || gridWidth
    var canvasHeight = Number(dashboardState.canvasHeight) || gridHeight
    var hints = descriptor ? plugins.sizeHints(requestedPluginId, canvasWidth, canvasHeight) : ({})
    var result = DashboardModel.managePlacement(dashboardState, {
      operation: operation,
      pluginId: requestedPluginId,
      selector: selector,
      instanceId: existing ? existing.id : "placement-" + Date.now() + "-" + pendingPlacements.length,
      label: descriptor ? descriptor.name : (existing ? existing.label : requestedPluginId),
      embedding: request.embedding || "auto",
      target: target,
      spaceId: resolvedSpace ? resolvedSpace.id : "",
      strategy: request.strategy || (request.rect ? "exact" : "auto"),
      rect: request.rect || null,
      hints: hints
    }, canvasWidth, canvasHeight)
    if (!result.ok) return {
      schemaVersion: 1, ok: false, code: result.code,
      placement: result.placement || null, revision: dashboardState.revision
    }
    if (result.changed) {
      var enablingId = operation !== "remove" && result.placement ? requestedPluginId : ""
      if (!plugins.applyHostPlacementTransaction(result.state, enablingId, descriptor ? descriptor.manifest : null))
        return { schemaVersion: 1, ok: false, code: "host-transaction-failed", revision: dashboardState.revision }
      if (!stateStore.replaceDocument(result.state))
        return { schemaVersion: 1, ok: false, code: "persistence-stage-failed", revision: dashboardState.revision }
      stateStore.flush()
    }
    return {
      schemaVersion: 1, ok: true, changed: result.changed,
      revision: dashboardState.revision, placement: result.placement || null
    }
  }

}
