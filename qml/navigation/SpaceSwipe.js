.pragma library

var MIN_DISTANCE = 96

function directionForTranslation(horizontal, vertical) {
  var x = Number(horizontal) || 0
  var y = Number(vertical) || 0
  if (Math.abs(x) < MIN_DISTANCE || Math.abs(x) <= Math.abs(y)) return 0
  return x < 0 ? 1 : -1
}
