.pragma library

var FALLBACKS = {
  "omarchy.audio": "󰕾",
  "omarchy.bluetooth": "󰂯",
  "omarchy.network": "󰤨",
  "omarchy.power": "󰁹",
  "omarchy.monitor": "󰍹",
  "omarchy.clock": "󰥔",
  "omarchy.weather": "󰖐",
  "omarchy.clipboard": "󰅌",
  "omarchy.emojis": "󰞅",
  "omarchy.image-picker": "󰋩",
  "omarchy.menu": "󰍜",
  "omarchy.agents": "󱚣",
  "omarchy.reminders": "󰃭",
  "omarchy.wifiqr": "󰖩",
  "omarchy.speedtest": "󰓅",
  "omarchy.disk-speedtest": "󰋊",
  "omarchy.tailscale": "󰖂",
  "omarchy.dropbox": "󰇣",
  "omarchy.lock": "󰌾",
  "omarchy.background": "󰸉",
  "omarchy.notifications": "󰂚",
  "omarchy.media": "󰝚",
  "omarchy.tray": "󰕰"
}

function glyph(value) {
  var source = String(value || "")
  if (source.length > 16) return ""
  var text = source.trim()
  if (!text || Array.from(text).length > 4) return ""
  for (var character of Array.from(text)) {
    var point = character.codePointAt(0)
    if ((point >= 0xe000 && point <= 0xf8ff) || point >= 0xf0000) return text
    if (point >= 0x2300 && !(/[\p{L}\p{N}]/u.test(character))) return text
  }
  return ""
}

function candidate(value) {
  if (!value) return null
  if (typeof value === "object" && value.kind && value.value)
    return { kind: String(value.kind), value: String(value.value) }
  var resolved = glyph(value)
  return resolved ? { kind: "glyph", value: resolved } : null
}

function manifestCandidate(manifest) {
  var source = manifest || ({})
  var dashboard = source.dashboard || ({})
  var bar = source.barWidget || ({})
  return candidate(dashboard.icon) || candidate(source.icon)
    || candidate(bar.icon) || candidate(bar.iconName)
}

function liveCandidate(widget) {
  if (!widget) return null
  var names = ["icon", "heroGlyph", "glyph", "iconText", "text"]
  for (var index = 0; index < names.length; index++) {
    try {
      var result = candidate(widget[names[index]])
      if (result) return result
    } catch (error) {}
  }
  return null
}

function keywordFallback(manifest) {
  var source = manifest || ({})
  var id = String(source.id || "").slice(0, 160)
  if (FALLBACKS[id]) return FALLBACKS[id]
  var haystack = (id + " " + String(source.name || "").slice(0, 160)).toLowerCase()
  var keywords = [
    ["bluetooth", "󰂯"], ["audio", "󰕾"], ["volume", "󰕾"],
    ["network", "󰤨"], ["wifi", "󰤨"], ["vpn", "󰖂"],
    ["monitor", "󰍹"], ["display", "󰍹"], ["power", "󰁹"],
    ["battery", "󰁹"], ["weather", "󰖐"], ["clock", "󰥔"],
    ["calendar", "󰃭"], ["notification", "󰂚"], ["clipboard", "󰅌"],
    ["agent", "󱚣"], ["lock", "󰌾"], ["image", "󰋩"],
    ["emoji", "󰞅"], ["workspace", "󰍹"], ["tray", "󰕰"]
  ]
  for (var index = 0; index < keywords.length; index++)
    if (haystack.indexOf(keywords[index][0]) >= 0) return keywords[index][1]
  var kinds = Array.isArray(source.kinds) ? source.kinds : []
  if (kinds.indexOf("service") >= 0) return "󰒓"
  if (kinds.indexOf("overlay") >= 0) return "󰘔"
  if (kinds.indexOf("panel") >= 0 || kinds.indexOf("bar-widget") >= 0) return "󰕮"
  return "󰏗"
}

// One small interface hides all icon sources from callers. Explicit manifest
// metadata wins, then a live widget, then the read-only scanner, then fallback.
function resolve(manifest, scanned, liveWidget) {
  return manifestCandidate(manifest)
    || liveCandidate(liveWidget)
    || candidate(scanned)
    || { kind: "glyph", value: keywordFallback(manifest) }
}
