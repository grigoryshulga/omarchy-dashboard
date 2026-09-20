.pragma library

var MAX_PLUGIN_ID_LENGTH = 160
var MAX_PLUGIN_NAME_LENGTH = 160
var MAX_PLUGIN_DESCRIPTION_LENGTH = 1024

function boundedText(value, maximum) {
  var text = value === undefined || value === null ? "" : String(value)
  return text.length > maximum ? text.slice(0, maximum) : text
}

function safePluginId(value) {
  var id = boundedText(value, MAX_PLUGIN_ID_LENGTH).trim()
  if (!id || !/^[A-Za-z0-9][A-Za-z0-9._-]*$/.test(id)) return ""
  return ["__proto__", "prototype", "constructor"].indexOf(id) >= 0 ? "" : id
}

function parseJsonArray(raw) {
  try {
    var parsed = JSON.parse(String(raw || ""))
    return Array.isArray(parsed) ? parsed : []
  } catch (error) {
    return []
  }
}

function safeSourceDirectory(value) {
  var directory = boundedText(value, 1024)
  return directory.charAt(0) === "/" && directory.indexOf("\0") < 0
    && directory.indexOf("\n") < 0 && directory.indexOf("\r") < 0 ? directory.replace(/\/+$/, "") : ""
}

// The installed set and its manifests only change when the registry changes.
// Comparing the two public helper outputs lets the runtime keep already
// validated adaptations resident instead of repeating adapter work on every
// Dashboard open. The NUL separator keeps the pair unambiguous.
function catalogSourcesKey(listRaw, catalogRaw) {
  return String(listRaw || "") + "\u0000" + String(catalogRaw || "")
}

// Copy a lookup table without one key so a single plugin can be invalidated
// without rebuilding the whole object graph.
function withoutKey(source, key) {
  var wanted = String(key || "")
  var result = ({})
  var table = source && typeof source === "object" ? source : ({})
  for (var current in table)
    if (current !== wanted) result[current] = table[current]
  return result
}

function catalogFromPublicSources(listRaw, catalogRaw, ownPluginId) {
  var catalog = parseJsonArray(catalogRaw)
  var manifests = ({})
  for (var catalogIndex = 0; catalogIndex < catalog.length; catalogIndex++) {
    var candidate = catalog[catalogIndex]
    if (!candidate || typeof candidate !== "object") continue
    var candidateId = safePluginId(candidate.id)
    if (candidateId !== "") manifests[candidateId] = candidate
  }

  var result = []
  var seen = ({})
  var list = parseJsonArray(listRaw)
  for (var listIndex = 0; listIndex < list.length; listIndex++) {
    var row = list[listIndex]
    if (!row || typeof row !== "object") continue
    var id = safePluginId(row.id)
    if (id === "" || id === ownPluginId || seen[id]) continue
    seen[id] = true

    var source = manifests[id] || ({})
    var manifest = ({})
    for (var key in source) manifest[key] = source[key]
    manifest.id = id
    manifest.name = boundedText(source.name || row.name || id, MAX_PLUGIN_NAME_LENGTH)
    manifest.description = boundedText(source.description || "", MAX_PLUGIN_DESCRIPTION_LENGTH)
    manifest.kinds = Array.isArray(source.kinds) ? source.kinds
      : (Array.isArray(row.kinds) ? row.kinds : [])
    manifest.entryPoints = source.entryPoints && typeof source.entryPoints === "object"
      ? source.entryPoints : ({})
    manifest.__sourceDir = safeSourceDirectory(source.sourceDir)
    manifest.__isFirstParty = source.firstParty === true || row.firstParty === true
    manifest.__enabled = row.enabled === true
    result.push(manifest)
  }
  result.sort(function(left, right) {
    return String(left.name || left.id).localeCompare(String(right.name || right.id))
  })
  return result
}
