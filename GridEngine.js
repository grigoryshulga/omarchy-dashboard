.pragma library

// Tile coordinates are logical QML pixels snapped to a five-pixel lattice.
// Bounds are supplied by the visible surface, so interaction is pixel-based
// instead of tied to a small fixed matrix.
var STEP = 5
var DEFAULT_WIDTH = 1800
var DEFAULT_HEIGHT = 900
var MAX_WIDTH = 16380
var MAX_HEIGHT = 16380
var MIN_WIDTH = 5
var MIN_HEIGHT = 5

function finiteNumber(value, fallback) {
  var number = Number(value)
  return isFinite(number) ? number : fallback
}

function clamp(value, minimum, maximum) {
  return Math.max(minimum, Math.min(maximum, value))
}

function gridStep(value) {
  return Math.max(STEP, Math.round(finiteNumber(value, STEP) / STEP) * STEP)
}

function snap(value, step) {
  var increment = gridStep(step)
  return Math.round(finiteNumber(value, 0) / increment) * increment
}

function snapFrom(value, delta, step) {
  var current = finiteNumber(value, 0)
  var change = finiteNumber(delta, 0)
  if (change === 0) return current
  var target = snap(current + change, step)
  return change > 0 ? Math.max(current, target) : Math.min(current, target)
}

function advanceOnGrid(value, units, step) {
  var current = finiteNumber(value, 0)
  var count = Math.trunc(finiteNumber(units, 0))
  if (count === 0) return current
  var increment = gridStep(step)
  var aligned = current % increment === 0
  if (count > 0) {
    var next = aligned ? current + increment : Math.ceil(current / increment) * increment
    return next + (count - 1) * increment
  }
  var previous = aligned ? current - increment : Math.floor(current / increment) * increment
  return previous + (count + 1) * increment
}

function floorStep(value) {
  return Math.max(STEP, Math.floor(finiteNumber(value, STEP) / STEP) * STEP)
}

function bounds(width, height) {
  return {
    width: Math.min(MAX_WIDTH, floorStep(width || DEFAULT_WIDTH)),
    height: Math.min(MAX_HEIGHT, floorStep(height || DEFAULT_HEIGHT))
  }
}

function occupiedBounds(spaces) {
  var width = 0
  var height = 0
  var source = Array.isArray(spaces) ? spaces : []
  for (var spaceIndex = 0; spaceIndex < source.length; spaceIndex++) {
    var tiles = source[spaceIndex] && Array.isArray(source[spaceIndex].tiles)
      ? source[spaceIndex].tiles : []
    for (var tileIndex = 0; tileIndex < tiles.length; tileIndex++) {
      var tile = tiles[tileIndex] || ({})
      width = Math.max(width, finiteNumber(tile.x, 0) + finiteNumber(tile.w, 0))
      height = Math.max(height, finiteNumber(tile.y, 0) + finiteNumber(tile.h, 0))
    }
    var elements = source[spaceIndex] && Array.isArray(source[spaceIndex].elements)
      ? source[spaceIndex].elements : []
    for (var elementIndex = 0; elementIndex < elements.length; elementIndex++) {
      var element = elements[elementIndex] || ({})
      if (element.kind === "divider") {
        width = Math.max(width, finiteNumber(element.x1, 0), finiteNumber(element.x2, 0))
        height = Math.max(height, finiteNumber(element.y1, 0), finiteNumber(element.y2, 0))
      } else {
        width = Math.max(width, finiteNumber(element.x, 0) + finiteNumber(element.w, 0))
        height = Math.max(height, finiteNumber(element.y, 0) + finiteNumber(element.h, 0))
      }
    }
  }
  return { width: Math.max(0, width), height: Math.max(0, height) }
}

function centeredExtent(available, required, step) {
  var limit = floorStep(available)
  var increment = gridStep(step)
  var aligned = Math.floor(limit / increment) * increment
  return aligned >= MIN_WIDTH && aligned >= finiteNumber(required, 0) ? aligned : limit
}

function centeredBounds(width, height, step, spaces) {
  var limit = bounds(width, height)
  var occupied = occupiedBounds(spaces)
  return {
    width: centeredExtent(limit.width, occupied.width, step),
    height: centeredExtent(limit.height, occupied.height, step)
  }
}

