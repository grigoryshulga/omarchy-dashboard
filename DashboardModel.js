.pragma library
.import "GridEngine.js" as GridEngine

var VERSION = 3
var MAX_STATE_BYTES = 256 * 1024
var MAX_SPACES = 12
var MAX_TILES_PER_SPACE = 24
var MAX_TOTAL_TILES = 64
var MAX_NAME_LENGTH = 80
var MAX_ID_LENGTH = 160
var MIN_GRID_SPACING = 5
var MAX_GRID_SPACING = 80

function stringBounded(value, maximum) {
  var text = value === undefined || value === null ? "" : String(value)
  return text.length > maximum ? text.slice(0, maximum) : text
}

function utf8ByteLength(value) {
  try {
    return unescape(encodeURIComponent(String(value))).length
  } catch (error) {
    return MAX_STATE_BYTES + 1
  }
}

function copy(value) {
  return JSON.parse(JSON.stringify(value))
}

function normalizeEmbedding(value) {
  var requested = String(value || "auto")
  if (requested === "explicit" || requested === "standard") return "embedded"
  if (requested === "native") return "launcher"
  return ["auto", "embedded", "widget", "launcher", "control"].indexOf(requested) >= 0
    ? requested : "auto"
}

function defaultState() {
  return {
    version: VERSION,
    revision: 0,
    gridSpacing: 10,
    activeSpaceId: "space-main",
    spaces: [{ id: "space-main", name: "Main", tiles: [] }]
  }
}

function normalizeTile(raw, usedTileIds, usedPluginIds, acceptedTiles) {
  var source = raw || ({})
  var id = stringBounded(source.id, MAX_ID_LENGTH).trim()
  var pluginId = stringBounded(source.pluginId || source.id, MAX_ID_LENGTH).trim()
  if (!id || !pluginId || usedTileIds[id] || usedPluginIds[pluginId]) return null
  var rect = GridEngine.normalizeRect(source, GridEngine.MIN_WIDTH, GridEngine.MIN_HEIGHT,
                                      GridEngine.MAX_WIDTH, GridEngine.MAX_HEIGHT)
  if (!GridEngine.canPlace(rect, acceptedTiles, "", GridEngine.MAX_WIDTH, GridEngine.MAX_HEIGHT)) return null
  usedTileIds[id] = true
  usedPluginIds[pluginId] = true
  return {
    id: id,
    pluginId: pluginId,
    label: stringBounded(source.label, MAX_NAME_LENGTH),
    x: rect.x,
    y: rect.y,
    w: rect.w,
    h: rect.h,
    embedding: normalizeEmbedding(source.embedding)
  }
}

function normalize(raw) {
  var source = raw && typeof raw === "object" ? raw : ({})
  var spacesSource = Array.isArray(source.spaces) ? source.spaces : []
  var spaces = []
  var usedSpaceIds = ({})
  var usedTileIds = ({})
  var usedPluginIds = ({})
  var totalTiles = 0

  for (var spaceIndex = 0; spaceIndex < spacesSource.length && spaces.length < MAX_SPACES; spaceIndex++) {
    var inputSpace = spacesSource[spaceIndex] || ({})
    var spaceId = stringBounded(inputSpace.id, MAX_ID_LENGTH).trim()
    if (!spaceId || usedSpaceIds[spaceId]) continue
    usedSpaceIds[spaceId] = true
    var tiles = []
    var tileSource = Array.isArray(inputSpace.tiles) ? inputSpace.tiles : []
    for (var tileIndex = 0; tileIndex < tileSource.length
         && tiles.length < MAX_TILES_PER_SPACE && totalTiles < MAX_TOTAL_TILES; tileIndex++) {
      var tile = normalizeTile(tileSource[tileIndex], usedTileIds, usedPluginIds, tiles)
      if (!tile) continue
      tiles.push(tile)
      totalTiles += 1
    }
    var name = stringBounded(inputSpace.name, MAX_NAME_LENGTH).trim()
    spaces.push({ id: spaceId, name: name || "Space " + (spaces.length + 1), tiles: tiles })
  }

  if (spaces.length === 0) return defaultState()
  var activeSpaceId = stringBounded(source.activeSpaceId, MAX_ID_LENGTH)
  if (!usedSpaceIds[activeSpaceId]) activeSpaceId = spaces[0].id
  var revision = Math.max(0, Math.floor(isFinite(Number(source.revision)) ? Number(source.revision) : 0))
  var requestedSpacing = GridEngine.snap(source.gridSpacing === undefined ? 10 : source.gridSpacing)
  var gridSpacing = Math.max(MIN_GRID_SPACING, Math.min(MAX_GRID_SPACING, requestedSpacing))
  return {
    version: VERSION,
    revision: revision,
    gridSpacing: gridSpacing,
    activeSpaceId: activeSpaceId,
    spaces: spaces
  }
}

