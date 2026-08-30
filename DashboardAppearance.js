.pragma library

var FRAMED = "framed"
var GLASS = "glass"

function surfaceMode(value) {
  var normalized = String(value === undefined || value === null ? "" : value)
    .replace(/^\s+|\s+$/g, "").toLowerCase()
  if (normalized === FRAMED || normalized === GLASS)
    return normalized
  // Push existed before v1.6.2. Treat stale settings as Glass without
  // rewriting the user's shell configuration.
  return GLASS
}

function usesGlass(value) {
  return surfaceMode(value) !== FRAMED
}
