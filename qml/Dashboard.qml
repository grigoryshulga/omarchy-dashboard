pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Hyprland
import qs.Commons
import "core/DashboardAppearance.js" as DashboardAppearance
import "core/DashboardModel.js" as DashboardModel
import "core/GridEngine.js" as GridEngine
import "core/SpatialNavigation.js" as SpatialNavigation
import "runtime" as Runtime
import "ui" as Ui

Item {
  id: root

  property var shell: null
  property var manifest: null
  property var pluginRegistry: null
  property bool opened: false
  property string activeScreenName: ""
  property string mode: "browse"
  property string selectedTileId: ""
  property string selectedElementId: ""
  property bool shortcutHintsVisible: false
  property string overlay: ""
  property var popoutTile: null
  property var placementDraft: null
  property var dividerDraft: null
  property double lastEscapeAt: 0
  readonly property var dashboardState: stateStore.document
  property real gridWidth: GridEngine.DEFAULT_WIDTH
  property real gridHeight: GridEngine.DEFAULT_HEIGHT

  readonly property string pluginId: manifest && manifest.id ? String(manifest.id) : "gshulga.dashboard"
  readonly property string home: Quickshell.env("HOME")
  readonly property string stateHome: {
    var configured = Quickshell.env("XDG_STATE_HOME")
    return configured && String(configured).charAt(0) === "/" ? String(configured) : home + "/.local/state"
  }
  readonly property string stateDirectory: stateHome + "/omarchy"
  readonly property string statePath: stateDirectory + "/gshulga.dashboard.json"
  readonly property string pluginDirectory: decodeURIComponent(Qt.resolvedUrl("../").toString().replace(/^file:\/\//, "").replace(/\/$/, ""))
  readonly property string cacheHome: {
    var configured = Quickshell.env("XDG_CACHE_HOME")
    return configured && String(configured).charAt(0) === "/" ? String(configured) : home + "/.cache"
  }
  readonly property string cacheRoot: cacheHome + "/omarchy-dashboard"
  readonly property var plugins: pluginRuntime
  readonly property var activeSpace: {
    var document = root.dashboardState
    var spaces = document && document.spaces ? document.spaces : []
    for (var index = 0; index < spaces.length; index++)
      if (spaces[index].id === document.activeSpaceId) return spaces[index]
    return spaces.length > 0 ? spaces[0] : ({ id: "", name: "", tiles: [] })
  }
  readonly property var activeTiles: {
    var space = root.activeSpace
    return space && space.tiles ? space.tiles : []
  }
  readonly property var activeElements: {
    var space = root.activeSpace
    return space && space.elements ? space.elements : []
  }
  readonly property var pendingPlacements: dashboardState && Array.isArray(dashboardState.pendingPlacements)
    ? dashboardState.pendingPlacements : []
  readonly property bool placingPlugin: placementDraft !== null
  readonly property bool placingDivider: dividerDraft !== null
  readonly property bool placementValid: placingPlugin
    && GridEngine.canPlace(placementDraft.rect, activeTiles, "", gridWidth, gridHeight)
  readonly property bool dimBackground: plugins.dashboardSetting("dimBackground", true) === true
  readonly property string surfaceMode: DashboardAppearance.surfaceMode(
    plugins.dashboardSetting("surfaceMode", "Glass"))
  readonly property bool glassBackground: DashboardAppearance.usesGlass(surfaceMode)
  readonly property bool blurBackground: glassBackground
    && plugins.dashboardSetting("blurBackground", true) === true

  function setSurfaceMode(value) {
    var normalized = DashboardAppearance.surfaceMode(value)
    if (normalized === surfaceMode) return true
    return plugins.setDashboardSetting(
      "surfaceMode", normalized === DashboardAppearance.FRAMED ? "Framed" : "Glass")
  }

  function toggleSurfaceMode() {
    return setSurfaceMode(glassBackground ? "Framed" : "Glass")
  }

  function toggleEditMode() {
    if (placingPlugin) cancelPluginPlacement()
    if (placingDivider) cancelDividerPlacement()
    mode = mode === "edit" ? "browse" : "edit"
    if (mode !== "edit") {
      selectedElementId = ""
      ensureSelection()
    }
  }

  function focusedScreenName() {
    var screens = Quickshell.screens || []
    var monitor = Hyprland.focusedMonitor
    var focusedName = monitor ? String(monitor.name || "") : ""
    for (var index = 0; index < screens.length; index++)
      if (String(screens[index].name || "") === focusedName) return focusedName
    return screens.length > 0 ? String(screens[0].name || "") : ""
  }

  function existingScreenName(requested) {
    var wanted = String(requested || "")
    var screens = Quickshell.screens || []
    for (var index = 0; index < screens.length; index++)
      if (String(screens[index].name || "") === wanted) return wanted
    return focusedScreenName()
  }

  function screenFromPayload(payloadJson) {
    try {
      var payload = JSON.parse(String(payloadJson || "{}"))
      return existingScreenName(payload.screenName)
    } catch (error) {
      return focusedScreenName()
    }
  }

  function open(payloadJson) {
    activeScreenName = screenFromPayload(payloadJson)
    opened = true
    mode = "browse"
    selectedElementId = ""
    overlay = ""
    popoutTile = null
    shortcutHintsVisible = false
    ensureSelection()
  }

  function close() {
    overlay = ""
    popoutTile = null
    placementDraft = null
    dividerDraft = null
    mode = "browse"
    selectedTileId = ""
    selectedElementId = ""
    shortcutHintsVisible = false
    opened = false
    stateStore.flush()
  }

  function toggle(payloadJson) {
    if (opened) close()
    else open(payloadJson)
  }

  function status() {
    var tiles = root.activeTiles
    var count = typeof tiles !== "undefined" && tiles !== null && typeof tiles.length === "number"
      ? tiles.length : 0
    return JSON.stringify({
      opened: opened,
      activeScreenName: activeScreenName,
      focusedScreenName: focusedScreenName(),
      mode: mode,
      overlay: overlay,
      popoutPluginId: popoutTile ? String(popoutTile.pluginId || "") : "",
      activeSpaceId: dashboardState ? dashboardState.activeSpaceId : "",
      tileCount: count,
      hostedPluginCount: plugins.hostEntries.length,
      pendingPluginCount: pendingPlacements.length,
      elementCount: activeElements.length,
      spaceCount: dashboardState && dashboardState.spaces ? dashboardState.spaces.length : 0,
      selectedTileId: selectedTileId,
      selectedElementId: selectedElementId,
      adaptingPluginId: plugins.adaptingPluginId,
      cornerRadius: Style.cornerRadius,
      surfaceMode: surfaceMode,
      blurBackground: blurBackground,
      gridSpacing: dashboardState ? dashboardState.gridSpacing : 10,
      gridWidth: dashboardState ? dashboardState.canvasWidth : gridWidth,
      gridHeight: dashboardState ? dashboardState.canvasHeight : gridHeight,
      statePath: statePath
    })
  }

  Connections {
    target: Hyprland
    function onRawEvent(event) {
      if (event && String(event.name || "") === "configreloaded") {
        Style.scheduleRefresh()
        blurSettings.scheduleApply()
      }
    }
  }

  // A single-string command endpoint keeps shell IPC useful without exposing
  // persistence or plugin-registry internals. Every mutation still passes
  // through DashboardModel's validation and collision checks.
  function execute(commandJson) {
    var rawCommand = String(commandJson || "{}")
    if (DashboardModel.utf8ByteLength(rawCommand) > 64 * 1024)
      return JSON.stringify({ ok: false, error: "command-too-large" })
    var command
    try {
      command = JSON.parse(rawCommand)
    } catch (error) {
      return JSON.stringify({ ok: false, error: "invalid-json" })
    }
    if (!command || typeof command !== "object" || Array.isArray(command))
      return JSON.stringify({ ok: false, error: "invalid-command" })

    var type = String(command.type || "")
    if (type === "status") return status()
    if (type === "getState") return JSON.stringify({ ok: true, state: dashboardState })
    if (type === "listPlugins") return JSON.stringify({ ok: true, plugins: plugins.availablePlugins })
    if (type === "listHostEntries") return JSON.stringify({
      ok: true, hostId: pluginId, placements: plugins.hostEntries
    })
    if (type === "managePlugins") return JSON.stringify(managePlugins(command.request || ({})))
    if (type === "open") open(JSON.stringify({ screenName: command.screenName || "" }))
    else if (type === "close") close()
    else if (type === "toggle") toggle(JSON.stringify({ screenName: command.screenName || "" }))
    else if (type === "selectSpace") selectSpace(String(command.spaceId || ""))
    else if (type === "nextSpace") moveSpace(Number(command.delta) < 0 ? -1 : 1)
    else if (type === "addSpace") addSpace(String(command.name || ""))
    else if (type === "renameSpace") renameActiveSpace(String(command.name || ""))
    else if (type === "reorderSpace") reorderSpace(String(command.spaceId || ""), Number(command.toIndex))
    else if (type === "removeSpace") removeActiveSpace()
    else if (type === "setGridSpacing") setGridSpacing(Number(command.value))
    else if (type === "addPlugin") addPlugin(String(command.pluginId || ""), String(command.embedding || "auto"))
    else if (type === "addDivider") addDivider(
      Number(command.x1), Number(command.y1), Number(command.x2), Number(command.y2))
    else if (type === "addText") addText(String(command.text || ""), command.rect || null)
    else if (type === "updateText") updateText(
      String(command.elementId || selectedElementId || ""), String(command.text || ""))
    else if (type === "removeElement") removeElement(
      String(command.elementId || selectedElementId || ""))
    else if (type === "removeTile") removeTile(String(command.tileId || selectedTileId || ""))
    else if (type === "selectTile") {
      selectTileId(String(command.tileId || ""))
    } else if (type === "activateTile") {
      if (command.tileId) selectTileId(String(command.tileId))
      ensureSelection()
      activateSelectedTile()
    } else if (type === "moveTile") {
      if (command.tileId) selectTileId(String(command.tileId))
      moveSelectedTile(Number(command.dx) || 0, Number(command.dy) || 0)
    } else if (type === "resizeTile") {
      if (command.tileId) selectTileId(String(command.tileId))
      resizeSelectedTile(Number(command.dw) || 0, Number(command.dh) || 0)
    } else if (type === "placeTile") {
      placeTile(String(command.tileId || selectedTileId || ""), command.rect || ({}))
    } else if (type === "placeElement") {
      placeElement(String(command.elementId || selectedElementId || ""), command.geometry || ({}))
    } else if (type === "setTileEmbedding") {
      setTileEmbedding(String(command.tileId || selectedTileId || ""), String(command.embedding || "auto"))
    } else if (type === "setMode" && ["browse", "edit", "interact"].indexOf(command.mode) >= 0) {
      mode = String(command.mode)
    } else return JSON.stringify({ ok: false, error: "unknown-command", type: type })
    return JSON.stringify({ ok: true, status: JSON.parse(status()) })
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

  function managePlugins(request) {
    if (!stateStore.ready)
      return { schemaVersion: 1, ok: false, code: "dashboard-loading" }
    if (!request || typeof request !== "object" || Array.isArray(request))
      return { schemaVersion: 1, ok: false, code: "invalid-request" }
    if (Number(request.schemaVersion || 1) !== 1)
      return { schemaVersion: 1, ok: false, code: "unsupported-schema-version" }
    var operation = String(request.operation || "")
    if (operation === "list") return {
      schemaVersion: 1, ok: true, revision: dashboardState.revision,
      grid: {
        spacing: dashboardState.gridSpacing,
        width: dashboardState.canvasWidth,
        height: dashboardState.canvasHeight
      },
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
      grid: {
        spacing: dashboardState.gridSpacing,
        width: dashboardState.canvasWidth,
        height: dashboardState.canvasHeight
      }
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
        grid: {
          spacing: dashboardState.gridSpacing,
          width: dashboardState.canvasWidth,
          height: dashboardState.canvasHeight
        }
      }
    }
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
      stateStore.replaceDocument(removedState)
      plugins.syncHostPlacements(dashboardState)
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
      stateStore.replaceDocument(result.state)
      if (result.placement && !plugins.enable(requestedPluginId, descriptor.manifest))
        return { schemaVersion: 1, ok: false, code: "host-sync-failed", revision: dashboardState.revision }
      plugins.syncHostPlacements(dashboardState)
      stateStore.flush()
    }
    return {
      schemaVersion: 1, ok: true, changed: result.changed,
      revision: dashboardState.revision, placement: result.placement || null
    }
  }

  function handleEscape() {
    var now = Date.now()
    if (now - lastEscapeAt < 120) return
    lastEscapeAt = now
    if (placingPlugin) cancelPluginPlacement()
    else if (placingDivider) cancelDividerPlacement()
    else if (mode === "interact" || mode === "edit") {
      mode = "browse"
      selectedElementId = ""
      ensureSelection()
    }
    else close()
  }

  function focusKeyboardPlugin(delta) {
    cycleTile(delta)
    mode = "browse"
  }

  function keyboardTiles() {
    return SpatialNavigation.readingOrder(activeTiles)
  }

  function keyboardShortcutForTile(tileId) {
    var tiles = keyboardTiles()
    for (var index = 0; index < tiles.length; index++)
      if (String(tiles[index].id || "") === String(tileId || ""))
        return SpatialNavigation.shortcutLabel(index)
    return ""
  }

  function activateKeyboardShortcut(key) {
    var index = SpatialNavigation.shortcutIndexForKey(key)
    var tiles = keyboardTiles()
    if (index < 0 || index >= tiles.length) return false
    selectedElementId = ""
    selectedTileId = String(tiles[index].id || "")
    mode = "browse"
    shortcutHintsVisible = false
    activateSelectedTile()
    return true
  }

  function selectTile(direction) {
    selectedElementId = ""
    selectedTileId = SpatialNavigation.next(activeTiles, selectedTileId, direction)
  }

  function cycleTile(delta) {
    selectedElementId = ""
    selectedTileId = SpatialNavigation.sequential(activeTiles, selectedTileId, delta)
  }

  function ensureSelection() {
    if (mode === "edit" && selectedElementId) {
      for (var elementIndex = 0; elementIndex < activeElements.length; elementIndex++) {
        if (activeElements[elementIndex].id === selectedElementId) {
          selectedTileId = ""
          return
        }
      }
    }
    selectedElementId = ""
    var tiles = root.activeTiles
    if (!tiles || typeof tiles.length !== "number") tiles = []
    for (var index = 0; index < tiles.length; index++)
      if (tiles[index].id === selectedTileId) return
    var orderedTiles = SpatialNavigation.readingOrder(tiles)
    selectedTileId = orderedTiles.length > 0 ? String(orderedTiles[0].id) : ""
  }

  function selectTileId(tileId) {
    selectedElementId = ""
    selectedTileId = String(tileId || "")
    ensureSelection()
  }

  function selectElement(elementId) {
    if (mode !== "edit") return
    selectedTileId = ""
    selectedElementId = String(elementId || "")
    ensureSelection()
  }

  function selectedTile() {
    var tiles = root.activeTiles
    if (!tiles || typeof tiles.length !== "number") tiles = []
    for (var index = 0; index < tiles.length; index++)
      if (tiles[index].id === selectedTileId) return tiles[index]
    return null
  }

  function selectedElement() {
    for (var index = 0; index < activeElements.length; index++)
      if (activeElements[index].id === selectedElementId) return activeElements[index]
    return null
  }

  function activateTile(tileValue) {
    if (!tileValue) return false
    selectedElementId = ""
    selectedTileId = String(tileValue.id || "")
    var tilePresentation = plugins.presentation(tileValue)
    if (tilePresentation.kind === "control")
      return plugins.activateControl(tileValue.pluginId)
    if (tilePresentation.kind === "launcher") {
      if (!tilePresentation.canLaunch) return false
      if (tilePresentation.launchTarget === "popout") {
        openPluginPopout(tileValue)
        return true
      }
      return plugins.launchNative(tileValue.pluginId)
    }
    mode = "interact"
    return true
  }

  function activateSelectedTile() {
    return activateTile(selectedTile())
  }

  function openPluginPopout(tileValue) {
    if (!tileValue) return
    popoutTile = tileValue
    mode = "browse"
    overlay = "plugin"
  }

  function closePluginPopout() {
    if (overlay === "plugin") overlay = ""
    popoutTile = null
  }

  function commit(command) {
    stateStore.commit(command, gridWidth, gridHeight)
    ensureSelection()
  }

  function updateGridBounds(width, height) {
    if (Number(width) < GridEngine.STEP || Number(height) < GridEngine.STEP) return
    var current = GridEngine.bounds(width, height)
    gridWidth = current.width
    gridHeight = current.height
    if (stateStore.ready && dashboardState && (dashboardState.canvasWidth !== current.width
        || dashboardState.canvasHeight !== current.height))
      commit({ type: "setCanvasBounds", width: current.width, height: current.height })
  }

  function setGridSpacing(value) {
    commit({ type: "setGridSpacing", value: value })
  }

  function adjustGridSpacing(delta) {
    setGridSpacing(Number(dashboardState.gridSpacing || 10) + Number(delta || 0))
  }

  function selectSpace(spaceId) {
    if (placingPlugin) cancelPluginPlacement()
    if (placingDivider) cancelDividerPlacement()
    selectedElementId = ""
    closePluginPopout()
    commit({ type: "selectSpace", spaceId: spaceId })
    mode = mode === "interact" ? "browse" : mode
  }

  function moveSpace(delta) {
    var spaces = dashboardState.spaces
    if (!spaces || spaces.length < 2) return
    var current = 0
    for (var index = 0; index < spaces.length; index++)
      if (spaces[index].id === dashboardState.activeSpaceId) current = index
    selectSpace(spaces[(current + (delta < 0 ? -1 : 1) + spaces.length) % spaces.length].id)
  }

  function addSpace(name) {
    var id = "space-" + Date.now() + "-" + dashboardState.spaces.length
    commit({ type: "addSpace", id: id, name: name || "Space " + (dashboardState.spaces.length + 1) })
  }

  function renameActiveSpace(name) {
    commit({ type: "renameSpace", spaceId: activeSpace.id, name: name })
  }

  function reorderSpace(spaceId, toIndex) {
    commit({ type: "reorderSpace", spaceId: spaceId, toIndex: toIndex })
  }

  function removeActiveSpace() {
    removeSpace(activeSpace.id)
  }

  function removeSpace(spaceId) {
    commit({ type: "removeSpace", spaceId: spaceId })
    plugins.syncHostPlacements(dashboardState)
  }

  function placeTile(tileId, rect) {
    commit({ type: "placeTile", spaceId: activeSpace.id, tileId: tileId, rect: rect })
  }

  function placeElement(elementId, geometry) {
    if (!elementId) return
    commit({
      type: "placeElement", spaceId: activeSpace.id,
      elementId: elementId, geometry: geometry
    })
  }

  function moveSelectedTile(dx, dy) {
    if (!selectedTileId) return
    commit({ type: "moveTile", spaceId: activeSpace.id, tileId: selectedTileId, dx: dx, dy: dy })
  }

  function moveSelectedItemByGrid(dx, dy) {
    if (selectedElementId) moveSelectedElementByGrid(dx, dy)
    else nudgeSelectedTile(dx, dy)
  }

  function resizeSelectedItemByGrid(dw, dh) {
    if (selectedElementId) resizeSelectedElementByGrid(dw, dh)
    else resizeSelectedTileByGrid(dw, dh)
  }

  function moveSelectedElementByGrid(dx, dy) {
    var element = selectedElement()
    if (!element) return
    var x = element.kind === "divider" ? element.x1 : element.x
    var y = element.kind === "divider" ? element.y1 : element.y
    var nextX = GridEngine.advanceOnGrid(x, dx, dashboardState.gridSpacing)
    var nextY = GridEngine.advanceOnGrid(y, dy, dashboardState.gridSpacing)
    var deltaX = nextX - x
    var deltaY = nextY - y
    if (element.kind === "divider") placeElement(element.id, {
      x1: element.x1 + deltaX, y1: element.y1 + deltaY,
      x2: element.x2 + deltaX, y2: element.y2 + deltaY
    })
    else placeElement(element.id, {
      x: element.x + deltaX, y: element.y + deltaY, w: element.w, h: element.h
    })
  }

  function resizeSelectedElementByGrid(dw, dh) {
    var element = selectedElement()
    if (!element) return
    if (element.kind === "divider") {
      var geometry = { x1: element.x1, y1: element.y1, x2: element.x2, y2: element.y2 }
      if (element.y1 === element.y2 && dw !== 0)
        geometry.x2 = GridEngine.advanceOnGrid(element.x2, dw, dashboardState.gridSpacing)
      else if (element.x1 === element.x2 && dh !== 0)
        geometry.y2 = GridEngine.advanceOnGrid(element.y2, dh, dashboardState.gridSpacing)
      placeElement(element.id, geometry)
      return
    }
    placeElement(element.id, {
      x: element.x, y: element.y,
      w: Math.max(40, GridEngine.advanceOnGrid(element.w, dw, dashboardState.gridSpacing)),
      h: Math.max(20, GridEngine.advanceOnGrid(element.h, dh, dashboardState.gridSpacing))
    })
  }

  function nudgeSelectedTile(dx, dy) {
    if (!selectedTileId) return
    commit({ type: "nudgeTile", spaceId: activeSpace.id, tileId: selectedTileId, dx: dx, dy: dy })
  }

  function resizeSelectedTile(dw, dh) {
    resizeSelectedTileWith("resizeTile", dw, dh)
  }

  function resizeSelectedTileByGrid(dw, dh) {
    resizeSelectedTileWith("resizeTileByGrid", dw, dh)
  }

  function tileMinimumSize(tileValue) {
    if (!tileValue) return { minW: GridEngine.MIN_WIDTH, minH: GridEngine.MIN_HEIGHT }
    var kind = plugins.presentation(tileValue).kind
    if (kind === "launcher" || kind === "control")
      return { minW: GridEngine.MIN_WIDTH, minH: GridEngine.MIN_HEIGHT }
    var hints = plugins.sizeHints(tileValue.pluginId, gridWidth, gridHeight)
    return { minW: hints.minW, minH: hints.minH }
  }

  function resizeSelectedTileWith(commandType, dw, dh) {
    if (!selectedTileId) return
    var tile = selectedTile()
    var minimum = tileMinimumSize(tile)
    commit({
      type: commandType, spaceId: activeSpace.id, tileId: selectedTileId,
      dw: dw, dh: dh, minW: minimum.minW, minH: minimum.minH
    })
  }

  function removeTile(tileId) {
    commit({ type: "removeTile", spaceId: activeSpace.id, tileId: tileId })
    plugins.syncHostPlacements(dashboardState)
  }

  function removeElement(elementId) {
    if (!elementId) return
    commit({ type: "removeElement", spaceId: activeSpace.id, elementId: elementId })
    if (selectedElementId === elementId) selectedElementId = ""
    ensureSelection()
  }

  function updateText(elementId, text) {
    if (!elementId || !String(text || "").trim()) return false
    commit({
      type: "updateText", spaceId: activeSpace.id,
      elementId: elementId, text: String(text)
    })
    return true
  }

  function defaultTextRect(text) {
    var step = dashboardState.gridSpacing
    var width = Math.min(gridWidth, GridEngine.snap(
      Math.max(160, Math.min(520, String(text || "").length * 18)), step))
    var height = Math.min(gridHeight, GridEngine.snap(70, step))
    return {
      x: Math.max(0, Math.min(gridWidth - width,
        GridEngine.snap((gridWidth - width) / 2, step))),
      y: Math.max(0, Math.min(gridHeight - height,
        GridEngine.snap((gridHeight - height) / 2, step))),
      w: width, h: height
    }
  }

  function addText(text, requestedRect) {
    var value = String(text || "").trim()
    if (!value) return false
    var elementId = "element-text-" + Date.now() + "-" + activeElements.length
    commit({
      type: "addText", spaceId: activeSpace.id, id: elementId,
      text: value, rect: requestedRect || defaultTextRect(value)
    })
    for (var index = 0; index < activeElements.length; index++) {
      if (activeElements[index].id === elementId) {
        selectElement(elementId)
        return true
      }
    }
    return false
  }

  function addDivider(x1, y1, x2, y2) {
    var elementId = "element-divider-" + Date.now() + "-" + activeElements.length
    commit({
      type: "addDivider", spaceId: activeSpace.id, id: elementId,
      x1: x1, y1: y1, x2: x2, y2: y2
    })
    for (var index = 0; index < activeElements.length; index++) {
      if (activeElements[index].id === elementId) {
        selectElement(elementId)
        return true
      }
    }
    return false
  }

  function beginDividerPlacement() {
    if (placingPlugin) cancelPluginPlacement()
    dividerDraft = { x1: 0, y1: 0, x2: 0, y2: 0, started: false }
    selectedTileId = ""
    selectedElementId = ""
    overlay = ""
    mode = "edit"
  }

  function updateDividerDraft(x1, y1, x2, y2, started) {
    if (!placingDivider) return
    dividerDraft = { x1: x1, y1: y1, x2: x2, y2: y2, started: started !== false }
  }

  function cancelDividerPlacement() {
    dividerDraft = null
    ensureSelection()
  }

  function confirmDividerPlacement() {
    if (!placingDivider || !dividerDraft.started) return false
    var draft = dividerDraft
    dividerDraft = null
    return addDivider(draft.x1, draft.y1, draft.x2, draft.y2)
  }

  function setTileEmbedding(tileId, embedding) {
    if (!tileId) return
    commit({
      type: "setTileEmbedding", spaceId: activeSpace.id,
      tileId: tileId, embedding: embedding
    })
  }

  function centeredMinimumRect(hints) {
    var step = dashboardState.gridSpacing
    var width = Math.min(gridWidth, GridEngine.floorStep(hints.minW))
    var height = Math.min(gridHeight, GridEngine.floorStep(hints.minH))
    var x = GridEngine.snap((gridWidth - width) / 2, step)
    var y = GridEngine.snap((gridHeight - height) / 2, step)
    return {
      x: Math.max(0, Math.min(gridWidth - width, x)),
      y: Math.max(0, Math.min(gridHeight - height, y)),
      w: width,
      h: height
    }
  }

  function pendingPlacement(pluginIdValue) {
    for (var index = 0; index < pendingPlacements.length; index++)
      if (String(pendingPlacements[index].pluginId) === String(pluginIdValue)) return pendingPlacements[index]
    return null
  }

  function beginPluginPlacement(pluginIdValue, embedding) {
    var descriptor = plugins.descriptor(pluginIdValue)
    if (!descriptor) return false
    var pending = pendingPlacement(pluginIdValue)
    var hints = plugins.sizeHints(pluginIdValue, gridWidth, gridHeight)
    var rect = GridEngine.bestFree(
      hints.preferredW, hints.preferredH, hints.minW, hints.minH,
      activeTiles, gridWidth, gridHeight, dashboardState.gridSpacing)
    placementDraft = {
      pluginId: pluginIdValue,
      instanceId: pending ? String(pending.id) : "",
      label: descriptor.name,
      embedding: embedding || "auto",
      manifest: descriptor.manifest,
      minW: hints.minW,
      minH: hints.minH,
      preferredW: hints.preferredW,
      preferredH: hints.preferredH,
      previousTileId: selectedTileId,
      rect: rect || centeredMinimumRect(hints)
    }
    selectedTileId = ""
    selectedElementId = ""
    overlay = ""
    mode = "edit"
    return true
  }

  function updatePlacementRect(rect) {
    if (!placingPlugin || !rect) return
    var next = placementDraft
    placementDraft = {
      pluginId: next.pluginId,
      instanceId: next.instanceId,
      label: next.label,
      embedding: next.embedding,
      manifest: next.manifest,
      minW: next.minW,
      minH: next.minH,
      preferredW: next.preferredW,
      preferredH: next.preferredH,
      previousTileId: next.previousTileId,
      rect: rect
    }
  }

  function movePlacementByGrid(dx, dy) {
    if (!placingPlugin) return
    var rect = placementDraft.rect
    var step = dashboardState.gridSpacing
    var x = GridEngine.advanceOnGrid(rect.x, dx, step)
    var y = GridEngine.advanceOnGrid(rect.y, dy, step)
    updatePlacementRect({
      x: Math.max(0, Math.min(gridWidth - rect.w, x)),
      y: Math.max(0, Math.min(gridHeight - rect.h, y)),
      w: rect.w,
      h: rect.h
    })
  }

  function resizePlacementByGrid(dw, dh) {
    if (!placingPlugin) return
    var draft = placementDraft
    var rect = draft.rect
    var step = dashboardState.gridSpacing
    updatePlacementRect({
      x: rect.x,
      y: rect.y,
      w: Math.max(draft.minW, Math.min(gridWidth - rect.x,
        GridEngine.advanceOnGrid(rect.w, dw, step))),
      h: Math.max(draft.minH, Math.min(gridHeight - rect.y,
        GridEngine.advanceOnGrid(rect.h, dh, step)))
    })
  }

  function cancelPluginPlacement() {
    var previousTileId = placingPlugin ? String(placementDraft.previousTileId || "") : ""
    placementDraft = null
    selectedTileId = previousTileId
    ensureSelection()
  }

  function confirmPluginPlacement() {
    if (!placementValid) return false
    var draft = placementDraft
    var tileId = String(draft.instanceId || "") || "tile-" + Date.now() + "-" + activeTiles.length
    commit({
      type: "addTile", spaceId: activeSpace.id, id: tileId,
      pluginId: draft.pluginId, label: draft.label, rect: draft.rect,
      embedding: draft.embedding
    })
    var added = false
    for (var index = 0; index < activeTiles.length; index++)
      if (activeTiles[index].id === tileId) added = true
    if (!added) return false
    plugins.enable(draft.pluginId, draft.manifest)
    plugins.syncHostPlacements(dashboardState)
    selectedTileId = tileId
    placementDraft = null
    return true
  }

  function addPlugin(pluginIdValue, embedding) {
    if (!beginPluginPlacement(pluginIdValue, embedding)) return false
    if (placementValid) return confirmPluginPlacement()
    cancelPluginPlacement()
    return false
  }

  onOpenedChanged: {
    if (!opened) stateStore.flush()
  }
  onActiveSpaceChanged: {
    Qt.callLater(root.ensureSelection)
  }

  Connections {
    target: Quickshell
    function onScreensChanged() {
      if (!root.opened) return
      var replacement = root.existingScreenName(root.activeScreenName)
      if (replacement) root.activeScreenName = replacement
      else root.close()
    }
  }

  Runtime.DashboardStore {
    id: stateStore
    directoryPath: root.stateDirectory
    statePath: root.statePath
    readerPath: root.pluginDirectory + "/bin/omarchy-dashboard-read-state"
    onLoaded: {
      root.gridWidth = Number(root.dashboardState.canvasWidth) || GridEngine.DEFAULT_WIDTH
      root.gridHeight = Number(root.dashboardState.canvasHeight) || GridEngine.DEFAULT_HEIGHT
      root.plugins.syncHostPlacements(root.dashboardState)
      root.ensureSelection()
    }
  }

  Runtime.DashboardBlurSettings {
    id: blurSettings
    active: root.blurBackground
  }

  Runtime.PluginRuntime {
    id: pluginRuntime
    dashboardHost: root
    shell: root.shell
    registry: root.pluginRegistry
    dashboardPluginId: root.pluginId
    pluginDirectory: root.pluginDirectory
    cacheRoot: root.cacheRoot
    active: root.opened
    tiles: root.activeTiles
    spaces: root.dashboardState.spaces
    pendingPlacements: root.pendingPlacements
  }

  Variants {
    model: Quickshell.screens
    delegate: Component {
      Ui.DashboardSurface {
        required property var modelData
        dashboard: root
        screen: modelData
        visible: root.opened && String(modelData.name || "") === root.activeScreenName
      }
    }
  }

}