// Magnetically aligns a rectangular item's center with either canvas axis.
// The stored origin stays on the five-pixel lattice even when an exact center
// would land between lattice points; the guide still marks the true canvas axis.
function snapRectToCenter(rect, boundWidth, boundHeight, threshold) {
  var source = rect || ({})
  var width = finiteNumber(source.w, 0)
  var height = finiteNumber(source.h, 0)
  var limitWidth = Math.max(0, finiteNumber(boundWidth, 0))
  var limitHeight = Math.max(0, finiteNumber(boundHeight, 0))
  var radius = Math.max(0, finiteNumber(threshold, 0))
  var targetX = clamp(snap((limitWidth - width) / 2), 0, Math.max(0, limitWidth - width))
  var targetY = clamp(snap((limitHeight - height) / 2), 0, Math.max(0, limitHeight - height))
  var currentX = finiteNumber(source.x, 0)
  var currentY = finiteNumber(source.y, 0)
  var vertical = Math.abs(currentX - targetX) <= radius
  var horizontal = Math.abs(currentY - targetY) <= radius
  return {
    rect: {
      x: vertical ? targetX : currentX,
      y: horizontal ? targetY : currentY,
      w: width,
      h: height
    },
    vertical: vertical,
    horizontal: horizontal
  }
}

function normalizeRect(rect, minimumWidth, minimumHeight, boundWidth, boundHeight) {
  var source = rect || ({})
  var limit = bounds(boundWidth, boundHeight)
  var minW = clamp(floorStep(minimumWidth || MIN_WIDTH), MIN_WIDTH, limit.width)
  var minH = clamp(floorStep(minimumHeight || MIN_HEIGHT), MIN_HEIGHT, limit.height)
  var width = clamp(snap(source.w === undefined ? minW : source.w), minW, limit.width)
  var height = clamp(snap(source.h === undefined ? minH : source.h), minH, limit.height)
  var x = clamp(snap(source.x || 0), 0, limit.width - width)
  var y = clamp(snap(source.y || 0), 0, limit.height - height)
  return { x: x, y: y, w: width, h: height }
}

function strictRect(rect) {
  if (!rect || typeof rect !== "object") return null
  if (typeof rect.x !== "number" || typeof rect.y !== "number"
      || typeof rect.w !== "number" || typeof rect.h !== "number") return null
  var values = [rect.x, rect.y, rect.w, rect.h]
  for (var index = 0; index < values.length; index++)
    if (!isFinite(values[index]) || Math.floor(values[index]) !== values[index]
        || values[index] % STEP !== 0) return null
  return { x: values[0], y: values[1], w: values[2], h: values[3] }
}

function overlaps(left, right) {
  if (!left || !right) return false
  return left.x < right.x + right.w
    && left.x + left.w > right.x
    && left.y < right.y + right.h
    && left.y + left.h > right.y
}

function inBounds(rect, boundWidth, boundHeight) {
  var limit = bounds(boundWidth, boundHeight)
  return !!rect && rect.x >= 0 && rect.y >= 0
    && rect.w >= MIN_WIDTH && rect.h >= MIN_HEIGHT
    && rect.x + rect.w <= limit.width && rect.y + rect.h <= limit.height
}

function tileRect(tile) {
  return tile ? { x: Number(tile.x), y: Number(tile.y), w: Number(tile.w), h: Number(tile.h) } : null
}

function canPlace(rect, tiles, ignoredTileId, boundWidth, boundHeight) {
  var candidate = strictRect(rect)
  if (!candidate || !inBounds(candidate, boundWidth, boundHeight)) return false
  var source = Array.isArray(tiles) ? tiles : []
  for (var index = 0; index < source.length; index++) {
    var tile = source[index]
    if (!tile || String(tile.id || "") === String(ignoredTileId || "")) continue
    if (overlaps(candidate, tileRect(tile))) return false
  }
  return true
}

function firstFree(width, height, tiles, boundWidth, boundHeight, step) {
  var limit = bounds(boundWidth, boundHeight)
  var increment = gridStep(step)
  var size = normalizeRect({ x: 0, y: 0, w: width, h: height }, MIN_WIDTH, MIN_HEIGHT,
                           limit.width, limit.height)
  for (var y = 0; y <= limit.height - size.h; y += increment) {
    for (var x = 0; x <= limit.width - size.w; x += increment) {
      var candidate = { x: x, y: y, w: size.w, h: size.h }
      if (canPlace(candidate, tiles, "", limit.width, limit.height)) return candidate
    }
  }
  return null
}

function appendUnique(values, value) {
  for (var index = 0; index < values.length; index++)
    if (values[index] === value) return
  values.push(value)
}

function alignedUp(value, step) {
  var increment = gridStep(step)
  return Math.ceil(finiteNumber(value, 0) / increment) * increment
}

