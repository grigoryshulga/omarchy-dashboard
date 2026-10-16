.pragma library

// Pure normalization for Omarchy Shell's qs.Commons tokens. This library never
// throws and never imports Quickshell, so HostChrome.qml and the unit tests
// can load it in any engine, against a complete system or a stub.

// Mirrors the installed shell: the initial palette in Commons/Color.qml and
// Commons/Style.qml's own fallbacks at spacing scale 1.0. Update these together
// with the shell sources; never invent sizes.
var DEFAULTS = {
  background: "#101315",
  foreground: "#cacccc",
  accent: "#cacccc",
  urgent: "#a55555",
  muted: "#707880",

  // Color.qml composes the popup surfaces from the foundational palette.
  popupBackground: "#101315",
  popupText: "#cacccc",
  popupBorder: "#cacccc",

  cornerRadius: 0,
  gapsOut: 5,
  borderWidth: 1,

  fontFamily: "monospace",
  fontTitle: 14,
  fontSubtitle: 13,
  fontBody: 12,
  fontBodySmall: 11,
  fontCaption: 10,

  spaceXs: 3,
  spaceSm: 4,
  spaceMd: 6,
  spaceLg: 8,
  panelPadding: 18,
  panelGap: 14,
  controlPaddingY: 6
}

// menu.scrim falls back to the background color at half opacity.
DEFAULTS.menuScrim = alpha(DEFAULTS.background, 0.5)

function isFiniteNumber(value) {
  return typeof value === "number" && isFinite(value)
}

function clamp01(value) {
  if (!isFiniteNumber(value)) return 0
  return Math.min(1, Math.max(0, value))
}

// True for a QML color (an object with finite r, g, b channels) or for a
// #RGB, #RRGGBB or #AARRGGBB string. Named colors are not accepted so a
// typo can never masquerade as a theme value.
function isColor(value) {
  if (value !== null && typeof value === "object") {
    return isFiniteNumber(value.r) && isFiniteNumber(value.g) && isFiniteNumber(value.b)
  }
  return typeof value === "string" && /^#(?:[0-9A-Fa-f]{3}|[0-9A-Fa-f]{6}|[0-9A-Fa-f]{8})$/.test(value)
}

// Channel breakdown for anything isColor accepts, or null. Hex strings are
// parsed here so alpha() never has to trust a live object's channels.
function colorComponents(value) {
  if (value !== null && typeof value === "object") {
    if (!isFiniteNumber(value.r) || !isFiniteNumber(value.g) || !isFiniteNumber(value.b)) return null
    return { r: value.r, g: value.g, b: value.b, a: isFiniteNumber(value.a) ? value.a : 1 }
  }
  if (typeof value !== "string") return null
  var hex = value.match(/^#([0-9A-Fa-f]{3}|[0-9A-Fa-f]{6}|[0-9A-Fa-f]{8})$/)
  if (!hex) return null
  var digits = hex[1]
  if (digits.length === 3) {
    return {
      r: parseInt(digits.charAt(0) + digits.charAt(0), 16) / 255,
      g: parseInt(digits.charAt(1) + digits.charAt(1), 16) / 255,
      b: parseInt(digits.charAt(2) + digits.charAt(2), 16) / 255,
      a: 1
    }
  }
  if (digits.length === 6) {
    return {
      r: parseInt(digits.slice(0, 2), 16) / 255,
      g: parseInt(digits.slice(2, 4), 16) / 255,
      b: parseInt(digits.slice(4, 6), 16) / 255,
      a: 1
    }
  }
  // #AARRGGBB: alpha comes first.
  return {
    r: parseInt(digits.slice(2, 4), 16) / 255,
    g: parseInt(digits.slice(4, 6), 16) / 255,
    b: parseInt(digits.slice(6, 8), 16) / 255,
    a: parseInt(digits.slice(0, 2), 16) / 255
  }
}

// Always returns a fresh Qt.rgba value that is safe to assign to a
// `property color`. Invalid, undefined or null input yields the fallback; a
// fallback that is itself invalid yields transparent black. Callers never
// hold a live system color object.
function colorOr(value, fallback) {
  var parts = colorComponents(value)
  if (parts === null) parts = colorComponents(fallback)
  if (parts === null) parts = { r: 0, g: 0, b: 0, a: 0 }
  return Qt.rgba(clamp01(parts.r), clamp01(parts.g), clamp01(parts.b), clamp01(parts.a))
}

// Finite numbers are rounded and clamped to the optional bounds; everything
// else (undefined, null, empty, non-numeric) returns the fallback.
function intOr(value, fallback, min, max) {
  if (value === undefined || value === null || value === "") return fallback
  var n = Number(value)
  if (!isFiniteNumber(n)) return fallback
  n = Math.round(n)
  if (isFiniteNumber(min)) n = Math.max(min, n)
  if (isFiniteNumber(max)) n = Math.min(max, n)
  return n
}

function textOr(value, fallback) {
  return typeof value === "string" && value.length > 0 ? value : fallback
}

// Spacing resolution shared by HostChrome.space. Prefers the system
// Style.space helper (result rounded, floored at 0); when it is missing,
// throws or yields nothing finite, applies the same fallback curve the shell
// uses locally: 0 for non-positive or non-finite pixels, at least 1px above.
function spaceOr(px, styleSpaceFn) {
  if (typeof styleSpaceFn === "function") {
    try {
      var scaled = styleSpaceFn(px)
      if (isFiniteNumber(scaled)) return intOr(scaled, 0, 0)
    } catch (e) {
      // System helper threw; fall through to the local fallback.
    }
  }
  var p = Number(px)
  if (!isFiniteNumber(p) || p <= 0) return 0
  return Math.max(1, Math.round(p))
}

// Recolors a validated color to the given opacity. Never throws: an invalid
// color degrades to transparent black and a non-finite opacity keeps the
// color's own alpha.
function alpha(color, opacity) {
  var parts = colorComponents(color)
  if (parts === null) parts = { r: 0, g: 0, b: 0, a: 0 }
  var o = Number(opacity)
  if (!isFiniteNumber(o)) o = parts.a
  return Qt.rgba(clamp01(parts.r), clamp01(parts.g), clamp01(parts.b), clamp01(o))
}
