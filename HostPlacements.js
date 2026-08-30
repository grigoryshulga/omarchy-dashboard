// Host-scoped plugin references stored in shell.json.
//
// Omarchy 4.0.1 ignores `hosts`, so PluginRuntime keeps `plugins[]` as a
// compatibility adapter. Dashboard owns visual geometry in its state file;
// this module only records which plugin instance belongs to which host.

function plainObject(value) {
  return value !== null && typeof value === "object" && !Array.isArray(value)
}

function safeId(value) {
  var id = String(value || "").trim()
  if (!id || id.length > 160 || id === "." || id === "..") return ""
  if (id.indexOf("/") >= 0 || id.indexOf("..") >= 0) return ""
  for (var index = 0; index < id.length; index++)
    if (id.charCodeAt(index) < 32) return ""
  return id
}

function host(config, hostId, create) {
  if (!plainObject(config)) return null
  var id = safeId(hostId)
  if (!id) return null
  if (!plainObject(config.hosts)) {
    if (!create) return null
    config.hosts = ({})
  }
  if (!plainObject(config.hosts[id])) {
    if (!create) return null
    config.hosts[id] = { placements: [] }
  }
  if (!Array.isArray(config.hosts[id].placements)) {
    if (!create) return null
    config.hosts[id].placements = []
  }
  return config.hosts[id]
}

function entries(config, hostId) {
  var record = host(config, hostId, false)
  if (!record) return []
  var result = []
  var usedInstances = ({})
  for (var index = 0; index < record.placements.length; index++) {
    var source = record.placements[index]
    if (!plainObject(source)) continue
    var pluginId = safeId(source.id)
    var instanceId = safeId(source.instanceId)
    if (!pluginId || !instanceId || usedInstances[instanceId]) continue
    usedInstances[instanceId] = true
    result.push({
      id: pluginId,
      instanceId: instanceId,
      slot: safeId(source.slot),
      settings: plainObject(source.settings) ? source.settings : ({})
    })
  }
  return result
}

function references(document) {
  var result = []
  var usedPlugins = ({})
  var spaces = plainObject(document) && Array.isArray(document.spaces) ? document.spaces : []
  for (var spaceIndex = 0; spaceIndex < spaces.length; spaceIndex++) {
    var space = spaces[spaceIndex]
    var spaceId = safeId(space && space.id)
    var tiles = space && Array.isArray(space.tiles) ? space.tiles : []
    for (var tileIndex = 0; tileIndex < tiles.length; tileIndex++) {
      var tile = tiles[tileIndex]
      var pluginId = safeId(tile && tile.pluginId)
      var instanceId = safeId(tile && tile.id)
      if (!pluginId || !instanceId || usedPlugins[pluginId]) continue
      usedPlugins[pluginId] = true
      result.push({ id: pluginId, instanceId: instanceId, slot: spaceId })
    }
  }
  return result
}

function synchronize(config, hostId, desiredReferences) {
  if (!plainObject(config) || !safeId(hostId)) return false
  var desired = Array.isArray(desiredReferences) ? desiredReferences : []
  var existing = entries(config, hostId)
  var existingByInstance = ({})
  var existingByPlugin = ({})
  for (var oldIndex = 0; oldIndex < existing.length; oldIndex++) {
    existingByInstance[existing[oldIndex].instanceId] = existing[oldIndex]
    existingByPlugin[existing[oldIndex].id] = existing[oldIndex]
  }

  var next = []
  var usedPlugins = ({})
  var usedInstances = ({})
  for (var index = 0; index < desired.length; index++) {
    var source = desired[index]
    var pluginId = safeId(source && source.id)
    var instanceId = safeId(source && source.instanceId)
    if (!pluginId || !instanceId || usedPlugins[pluginId] || usedInstances[instanceId]) continue
    usedPlugins[pluginId] = true
    usedInstances[instanceId] = true
    var previous = existingByInstance[instanceId] || existingByPlugin[pluginId]
    next.push({
      id: pluginId,
      instanceId: instanceId,
      slot: safeId(source.slot),
      settings: previous && plainObject(previous.settings) ? previous.settings : ({})
    })
  }

  var record = host(config, hostId, next.length > 0)
  if (record) record.placements = next
  if (next.length === 0 && plainObject(config.hosts)) {
    delete config.hosts[safeId(hostId)]
    if (Object.keys(config.hosts).length === 0) delete config.hosts
  }
  return true
}

function settingsFor(config, hostId, pluginId, instanceId) {
  var wantedPlugin = safeId(pluginId)
  var wantedInstance = safeId(instanceId)
  var current = entries(config, hostId)
  for (var index = 0; index < current.length; index++) {
    if (wantedInstance && current[index].instanceId === wantedInstance) return current[index].settings
    if (!wantedInstance && current[index].id === wantedPlugin) return current[index].settings
  }
  return ({})
}
