.pragma library
.import "GridEngine.js" as GridEngine

var VERSION = 4
var MAX_STATE_BYTES = 256 * 1024
var MAX_SPACES = 12
var MAX_TILES_PER_SPACE = 24
var MAX_TOTAL_TILES = 64
var MAX_ELEMENTS_PER_SPACE = 48
var MAX_TOTAL_ELEMENTS = 128
var MAX_NAME_LENGTH = 80
var MAX_TEXT_LENGTH = 240
var MAX_ID_LENGTH = 160
var MIN_GRID_SPACING = 5
var MAX_GRID_SPACING = 80
var MIN_TEXT_WIDTH = 40
var MIN_TEXT_HEIGHT = 20

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
    spaces: [{ id: "space-main", name: "Main", tiles: [], elements: [] }]
  }
}

function normalizeElement(raw, usedElementIds) {
  var source = raw || ({})
  var id = stringBounded(source.id, MAX_ID_LENGTH).trim()
  var kind = String(source.kind || source.type || "")
  if (!id || usedElementIds[id] || ["divider", "text"].indexOf(kind) < 0) return null

  if (kind === "divider") {
    var x1 = GridEngine.snap(source.x1)
    var y1 = GridEngine.snap(source.y1)
    var x2 = GridEngine.snap(source.x2)
    var y2 = GridEngine.snap(source.y2)
    if (![x1, y1, x2, y2].every(function(value) { return isFinite(value) })) return null
    x1 = Math.max(0, Math.min(GridEngine.MAX_WIDTH, x1))
    x2 = Math.max(0, Math.min(GridEngine.MAX_WIDTH, x2))
    y1 = Math.max(0, Math.min(GridEngine.MAX_HEIGHT, y1))
    y2 = Math.max(0, Math.min(GridEngine.MAX_HEIGHT, y2))
    if ((x1 !== x2 && y1 !== y2) || (x1 === x2 && y1 === y2)) return null
    usedElementIds[id] = true
    return { id: id, kind: kind, x1: x1, y1: y1, x2: x2, y2: y2 }
  }

  var text = stringBounded(source.text, MAX_TEXT_LENGTH).trim()
  if (!text) return null
  var rect = GridEngine.normalizeRect(source, MIN_TEXT_WIDTH, MIN_TEXT_HEIGHT,
                                      GridEngine.MAX_WIDTH, GridEngine.MAX_HEIGHT)
  usedElementIds[id] = true
  return {
    id: id, kind: kind, text: text,
    x: rect.x, y: rect.y, w: rect.w, h: rect.h
  }
}

function elementIndex(space, id) {
  var elements = space && Array.isArray(space.elements) ? space.elements : []
  for (var index = 0; index < elements.length; index++)
    if (elements[index].id === id) return index
  return -1
}

