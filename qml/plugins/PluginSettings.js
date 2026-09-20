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

// Layer not-yet-published writes over the persisted entry. Used as the merge
// base so a quick second write cannot drop the first one while the scoped API
// is still republishing `barConfig`.
function withOverrides(settings, overrides) {
  var source = settings && typeof settings === "object" ? settings : ({})
  var next = ({})
  for (var key in source) if (key !== "id") next[key] = source[key]
  var pending = overrides && typeof overrides === "object" ? overrides : ({})
  for (var name in pending) next[name] = pending[name]
  return next
}

// Decide which optimistic echoes to keep. A value the persisted entry now
// matches is confirmed and dropped; a key it does not contain is still
// unpublished and kept. A differing value is also kept: the scoped API can
// republish a stale config after one of our own writes, and adopting that would
// flip the UI back to the value the user just replaced.
function settleOverrides(overrides, stored) {
  var source = overrides && typeof overrides === "object" ? overrides : ({})
  var persisted = stored && typeof stored === "object" ? stored : ({})
  var kept = ({})
  var settled = false
  for (var name in source) {
    if (persisted[name] === source[name]) { settled = true; continue }
    kept[name] = source[name]
  }
  return { overrides: kept, settled: settled }
}
