.pragma library

function center(tile) {
  return {
    x: Number(tile.x || 0) + Number(tile.w || 1) / 2,
    y: Number(tile.y || 0) + Number(tile.h || 1) / 2
  }
}

function directionVector(direction) {
  if (direction === "left") return { x: -1, y: 0 }
  if (direction === "right") return { x: 1, y: 0 }
  if (direction === "up") return { x: 0, y: -1 }
  if (direction === "down") return { x: 0, y: 1 }
  return null
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
  var candidates = []
  for (var candidateIndex = 0; candidateIndex < source.length; candidateIndex++) {
    var tile = source[candidateIndex]
    if (!tile || tile === current) continue
    var point = center(tile)
    var deltaX = point.x - origin.x
    var deltaY = point.y - origin.y
    var primary = deltaX * vector.x + deltaY * vector.y
    if (primary <= 0) continue
    var cross = Math.abs(deltaX * vector.y - deltaY * vector.x)
    candidates.push({
      id: String(tile.id || ""),
      primary: primary,
      cross: cross,
      distance: deltaX * deltaX + deltaY * deltaY,
      order: candidateIndex
    })
  }
  candidates.sort(function(left, right) {
    if (left.primary !== right.primary) return left.primary - right.primary
    if (left.cross !== right.cross) return left.cross - right.cross
    if (left.distance !== right.distance) return left.distance - right.distance
    return left.order - right.order
  })
  return candidates.length > 0 ? candidates[0].id : String(current.id || "")
}

function sequential(tiles, currentId, delta) {
  var source = Array.isArray(tiles) ? tiles : []
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
