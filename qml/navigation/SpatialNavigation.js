.pragma library

function center(tile) {
  return {
    x: Number(tile.x || 0) + Number(tile.w || 1) / 2,
    y: Number(tile.y || 0) + Number(tile.h || 1) / 2
  }
}

function bounds(tile) {
  var x = Number(tile.x || 0)
  var y = Number(tile.y || 0)
  return {
    left: x,
    top: y,
    right: x + Number(tile.w || 1),
    bottom: y + Number(tile.h || 1)
  }
}

function directionVector(direction) {
  if (direction === "left") return { x: -1, y: 0 }
  if (direction === "right") return { x: 1, y: 0 }
  if (direction === "up") return { x: 0, y: -1 }
  if (direction === "down") return { x: 0, y: 1 }
  return null
}

function readingOrder(tiles) {
  var source = Array.isArray(tiles) ? tiles.slice() : []
  source.sort(function(left, right) {
    var leftBounds = bounds(left)
    var rightBounds = bounds(right)
    if (leftBounds.top !== rightBounds.top) return leftBounds.top - rightBounds.top
    if (leftBounds.left !== rightBounds.left) return leftBounds.left - rightBounds.left
    if (leftBounds.bottom !== rightBounds.bottom) return leftBounds.bottom - rightBounds.bottom
    if (leftBounds.right !== rightBounds.right) return leftBounds.right - rightBounds.right
    return String(left.id || "").localeCompare(String(right.id || ""))
  })
  return source
}

function shortcutLabel(index) {
  var value = Number(index)
  if (value >= 0 && value < 9) return String(value + 1)
  if (value >= 9 && value < 35) return String.fromCharCode("A".charCodeAt(0) + value - 9)
  return ""
}

function shortcutIndexForKey(key) {
  var value = Number(key)
  if (value >= "1".charCodeAt(0) && value <= "9".charCodeAt(0))
    return value - "1".charCodeAt(0)
  if (value >= "A".charCodeAt(0) && value <= "Z".charCodeAt(0))
    return value - "A".charCodeAt(0) + 9
  return -1
}

function overlapsPerpendicular(current, candidate, direction) {
  var currentBounds = bounds(current)
  var candidateBounds = bounds(candidate)
  if (direction === "left" || direction === "right")
    return candidateBounds.bottom > currentBounds.top && candidateBounds.top < currentBounds.bottom
  return candidateBounds.right > currentBounds.left && candidateBounds.left < currentBounds.right
}

function next(tiles, currentId, direction) {
  var source = Array.isArray(tiles) ? tiles : []
  var vector = directionVector(direction)
  if (!vector || source.length === 0) return ""
  var current = null
  for (var index = 0; index < source.length; index++) {
    if (String(source[index].id || "") === String(currentId || "")) {
      current = source[index]
      break
    }
  }
  if (!current) return String(source[0].id || "")

  var origin = center(current)
  var alignedCandidates = []
  var diagonalCandidates = []
  for (var candidateIndex = 0; candidateIndex < source.length; candidateIndex++) {
    var tile = source[candidateIndex]
    if (!tile || tile === current) continue
    var point = center(tile)
    var deltaX = point.x - origin.x
    var deltaY = point.y - origin.y
    var primary = deltaX * vector.x + deltaY * vector.y
    if (primary <= 0) continue
    var cross = Math.abs(deltaX * vector.y - deltaY * vector.x)
    var entry = {
      id: String(tile.id || ""),
      primary: primary,
      cross: cross,
      distance: deltaX * deltaX + deltaY * deltaY,
      order: candidateIndex
    }
    if (overlapsPerpendicular(current, tile, direction)) alignedCandidates.push(entry)
    else diagonalCandidates.push(entry)
  }

  var candidates = alignedCandidates.length > 0 ? alignedCandidates : diagonalCandidates
  candidates.sort(function(left, right) {
    if (alignedCandidates.length === 0) {
      var leftAngle = left.cross / left.primary
      var rightAngle = right.cross / right.primary
      if (leftAngle !== rightAngle) return leftAngle - rightAngle
    }
    if (left.primary !== right.primary) return left.primary - right.primary
    if (left.cross !== right.cross) return left.cross - right.cross
    if (left.distance !== right.distance) return left.distance - right.distance
    return left.order - right.order
  })
  return candidates.length > 0 ? candidates[0].id : String(current.id || "")
}

function sequential(tiles, currentId, delta) {
  var source = readingOrder(tiles)
  if (source.length === 0) return ""
  var currentIndex = -1
  for (var index = 0; index < source.length; index++) {
    if (String(source[index].id || "") === String(currentId || "")) {
      currentIndex = index
      break
    }
  }
  if (currentIndex < 0) return String(source[0].id || "")
  var step = Number(delta) < 0 ? -1 : 1
  return String(source[(currentIndex + step + source.length) % source.length].id || "")
}
