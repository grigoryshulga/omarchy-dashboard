pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Hyprland
import qs.Commons
import "DashboardAppearance.js" as DashboardAppearance
import "GridEngine.js" as GridEngine
import "SpatialNavigation.js" as SpatialNavigation

Item {
  id: root

  property var shell: null
  property var manifest: null
  property var pluginRegistry: null
  property bool opened: false
  property string activeScreenName: ""
  property string mode: "browse"
  property string selectedTileId: ""
  property string overlay: ""
  property var popoutTile: null
  property var placementDraft: null
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
  readonly property string pluginDirectory: decodeURIComponent(Qt.resolvedUrl(".").toString().replace(/^file:\/\//, "").replace(/\/$/, ""))
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
  readonly property bool placingPlugin: placementDraft !== null
  readonly property bool placementValid: placingPlugin
    && GridEngine.canPlace(placementDraft.rect, activeTiles, "", gridWidth, gridHeight)
  readonly property bool dimBackground: plugins.dashboardSetting("dimBackground", true) === true
  readonly property string surfaceMode: DashboardAppearance.surfaceMode(
    plugins.dashboardSetting("surfaceMode", "Glass"))
  readonly property bool glassBackground: DashboardAppearance.usesGlass(surfaceMode)
  readonly property bool blurBackground: glassBackground
    && plugins.dashboardSetting("blurBackground", true) === true
  readonly property var backgroundService: plugins.pluginService("omarchy.background")
  readonly property string backgroundPath: {
    var service = backgroundService
    if (!service) return ""
    return String(service.displayedBackground || service.currentBackground || "")
  }
  readonly property string backgroundUrl: backgroundPath ? Util.fileUrl(backgroundPath) : ""
  readonly property var blurEffect: blurSettings.effect

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
    mode = mode === "edit" ? "browse" : "edit"
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
    overlay = ""
    popoutTile = null
    ensureSelection()
  }

  function close() {
    overlay = ""
    popoutTile = null
    placementDraft = null
    mode = "browse"
    selectedTileId = ""
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
      spaceCount: dashboardState && dashboardState.spaces ? dashboardState.spaces.length : 0,
      selectedTileId: selectedTileId,
      adaptingPluginId: plugins.adaptingPluginId,
      cornerRadius: Style.cornerRadius,
      surfaceMode: surfaceMode,
      blurBackground: blurBackground,
      backgroundPath: backgroundPath,
      gridSpacing: dashboardState ? dashboardState.gridSpacing : 10,
      gridWidth: gridWidth,
      gridHeight: gridHeight,
      statePath: statePath
    })
  }

  Connections {
    target: Hyprland
    function onRawEvent(event) {
      if (event && String(event.name || "") === "configreloaded") {
        Style.scheduleRefresh()
        blurSettings.scheduleRefresh()
      }
    }
  }

  // A single-string command endpoint keeps shell IPC useful without exposing
  // persistence or plugin-registry internals. Every mutation still passes
  // through DashboardModel's validation and collision checks.
  function execute(commandJson) {
    var command
    try {
      command = JSON.parse(String(commandJson || "{}"))
    } catch (error) {
      return JSON.stringify({ ok: false, error: "invalid-json" })
    }
    if (!command || typeof command !== "object" || Array.isArray(command))
      return JSON.stringify({ ok: false, error: "invalid-command" })

    var type = String(command.type || "")
    if (type === "status") return status()
    if (type === "getState") return JSON.stringify({ ok: true, state: dashboardState })
    if (type === "listPlugins") return JSON.stringify({ ok: true, plugins: plugins.availablePlugins })
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
    else if (type === "removeTile") removeTile(String(command.tileId || selectedTileId || ""))
    else if (type === "selectTile") {
      selectedTileId = String(command.tileId || "")
      ensureSelection()
    } else if (type === "activateTile") {
      if (command.tileId) selectedTileId = String(command.tileId)
      ensureSelection()
      activateSelectedTile()
    } else if (type === "moveTile") {
      if (command.tileId) selectedTileId = String(command.tileId)
      moveSelectedTile(Number(command.dx) || 0, Number(command.dy) || 0)
    } else if (type === "resizeTile") {
      if (command.tileId) selectedTileId = String(command.tileId)
      resizeSelectedTile(Number(command.dw) || 0, Number(command.dh) || 0)
    } else if (type === "placeTile") {
      placeTile(String(command.tileId || selectedTileId || ""), command.rect || ({}))
    } else if (type === "setTileEmbedding") {
      setTileEmbedding(String(command.tileId || selectedTileId || ""), String(command.embedding || "auto"))
    } else if (type === "setMode" && ["browse", "edit", "interact"].indexOf(command.mode) >= 0) {
      mode = String(command.mode)
    } else return JSON.stringify({ ok: false, error: "unknown-command", type: type })
    return JSON.stringify({ ok: true, status: JSON.parse(status()) })
  }

  function handleEscape() {
    var now = Date.now()
    if (now - lastEscapeAt < 120) return
    lastEscapeAt = now
    if (placingPlugin) cancelPluginPlacement()
    else if (mode === "interact" || mode === "edit") mode = "browse"
    else close()
  }

  function focusKeyboardPlugin(delta) {
    cycleTile(delta)
    mode = "browse"
  }

  function selectTile(direction) {
    selectedTileId = SpatialNavigation.next(activeTiles, selectedTileId, direction)
  }

  function cycleTile(delta) {
    selectedTileId = SpatialNavigation.sequential(activeTiles, selectedTileId, delta)
  }

  function ensureSelection() {
    var tiles = root.activeTiles
    if (!tiles || typeof tiles.length !== "number") tiles = []
    for (var index = 0; index < tiles.length; index++)
      if (tiles[index].id === selectedTileId) return
    selectedTileId = tiles.length > 0 ? String(tiles[0].id) : ""
  }

  function selectedTile() {
    var tiles = root.activeTiles
    if (!tiles || typeof tiles.length !== "number") tiles = []
    for (var index = 0; index < tiles.length; index++)
      if (tiles[index].id === selectedTileId) return tiles[index]
    return null
  }

  function activateTile(tileValue) {
    if (!tileValue) return false
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
  }

  function setGridSpacing(value) {
    commit({ type: "setGridSpacing", value: value })
  }

  function adjustGridSpacing(delta) {
    setGridSpacing(Number(dashboardState.gridSpacing || 10) + Number(delta || 0))
  }

  function selectSpace(spaceId) {
    if (placingPlugin) cancelPluginPlacement()
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
  }

  function placeTile(tileId, rect) {
    commit({ type: "placeTile", spaceId: activeSpace.id, tileId: tileId, rect: rect })
  }

  function moveSelectedTile(dx, dy) {
    if (!selectedTileId) return
    commit({ type: "moveTile", spaceId: activeSpace.id, tileId: selectedTileId, dx: dx, dy: dy })
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

  function resizeSelectedTileWith(commandType, dw, dh) {
    if (!selectedTileId) return
    var tile = selectedTile()
    var hints = plugins.sizeHints(tile ? tile.pluginId : "", gridWidth, gridHeight)
    commit({
      type: commandType, spaceId: activeSpace.id, tileId: selectedTileId,
      dw: dw, dh: dh, minW: hints.minW, minH: hints.minH
    })
  }

  function removeTile(tileId) {
    commit({ type: "removeTile", spaceId: activeSpace.id, tileId: tileId })
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

  function beginPluginPlacement(pluginIdValue, embedding) {
    var descriptor = plugins.descriptor(pluginIdValue)
    if (!descriptor) return false
    var hints = plugins.sizeHints(pluginIdValue, gridWidth, gridHeight)
    var rect = GridEngine.bestFree(
      hints.preferredW, hints.preferredH, hints.minW, hints.minH,
      activeTiles, gridWidth, gridHeight, dashboardState.gridSpacing)
    placementDraft = {
      pluginId: pluginIdValue,
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
    overlay = ""
    mode = "edit"
    return true
  }

  function updatePlacementRect(rect) {
    if (!placingPlugin || !rect) return
    var next = placementDraft
    placementDraft = {
      pluginId: next.pluginId,
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
    var tileId = "tile-" + Date.now() + "-" + activeTiles.length
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

  DashboardStore {
    id: stateStore
    directoryPath: root.stateDirectory
    statePath: root.statePath
    readerPath: root.pluginDirectory + "/bin/omarchy-dashboard-read-state"
    onLoaded: root.ensureSelection()
  }

  DashboardBlurSettings {
    id: blurSettings
  }

  PluginRuntime {
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
  }

  Variants {
    model: Quickshell.screens
    delegate: Component {
      DashboardSurface {
        required property var modelData
        dashboard: root
        screen: modelData
        visible: root.opened && String(modelData.name || "") === root.activeScreenName
      }
    }
  }

}
