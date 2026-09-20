.pragma library

// Inline plugin settings live in the bar layout of the public Shell config.
// Third-party plugins receive that config as `shell.barConfig`, so their own
// entry is resolved here rather than through the host registry, which scoped
// plugins no longer receive.

function fromBarLayout(barConfig, id) {
  var wanted = String(id || "")
  if (!wanted || !barConfig || typeof barConfig !== "object" || !barConfig.layout) return null
  var layout = barConfig.layout
  var sections = ["left", "center", "right"]
  for (var section = 0; section < sections.length; section++) {
    var entries = layout[sections[section]]
    if (!Array.isArray(entries)) continue
    for (var index = 0; index < entries.length; index++) {
      var entry = entries[index]
      if (!entry) continue
      var entryId = typeof entry === "object" ? String(entry.id || "") : String(entry)
      if (entryId === wanted) return typeof entry === "object" ? entry : ({ id: entryId })
    }
  }
  return null
}

// A settings write replaces the whole entry, so carry the current keys over and
// only drop the identity key the Shell re-adds itself.
function withSetting(settings, name, value) {
  var source = settings && typeof settings === "object" ? settings : ({})
  var next = ({})
  for (var key in source) if (key !== "id") next[key] = source[key]
  next[String(name)] = value
  return next
}
