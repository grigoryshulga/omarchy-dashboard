.pragma library

// Dashboard-owned compatibility profiles for non-visual Omarchy services.
// The foreign plugin remains untouched: this adapter only uses public state
// and methods already consumed by Omarchy's own bar indicators.

var PROFILES = {
  "omarchy.idle": {
    name: "Stay Awake",
    description: "Temporarily disable idle lock and the screensaver.",
    icon: "󰅶",
    activeText: "On",
    inactiveText: "Off"
  },
  "omarchy.nightlight": {
    name: "Night Light",
    description: "Switch the display between day and night temperature.",
    icon: "󰔎",
    activeText: "On",
    inactiveText: "Off"
  },
  "omarchy.notifications": {
    name: "Do Not Disturb",
    description: "Silence notification popups without disabling notifications.",
    icon: "󰂛",
    activeText: "On",
    inactiveText: "Off"
  }
}

function profile(pluginId) {
  return PROFILES[String(pluginId || "")] || null
}

function snapshot(pluginId, service) {
  var definition = profile(pluginId)
  if (!definition) return null
  var id = String(pluginId || "")
  var ready = !!service
  var active = false
  if (id === "omarchy.idle") {
    ready = ready && service.stayAwakeStateLoaded === true
    active = ready && service.stayAwake === true
  } else if (id === "omarchy.nightlight") {
    ready = ready && service.stateLoaded === true
    active = ready && service.enabled === true
  } else if (id === "omarchy.notifications") {
    active = ready && service.doNotDisturb === true
  }
  return {
    name: definition.name,
    description: definition.description,
    icon: definition.icon,
    ready: ready,
    active: active,
    statusText: ready ? (active ? definition.activeText : definition.inactiveText) : "Loading…"
  }
}

function activate(pluginId, service) {
  if (!service) return false
  var id = String(pluginId || "")
  try {
    if (id === "omarchy.idle" && typeof service.setIdleEnabled === "function") {
      service.setIdleEnabled(service.stayAwake === true)
      return true
    }
    if (id === "omarchy.nightlight" && typeof service.setNightlight === "function") {
      service.setNightlight(service.enabled !== true)
      return true
    }
    if (id === "omarchy.notifications" && typeof service.setDoNotDisturb === "function") {
      service.setDoNotDisturb(service.doNotDisturb !== true)
      return true
    }
  } catch (error) {
    console.warn("Dashboard: control activation failed for " + id + ":", error)
  }
  return false
}
