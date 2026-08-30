.pragma library

var DEFAULTS = {
  enabled: true,
  size: 8,
  passes: 1,
  brightness: 1,
  contrast: 1,
  vibrancy: 0
}

function optionValue(entry) {
  if (entry.bool !== undefined) return entry.bool
  if (entry.int !== undefined) return entry.int
  if (entry.float !== undefined) return entry.float
  return undefined
}

function parse(raw, previous) {
  var result = Object.assign({}, DEFAULTS, previous || {})
  var objects = String(raw || "").match(/\{[^{}]*\}/g) || []
  for (var index = 0; index < objects.length; index++) {
    try {
      var entry = JSON.parse(objects[index])
      var key = String(entry.option || "").replace(/^decoration:blur:/, "")
      var value = optionValue(entry)
      if (value !== undefined && result[key] !== undefined) result[key] = value
    } catch (error) {}
  }
  return result
}

function clamp(value, minimum, maximum) {
  return Math.max(minimum, Math.min(maximum, Number(value)))
}

function effect(options) {
  var source = Object.assign({}, DEFAULTS, options || {})
  var size = clamp(source.size, 1, 64)
  var passes = clamp(source.passes, 1, 8)
  return {
    enabled: source.enabled === true,
    blurMax: Math.round(clamp(size * passes * 4, 16, 128)),
    brightness: clamp(Number(source.brightness) - 1, -1, 1),
    contrast: clamp(Number(source.contrast) - 1, -1, 1),
    saturation: clamp(source.vibrancy, -1, 1)
  }
}
