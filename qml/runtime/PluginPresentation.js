.pragma library

var AUTO = "auto"
var EMBEDDED = "embedded"
var WIDGET = "widget"
var LAUNCHER = "launcher"
var CONTROL = "control"

function normalizePreference(value) {
  var requested = String(value || AUTO)
  if (requested === "explicit" || requested === "standard") return EMBEDDED
  if (requested === "native") return LAUNCHER
  return [AUTO, EMBEDDED, WIDGET, LAUNCHER, CONTROL].indexOf(requested) >= 0 ? requested : AUTO
}

function adaptationEntryPoints(manifest) {
  var entries = (manifest || {}).entryPoints || {}
  var result = []
  // Prefer declared surfaces to the bar wrapper; try every distinct option.
  var names = ["panel", "overlay", "barWidget", "menu"]
  names.forEach(function(name) {
    var value = entries[name]
    if (typeof value === "string" && value.length > 0 && result.indexOf(value) < 0)
      result.push(value)
  })
  return result
}

function capabilities(manifest, options) {
  var source = manifest || ({})
  var entryPoints = source.entryPoints || ({})
  var runtime = options || ({})
  var hasControl = runtime.hasControl === true
  var hasExplicitPage = !!(entryPoints.dashboardPage || entryPoints.sidePanelPage)
  var hasWidget = !!entryPoints.dashboardWidget
  var candidates = adaptationEntryPoints(source)
  var adaptationEntryPoint = candidates.length ? candidates[0] : ""
  var canAdapt = !!(adaptationEntryPoint && source.__sourceDir)
  var hasNativeSurface = !!(entryPoints.panel || entryPoints.overlay || entryPoints.menu)
  var available = []
  if (hasControl) available.push(CONTROL)
  if (hasExplicitPage || canAdapt) available.push(EMBEDDED)
  if (hasWidget) available.push(WIDGET)
  available.push(LAUNCHER)
  return {
    hasControl: hasControl,
    hasExplicitPage: hasExplicitPage,
    hasWidget: hasWidget,
    canAdapt: canAdapt,
    adaptationEntryPoint: adaptationEntryPoint,
    adaptationEntryPoints: candidates,
    hasNativeSurface: hasNativeSurface,
    canLaunch: hasNativeSurface || canAdapt || hasExplicitPage || hasWidget,
    available: available,
    preferred: hasControl ? CONTROL
      : (hasExplicitPage ? EMBEDDED : (hasWidget ? WIDGET : (canAdapt ? EMBEDDED : LAUNCHER)))
  }
}

function capabilityLabel(manifest, options) {
  var result = capabilities(manifest, options)
  if (result.hasControl) return "Dashboard control"
  if (result.hasExplicitPage) return "Embedded page"
  if (result.hasWidget) return "Compact widget"
  if (result.canAdapt) return "Adaptable panel"
  if (result.canLaunch) return "Native launcher"
  return "Information tile"
}

function launcher(caps, runtime, source, state, reason) {
  var nativeAvailable = runtime.nativeAvailable === true
  var canPopout = !!source
  var target = nativeAvailable ? "native" : (canPopout ? "popout" : "")
  var preparing = !target && caps.canAdapt && !runtime.adaptationError
  return {
    kind: LAUNCHER,
    state: state || (preparing ? "preparing" : "ready"),
    source: source || "",
    modeLabel: "Launcher",
    canLaunch: target !== "",
    launchTarget: target,
    available: caps.available,
    reason: reason || (caps.canLaunch
      ? (preparing ? "Preparing an independent Dashboard popout…"
        : (target === "native" ? "Open this plugin in its native Omarchy surface."
          : "Open this plugin in a Dashboard popout."))
      : "This plugin has no visual entry point, but it can stay on the dashboard as an information tile.")
  }
}

function resolve(manifest, preference, sources, options) {
  var runtime = options || ({})
  var caps = capabilities(manifest, runtime)
  var requested = normalizePreference(preference)
  var urls = sources || ({})
  var explicitSource = String(urls.explicit || "")
  var widgetSource = String(urls.widget || "")
  var adaptedSource = String(urls.adapted || "")
  var adaptationError = String(urls.adaptationError || "")
  runtime.adaptationError = adaptationError

  function controlResult() {
    var control = runtime.control || ({})
    return {
      kind: CONTROL,
      state: control.ready === false ? "preparing" : "ready",
      source: "",
      modeLabel: "Control",
      canLaunch: false,
      launchTarget: "",
      available: caps.available,
      active: control.active === true,
      statusText: String(control.statusText || ""),
      reason: ""
    }
  }

  function embeddedResult(source, state, reason) {
    return {
      kind: EMBEDDED,
      state: state,
      source: source,
      modeLabel: "Embedded",
      canLaunch: runtime.nativeAvailable === true || !!adaptedSource,
      launchTarget: runtime.nativeAvailable === true ? "native" : (!!adaptedSource ? "popout" : ""),
      available: caps.available,
      reason: reason || ""
    }
  }

  function widgetResult() {
    return {
      kind: WIDGET,
      state: "ready",
      source: widgetSource,
      modeLabel: "Widget",
      canLaunch: runtime.nativeAvailable === true,
      launchTarget: runtime.nativeAvailable === true ? "native" : "",
      available: caps.available,
      reason: ""
    }
  }

  if (requested === LAUNCHER) return launcher(caps, runtime, explicitSource || adaptedSource || widgetSource)
  if (requested === CONTROL) {
    if (caps.hasControl) return controlResult()
    return launcher(caps, runtime, adaptedSource, "fallback", "This plugin has no Dashboard control adapter.")
  }
  if (requested === WIDGET) {
    if (caps.hasWidget && widgetSource) return widgetResult()
    return launcher(caps, runtime, adaptedSource, "fallback", "This plugin does not provide a dashboard widget.")
  }
  if (requested === EMBEDDED) {
    if (caps.hasExplicitPage && explicitSource) return embeddedResult(explicitSource, "ready")
    if (adaptedSource) return embeddedResult(adaptedSource, "ready")
    if (caps.canAdapt && !adaptationError)
      return embeddedResult("", "preparing", "Preparing the standard Omarchy panel…")
    return launcher(caps, runtime, adaptedSource, "fallback", adaptationError || "This plugin cannot be embedded safely.")
  }

  if (caps.hasControl) return controlResult()
  if (caps.hasExplicitPage && explicitSource) return embeddedResult(explicitSource, "ready")
  if (caps.hasWidget && widgetSource) return widgetResult()
  if (adaptedSource) return embeddedResult(adaptedSource, "ready")
  if (caps.canAdapt && !adaptationError)
    return embeddedResult("", "preparing", "Preparing the standard Omarchy panel…")
  return launcher(caps, runtime, adaptedSource, adaptationError ? "fallback" : "ready", adaptationError)
}