// Finds the least-shrunk free rectangle between preferred and minimum size.
// Candidate edges come from the canvas and occupied tile edges, which keeps
// the search bounded by the number of tiles instead of the pixel dimensions.
function bestFree(preferredWidth, preferredHeight, minimumWidth, minimumHeight,
                  tiles, boundWidth, boundHeight, step) {
  var limit = bounds(boundWidth, boundHeight)
  var increment = gridStep(step)
  var preferredW = clamp(floorStep(preferredWidth), MIN_WIDTH, limit.width)
  var preferredH = clamp(floorStep(preferredHeight), MIN_HEIGHT, limit.height)
  var minW = clamp(floorStep(minimumWidth), MIN_WIDTH, preferredW)
  var minH = clamp(floorStep(minimumHeight), MIN_HEIGHT, preferredH)
  var source = Array.isArray(tiles) ? tiles : []
  var startsX = [0]
  var startsY = [0]
  var endsX = [limit.width]
  var endsY = [limit.height]

  for (var tileIndex = 0; tileIndex < source.length; tileIndex++) {
    var tile = tileRect(source[tileIndex])
    if (!tile) continue
    appendUnique(startsX, alignedUp(tile.x + tile.w, increment))
    appendUnique(startsY, alignedUp(tile.y + tile.h, increment))
    appendUnique(endsX, floorStep(tile.x))
    appendUnique(endsY, floorStep(tile.y))
  }
  startsX.sort(function(left, right) { return left - right })
  startsY.sort(function(left, right) { return left - right })
  endsX.sort(function(left, right) { return left - right })
  endsY.sort(function(left, right) { return left - right })

  var best = null
  var bestBalance = -1
  var bestArea = -1
  for (var yIndex = 0; yIndex < startsY.length; yIndex++) {
    var y = startsY[yIndex]
    if (y < 0 || y + minH > limit.height) continue
    for (var xIndex = 0; xIndex < startsX.length; xIndex++) {
      var x = startsX[xIndex]
      if (x < 0 || x + minW > limit.width) continue
      for (var bottomIndex = 0; bottomIndex < endsY.length; bottomIndex++) {
        var height = Math.min(preferredH, endsY[bottomIndex] - y)
        height = floorStep(height)
        if (height < minH) continue
        for (var rightIndex = 0; rightIndex < endsX.length; rightIndex++) {
          var width = Math.min(preferredW, endsX[rightIndex] - x)
          width = floorStep(width)
          if (width < minW) continue
          var candidate = { x: x, y: y, w: width, h: height }
          if (!canPlace(candidate, source, "", limit.width, limit.height)) continue
          var balance = Math.min(width / preferredW, height / preferredH)
          var area = width * height
          if (!best || balance > bestBalance
              || (balance === bestBalance && area > bestArea)
              || (balance === bestBalance && area === bestArea && y < best.y)
              || (balance === bestBalance && area === bestArea && y === best.y && x < best.x)) {
            best = candidate
            bestBalance = balance
            bestArea = area
          }
        }
      }
    }
  }
  return best
}

function move(tile, deltaX, deltaY, tiles, boundWidth, boundHeight) {
  if (!tile) return null
  var candidate = {
    x: Number(tile.x) + snap(deltaX),
    y: Number(tile.y) + snap(deltaY),
    w: Number(tile.w),
    h: Number(tile.h)
  }
  return canPlace(candidate, tiles, tile.id, boundWidth, boundHeight) ? candidate : null
}

function moveOnGrid(tile, xSteps, ySteps, tiles, boundWidth, boundHeight, step) {
  if (!tile) return null
  var candidate = {
    x: advanceOnGrid(tile.x, xSteps, step),
    y: advanceOnGrid(tile.y, ySteps, step),
    w: Number(tile.w),
    h: Number(tile.h)
  }
  return canPlace(candidate, tiles, tile.id, boundWidth, boundHeight) ? candidate : null
}

function resize(tile, deltaWidth, deltaHeight, tiles, minimumWidth, minimumHeight,
                boundWidth, boundHeight) {
  if (!tile) return null
  var minW = floorStep(minimumWidth || MIN_WIDTH)
  var minH = floorStep(minimumHeight || MIN_HEIGHT)
  var candidate = {
    x: Number(tile.x),
    y: Number(tile.y),
    w: Math.max(minW, Number(tile.w) + snap(deltaWidth)),
    h: Math.max(minH, Number(tile.h) + snap(deltaHeight))
  }
  return canPlace(candidate, tiles, tile.id, boundWidth, boundHeight) ? candidate : null
}

function resizeOnGrid(tile, widthSteps, heightSteps, tiles, minimumWidth, minimumHeight,
                      boundWidth, boundHeight, step) {
  if (!tile) return null
  var minW = floorStep(minimumWidth || MIN_WIDTH)
  var minH = floorStep(minimumHeight || MIN_HEIGHT)
  var candidate = {
    x: Number(tile.x),
    y: Number(tile.y),
    w: Math.max(minW, advanceOnGrid(tile.w, widthSteps, step)),
    h: Math.max(minH, advanceOnGrid(tile.h, heightSteps, step))
  }
  return canPlace(candidate, tiles, tile.id, boundWidth, boundHeight) ? candidate : null
}