function parse(raw) {
  if (utf8ByteLength(raw) > MAX_STATE_BYTES) return null
  try {
    var document = JSON.parse(String(raw || ""))
    if (!document || [2, VERSION].indexOf(document.version) < 0 || !Array.isArray(document.spaces)) return null
    return normalize(document)
  } catch (error) {
    return null
  }
}

function serialize(state) {
  var text = JSON.stringify(normalize(state), null, 2) + "\n"
  return utf8ByteLength(text) <= MAX_STATE_BYTES ? text : ""
}

function spaceIndex(state, id) {
  for (var index = 0; index < state.spaces.length; index++)
    if (state.spaces[index].id === id) return index
  return -1
}

function tileIndex(space, id) {
  for (var index = 0; index < space.tiles.length; index++)
    if (space.tiles[index].id === id) return index
  return -1
}

function pluginExists(state, pluginId) {
  for (var spaceIndexValue = 0; spaceIndexValue < state.spaces.length; spaceIndexValue++) {
    var tiles = state.spaces[spaceIndexValue].tiles
    for (var tileIndexValue = 0; tileIndexValue < tiles.length; tileIndexValue++)
      if (tiles[tileIndexValue].pluginId === pluginId) return true
  }
  return false
}

function apply(state, command, boundWidth, boundHeight) {
  var next = normalize(copy(state || defaultState()))
  var action = command || ({})
  var index = spaceIndex(next, action.spaceId || next.activeSpaceId)
  if (action.type === "selectSpace") {
    if (spaceIndex(next, String(action.spaceId || "")) >= 0) next.activeSpaceId = String(action.spaceId)
  } else if (action.type === "addSpace" && next.spaces.length < MAX_SPACES) {
    var newSpaceId = stringBounded(action.id, MAX_ID_LENGTH).trim()
    if (newSpaceId && spaceIndex(next, newSpaceId) < 0) {
      var name = stringBounded(action.name, MAX_NAME_LENGTH).trim()
      next.spaces.push({ id: newSpaceId, name: name || "Space " + (next.spaces.length + 1), tiles: [] })
      next.activeSpaceId = newSpaceId
    }
  } else if (action.type === "renameSpace" && index >= 0) {
    var nextName = stringBounded(action.name, MAX_NAME_LENGTH).trim()
    if (nextName) next.spaces[index].name = nextName
  } else if (action.type === "reorderSpace" && index >= 0) {
    var requestedIndex = Math.floor(Number(action.toIndex))
    if (isFinite(requestedIndex)) {
      var targetIndex = Math.max(0, Math.min(next.spaces.length - 1, requestedIndex))
      if (targetIndex !== index)
        next.spaces.splice(targetIndex, 0, next.spaces.splice(index, 1)[0])
    }
  } else if (action.type === "removeSpace" && index >= 0 && next.spaces.length > 1) {
    next.spaces.splice(index, 1)
    if (next.activeSpaceId === String(action.spaceId || ""))
      next.activeSpaceId = next.spaces[Math.min(index, next.spaces.length - 1)].id
  } else if (action.type === "setGridSpacing") {
    next.gridSpacing = Math.max(MIN_GRID_SPACING, Math.min(MAX_GRID_SPACING,
      GridEngine.snap(action.value)))
  } else if (action.type === "addTile" && index >= 0
             && next.spaces[index].tiles.length < MAX_TILES_PER_SPACE
             && !pluginExists(next, String(action.pluginId || ""))) {
    var allCount = 0
    for (var countIndex = 0; countIndex < next.spaces.length; countIndex++) allCount += next.spaces[countIndex].tiles.length
    var tileId = stringBounded(action.id, MAX_ID_LENGTH).trim()
    var pluginId = stringBounded(action.pluginId, MAX_ID_LENGTH).trim()
    var rectangle = action.rect || GridEngine.firstFree(action.w || 320, action.h || 240,
      next.spaces[index].tiles, boundWidth, boundHeight, next.gridSpacing)
    if (allCount < MAX_TOTAL_TILES && tileId && pluginId && tileIndex(next.spaces[index], tileId) < 0
        && rectangle && GridEngine.canPlace(rectangle, next.spaces[index].tiles, "", boundWidth, boundHeight)) {
      next.spaces[index].tiles.push({
        id: tileId,
        pluginId: pluginId,
        label: stringBounded(action.label, MAX_NAME_LENGTH),
        x: rectangle.x, y: rectangle.y, w: rectangle.w, h: rectangle.h,
        embedding: normalizeEmbedding(action.embedding)
      })
    }
  } else if (action.type === "setTileEmbedding" && index >= 0) {
    var embeddingIndex = tileIndex(next.spaces[index], String(action.tileId || ""))
    if (embeddingIndex >= 0)
      next.spaces[index].tiles[embeddingIndex].embedding = normalizeEmbedding(action.embedding)
  } else if (action.type === "removeTile" && index >= 0) {
    var removeIndex = tileIndex(next.spaces[index], String(action.tileId || ""))
    if (removeIndex >= 0) next.spaces[index].tiles.splice(removeIndex, 1)
  } else if (["moveTile", "resizeTile", "nudgeTile", "resizeTileByGrid"].indexOf(action.type) >= 0
             && index >= 0) {
    var changedIndex = tileIndex(next.spaces[index], String(action.tileId || ""))
    if (changedIndex >= 0) {
      var changed = next.spaces[index].tiles[changedIndex]
      var changedRect = null
      if (action.type === "nudgeTile")
        changedRect = GridEngine.moveOnGrid(changed, action.dx, action.dy, next.spaces[index].tiles,
                                            boundWidth, boundHeight, next.gridSpacing)
      else if (action.type === "resizeTileByGrid")
        changedRect = GridEngine.resizeOnGrid(changed, action.dw, action.dh, next.spaces[index].tiles,
          action.minW, action.minH, boundWidth, boundHeight, next.gridSpacing)
      else if (action.type === "moveTile")
        changedRect = GridEngine.move(changed, action.dx, action.dy, next.spaces[index].tiles,
                                      boundWidth, boundHeight)
      else changedRect = GridEngine.resize(changed, action.dw, action.dh, next.spaces[index].tiles,
                                           action.minW, action.minH, boundWidth, boundHeight)
      if (changedRect) {
        changed.x = changedRect.x
        changed.y = changedRect.y
        changed.w = changedRect.w
        changed.h = changedRect.h
      }
    }
  } else if (action.type === "placeTile" && index >= 0) {
    var placeIndex = tileIndex(next.spaces[index], String(action.tileId || ""))
    if (placeIndex >= 0 && GridEngine.canPlace(action.rect, next.spaces[index].tiles,
                                               action.tileId, boundWidth, boundHeight)) {
      var placed = next.spaces[index].tiles[placeIndex]
      placed.x = action.rect.x
      placed.y = action.rect.y
      placed.w = action.rect.w
      placed.h = action.rect.h
    }
  }
  next.revision += 1
  return normalize(next)
}