function elementInBounds(element, boundWidth, boundHeight) {
  var limit = GridEngine.bounds(boundWidth, boundHeight)
  if (!element) return false
  if (element.kind === "divider") {
    return element.x1 >= 0 && element.x1 <= limit.width
      && element.x2 >= 0 && element.x2 <= limit.width
      && element.y1 >= 0 && element.y1 <= limit.height
      && element.y2 >= 0 && element.y2 <= limit.height
      && ((element.x1 === element.x2 && element.y1 !== element.y2)
        || (element.y1 === element.y2 && element.x1 !== element.x2))
  }
  return GridEngine.inBounds(element, limit.width, limit.height)
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
  var usedElementIds = ({})
  var totalTiles = 0
  var totalElements = 0

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
    var elements = []
    var elementSource = Array.isArray(inputSpace.elements) ? inputSpace.elements : []
    for (var elementSourceIndex = 0; elementSourceIndex < elementSource.length
         && elements.length < MAX_ELEMENTS_PER_SPACE
         && totalElements < MAX_TOTAL_ELEMENTS; elementSourceIndex++) {
      var element = normalizeElement(elementSource[elementSourceIndex], usedElementIds)
      if (!element) continue
      elements.push(element)
      totalElements += 1
    }
    var name = stringBounded(inputSpace.name, MAX_NAME_LENGTH).trim()
    spaces.push({
      id: spaceId, name: name || "Space " + (spaces.length + 1),
      tiles: tiles, elements: elements
    })
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
    if (!document || [2, 3, VERSION].indexOf(document.version) < 0 || !Array.isArray(document.spaces)) return null
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

function elementExists(state, elementId) {
  for (var spaceIndexValue = 0; spaceIndexValue < state.spaces.length; spaceIndexValue++)
    if (elementIndex(state.spaces[spaceIndexValue], elementId) >= 0) return true
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
      next.spaces.push({
        id: newSpaceId, name: name || "Space " + (next.spaces.length + 1),
        tiles: [], elements: []
      })
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
  } else if (action.type === "addDivider" && index >= 0
             && next.spaces[index].elements.length < MAX_ELEMENTS_PER_SPACE) {
    var dividerCount = 0
    for (var dividerSpace = 0; dividerSpace < next.spaces.length; dividerSpace++)
      dividerCount += next.spaces[dividerSpace].elements.length
    var divider = normalizeElement({
      id: action.id, kind: "divider",
      x1: action.x1, y1: action.y1, x2: action.x2, y2: action.y2
    }, ({}))
    if (dividerCount < MAX_TOTAL_ELEMENTS && divider
        && !elementExists(next, divider.id)
        && elementInBounds(divider, boundWidth, boundHeight))
      next.spaces[index].elements.push(divider)
  } else if (action.type === "addText" && index >= 0
             && next.spaces[index].elements.length < MAX_ELEMENTS_PER_SPACE) {
    var textCount = 0
    for (var textSpace = 0; textSpace < next.spaces.length; textSpace++)
      textCount += next.spaces[textSpace].elements.length
    var textElement = normalizeElement({
      id: action.id, kind: "text", text: action.text,
      x: action.rect && action.rect.x, y: action.rect && action.rect.y,
      w: action.rect && action.rect.w, h: action.rect && action.rect.h
    }, ({}))
    if (textCount < MAX_TOTAL_ELEMENTS && textElement
        && !elementExists(next, textElement.id)
        && elementInBounds(textElement, boundWidth, boundHeight))
      next.spaces[index].elements.push(textElement)
  } else if (action.type === "updateText" && index >= 0) {
    var textElementIndex = elementIndex(next.spaces[index], String(action.elementId || ""))
    var nextText = stringBounded(action.text, MAX_TEXT_LENGTH).trim()
    if (textElementIndex >= 0 && next.spaces[index].elements[textElementIndex].kind === "text" && nextText)
      next.spaces[index].elements[textElementIndex].text = nextText
  } else if (action.type === "removeElement" && index >= 0) {
    var removeElementIndex = elementIndex(next.spaces[index], String(action.elementId || ""))
    if (removeElementIndex >= 0) next.spaces[index].elements.splice(removeElementIndex, 1)
  } else if (action.type === "placeElement" && index >= 0) {
    var placeElementIndex = elementIndex(next.spaces[index], String(action.elementId || ""))
    if (placeElementIndex >= 0) {
      var currentElement = next.spaces[index].elements[placeElementIndex]
      var replacement = null
      if (currentElement.kind === "divider") replacement = normalizeElement({
        id: currentElement.id, kind: currentElement.kind,
        x1: action.geometry && action.geometry.x1,
        y1: action.geometry && action.geometry.y1,
        x2: action.geometry && action.geometry.x2,
        y2: action.geometry && action.geometry.y2
      }, ({}))
      else replacement = normalizeElement({
        id: currentElement.id, kind: currentElement.kind, text: currentElement.text,
        x: action.geometry && action.geometry.x,
        y: action.geometry && action.geometry.y,
        w: action.geometry && action.geometry.w,
        h: action.geometry && action.geometry.h
      }, ({}))
      if (replacement && elementInBounds(replacement, boundWidth, boundHeight))
        next.spaces[index].elements[placeElementIndex] = replacement
    }
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
