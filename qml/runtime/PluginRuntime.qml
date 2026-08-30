import QtQuick
import Quickshell.Io
import qs.Commons
import "../core/GridEngine.js" as GridEngine
import "../core/HostPlacements.js" as HostPlacements
import "PluginControls.js" as PluginControls
import "PluginIconResolver.js" as PluginIconResolver
import "PluginPresentation.js" as PluginPresentation

Item {
  id: root

  readonly property int maxPluginIdLength: 160
  readonly property int maxPluginNameLength: 160
  readonly property int maxPluginDescriptionLength: 1024
  readonly property int maxDiscoveredPlugins: 512
  readonly property int maxHelperOutputLength: 1024 * 1024

  required property var dashboardHost
  required property var shell
  required property var registry
  required property string dashboardPluginId
  required property string pluginDirectory
  required property string cacheRoot
  property bool active: false
  property var tiles: []
  property var spaces: []
  property var pendingPlacements: []

  property var adaptations: ({})
  property var adaptationErrors: ({})
  property string adaptingPluginId: ""
  property int pluginEpoch: 0
  property var scannedIcons: ({})

  // Adapted bar panels are rendered inside the Dashboard surface, not on the
  // bar. Give them Dashboard's foreground palette while retaining the shell
  // reference that plugins use for settings and services.
  QtObject {
    id: dashboardBar

    property color barForeground: Color.popups.text
    property color foreground: Color.popups.text
    property color urgent: Color.accent
    property string fontFamily: Style.font.family
    property var shell: root.shell
  }

  readonly property int registryRevision: registry ? registry.registryRevision : 0
  readonly property var availablePlugins: discoverAvailablePlugins()
  readonly property var hostEntries: HostPlacements.entries(
    shell ? shell.shellConfig : null, dashboardPluginId)

  function boundedText(value, maximum) {
    var text = value === undefined || value === null ? "" : String(value)
    return text.length > maximum ? text.slice(0, maximum) : text
  }

  function safePluginId(value) {
    var id = boundedText(value, maxPluginIdLength).trim()
    if (!id || !/^[A-Za-z0-9][A-Za-z0-9._-]*$/.test(id)) return ""
    return ["__proto__", "prototype", "constructor"].indexOf(id) >= 0 ? "" : id
  }

  function descriptor(id) {
    if (!registry || !registry.installedPlugins) return null
    var resolved = typeof registry.resolveEnabledId === "function" ? registry.resolveEnabledId(id) : id
    resolved = safePluginId(resolved)
    if (!resolved) return null
    var pluginManifest = registry.installedPlugins[resolved]
    if (!pluginManifest) return null
    var controlProfile = PluginControls.profile(resolved)
    var capabilities = PluginPresentation.capabilities(pluginManifest, { hasControl: !!controlProfile })
    var icon = pluginIcon(pluginManifest)
    return {
      id: resolved,
      name: boundedText(controlProfile ? controlProfile.name : (pluginManifest.name || resolved),
                        maxPluginNameLength),
      description: boundedText(
        controlProfile ? controlProfile.description : (pluginManifest.description || ""),
        maxPluginDescriptionLength),
      compatibility: PluginPresentation.capabilityLabel(pluginManifest, { hasControl: !!controlProfile }),
      availablePresentations: capabilities.available,
      preferredPresentation: capabilities.preferred,
      canLaunchNative: capabilities.hasNativeSurface,
      pending: isPending(resolved),
      icon: icon.value,
      iconKind: icon.kind,
      manifest: pluginManifest
    }
  }

  function isPending(id) {
    var pending = Array.isArray(pendingPlacements) ? pendingPlacements : []
    for (var index = 0; index < pending.length; index++)
      if (pending[index] && String(pending[index].pluginId) === String(id)) return true
    return false
  }

  function discoverAvailablePlugins() {
    var revision = registryRevision
    if (!registry || !registry.installedPlugins) return []
    var used = ({})
    var sourceSpaces = Array.isArray(spaces) ? spaces : []
    for (var spaceIndex = 0; spaceIndex < sourceSpaces.length; spaceIndex++) {
      var spaceTiles = sourceSpaces[spaceIndex].tiles || []
      for (var tileIndex = 0; tileIndex < spaceTiles.length; tileIndex++) used[spaceTiles[tileIndex].pluginId] = true
    }
    var entries = []
    var manifests = registry.installedPlugins
    var inspected = 0
    for (var id in manifests) {
      inspected += 1
      if (entries.length >= maxDiscoveredPlugins || inspected > maxDiscoveredPlugins * 2) break
      var entry = descriptor(id)
      if (!entry || entry.id === dashboardPluginId || used[entry.id]) continue
      entries.push(entry)
    }
    entries.sort(function(left, right) {
      if (left.pending !== right.pending) return left.pending ? -1 : 1
      return left.name.localeCompare(right.name)
    })
    return entries
  }

  function sizeHints(id, boundWidth, boundHeight) {
    var entry = descriptor(id)
    var metadata = entry && entry.manifest && entry.manifest.dashboard
      ? entry.manifest.dashboard : ({})
    function boundedPixels(value, fallback, maximum) {
      var number = Number(value)
      return isFinite(number)
        ? Math.max(GridEngine.STEP, Math.min(maximum, GridEngine.snap(number))) : fallback
    }
    var legacyMinW = metadata.minColumns !== undefined ? Number(metadata.minColumns) * 80 : undefined
    var legacyMinH = metadata.minRows !== undefined ? Number(metadata.minRows) * 70 : undefined
    var legacyPreferredW = metadata.preferredColumns !== undefined ? Number(metadata.preferredColumns) * 80 : undefined
    var legacyPreferredH = metadata.preferredRows !== undefined ? Number(metadata.preferredRows) * 70 : undefined
    var compactControl = !!PluginControls.profile(id)
    var minW = boundedPixels(metadata.minWidth !== undefined ? metadata.minWidth : legacyMinW,
                             compactControl ? 150 : 160, boundWidth)
    var minH = boundedPixels(metadata.minHeight !== undefined ? metadata.minHeight : legacyMinH,
                             compactControl ? 90 : 120, boundHeight)
    return {
      minW: minW,
      minH: minH,
      preferredW: Math.max(minW, boundedPixels(
        metadata.preferredWidth !== undefined ? metadata.preferredWidth : legacyPreferredW,
        compactControl ? 210 : 360, boundWidth)),
      preferredH: Math.max(minH, boundedPixels(
        metadata.preferredHeight !== undefined ? metadata.preferredHeight : legacyPreferredH,
        compactControl ? 120 : 260, boundHeight))
    }
  }

  function enable(id, pluginManifest) {
    if (!shell || !shell.pluginRegistry) return false
    if (typeof shell.mutateShellConfig !== "function") return false
    try {
      shell.mutateShellConfig(function(config) {
        var disabled = Array.isArray(config.disabledPlugins) ? config.disabledPlugins : []
        config.disabledPlugins = disabled.filter(function(entry) { return String(entry) !== id })
        if (config.disabledPlugins.length === 0) delete config.disabledPlugins
        if (pluginManifest && pluginManifest.__isFirstParty) return
        // Compatibility adapter for Omarchy 4.0.1. The native reference lives
        // in config.hosts; the current shell still consults plugins[] when it
        // decides whether to load a third-party component/service.
        if (!Array.isArray(config.plugins)) config.plugins = []
        for (var index = 0; index < config.plugins.length; index++)
          if (config.plugins[index] && String(config.plugins[index].id) === id) return
        config.plugins.push({ id: id })
      })
      return true
    } catch (error) {
      console.warn("Dashboard: failed to enable " + id + ":", error)
      return false
    }
  }

  function syncHostPlacements(document) {
    if (!shell || typeof shell.mutateShellConfig !== "function") return false
    var desired = HostPlacements.references(document)
    try {
      shell.mutateShellConfig(function(config) {
        HostPlacements.synchronize(config, dashboardPluginId, desired)
        // Keep current Omarchy able to load every third-party hosted plugin.
        if (!Array.isArray(config.plugins)) config.plugins = []
        for (var index = 0; index < desired.length; index++) {
          var id = desired[index].id
          var manifest = registry && registry.installedPlugins ? registry.installedPlugins[id] : null
          if (manifest && manifest.__isFirstParty) continue
          var found = false
          for (var pluginIndex = 0; pluginIndex < config.plugins.length; pluginIndex++)
            if (config.plugins[pluginIndex] && String(config.plugins[pluginIndex].id) === id) found = true
          if (!found) config.plugins.push({ id: id })
        }
      })
      return true
    } catch (error) {
      console.warn("Dashboard: failed to synchronize host placements:", error)
      return false
    }
  }

  function explicitPageUrl(pluginId) {
    var entry = descriptor(pluginId)
    if (!entry || !registry) return ""
    var entryPoints = entry.manifest.entryPoints || ({})
    if (entryPoints.dashboardPage) return registry.entryPointUrl(entry.manifest, "dashboardPage")
    if (entryPoints.sidePanelPage) return registry.entryPointUrl(entry.manifest, "sidePanelPage")
    return ""
  }

  function widgetPageUrl(pluginId) {
    var entry = descriptor(pluginId)
    if (!entry || !registry || !entry.manifest.entryPoints
        || !entry.manifest.entryPoints.dashboardWidget) return ""
    return registry.entryPointUrl(entry.manifest, "dashboardWidget")
  }

  function versionedUrl(url) {
    var source = String(url || "")
    return source ? source + (source.indexOf("?") >= 0 ? "&" : "?") + "dashboardEpoch=" + pluginEpoch : ""
  }

  function pageSource(pluginId) {
    var prepared = adaptations[pluginId] || ({})
    return versionedUrl(explicitPageUrl(pluginId) || String(prepared.url || ""))
  }

  function pluginService(pluginId) {
    return shell && typeof shell.serviceFor === "function" ? shell.serviceFor(pluginId) : null
  }

  function controlSnapshot(pluginId) {
    return PluginControls.snapshot(pluginId, pluginService(pluginId))
  }

  function activateControl(pluginId) {
    return PluginControls.activate(pluginId, pluginService(pluginId))
  }

  function nativeAvailable(pluginId) {
    var entry = descriptor(pluginId)
    if (!entry) return false
    var capabilities = PluginPresentation.capabilities(entry.manifest, {
      hasControl: !!PluginControls.profile(pluginId)
    })
    if (capabilities.hasNativeSurface) return true
    if (!entry.manifest.entryPoints || !entry.manifest.entryPoints.barWidget) return false
    try {
      return !!(shell && shell.bar && typeof shell.bar.findPanelWidget === "function"
        && shell.bar.findPanelWidget(pluginId))
    } catch (error) {
      console.warn("Dashboard: native bar-widget lookup failed for " + pluginId + ":", error)
      return false
    }
  }

  function presentation(tile) {
    var pluginId = tile ? String(tile.pluginId || "") : ""
    var entry = descriptor(pluginId)
    if (!entry) return {
      kind: "launcher", state: "missing", source: "", modeLabel: "Launcher",
      name: tile && tile.label ? String(tile.label) : pluginId,
      description: "This plugin is no longer installed.", reason: "Install the plugin to use this tile.",
      canLaunch: false, available: ["launcher"], icon: "󰅙"
    }
    var control = controlSnapshot(pluginId)
    var prepared = adaptations[pluginId] || ({})
    var resolved = PluginPresentation.resolve(entry.manifest, tile ? tile.embedding : "auto", {
      explicit: versionedUrl(explicitPageUrl(pluginId)),
      widget: versionedUrl(widgetPageUrl(pluginId)),
      adapted: versionedUrl(String(prepared.url || "")),
      adaptationError: String(adaptationErrors[pluginId] || "")
    }, {
      hasControl: !!PluginControls.profile(pluginId),
      control: control,
      nativeAvailable: nativeAvailable(pluginId)
    })
    resolved.name = control ? control.name : entry.name
    resolved.description = control ? control.description : entry.description
    resolved.pluginId = entry.id
    var icon = control ? { kind: "glyph", value: control.icon } : pluginIcon(entry.manifest)
    resolved.icon = icon.value
    resolved.iconKind = icon.kind
    resolved.contentLayout = String(prepared.layout || "padded")
    return resolved
  }

  function pluginIcon(pluginManifest) {
    var id = String(pluginManifest && pluginManifest.id ? pluginManifest.id : "")
    var liveWidget = null
    try {
      if (shell && shell.bar && typeof shell.bar.moduleWidgets === "function") {
        var widgets = shell.bar.moduleWidgets(id)
        if (widgets.length > 0) liveWidget = widgets[0]
      }
    } catch (error) {}
    return PluginIconResolver.resolve(pluginManifest, scannedIcons[id], liveWidget)
  }

  function requestIconScan() {
    if (iconScanner.running) return
    iconScanner.command = [
      "/usr/bin/python3", "-I", pluginDirectory + "/lib/omarchy_dashboard_icons.py",
      "/usr/share/omarchy/shell/plugins",
      String(dashboardHost.home || "") + "/.config/omarchy/plugins"
    ]
    iconScanner.running = true
  }

  function pluginSettings(id) {
    try {
      var hosted = HostPlacements.settingsFor(
        shell ? shell.shellConfig : null, dashboardPluginId, id, "")
      if (Object.keys(hosted).length > 0) return hosted
      if (shell && shell.bar && typeof shell.bar.moduleWidgets === "function") {
        var widgets = shell.bar.moduleWidgets(id)
        if (widgets.length > 0 && widgets[0] && widgets[0].settings) return widgets[0].settings
      }
      var config = shell ? shell.shellConfig : null
      if (config && Array.isArray(config.plugins)) {
        for (var index = 0; index < config.plugins.length; index++)
          if (config.plugins[index] && String(config.plugins[index].id) === id) return config.plugins[index]
      }
    } catch (error) {
      console.warn("Dashboard: settings lookup failed for " + id + ":", error)
    }
    return ({})
  }

  function dashboardSetting(name, fallback) {
    var revision = registryRevision
    var settings = pluginSettings(dashboardPluginId)
    var value = settings[name]
    return value !== undefined && value !== null ? value : fallback
  }

  function setDashboardSetting(name, value) {
    if (!registry || typeof registry.setBarWidget !== "function") return false
    try {
      var error = registry.setBarWidget(dashboardPluginId, String(name), value, {})
      if (error) {
        console.warn("Dashboard: failed to save setting " + name + ": " + error)
        return false
      }
      return true
    } catch (exception) {
      console.warn("Dashboard: failed to save setting " + name + ":", exception)
      return false
    }
  }

  function inject(page, tile) {
    return injectInto(page, tile, dashboardHost)
  }

  function injectInto(page, tile, host) {
    if (!page || !tile) return false
    var targetHost = host || dashboardHost
    var service = pluginService(tile.pluginId)
    var context = {
      dashboard: targetHost,
      tile: tile,
      pluginId: tile.pluginId,
      settings: pluginSettings(tile.pluginId),
      service: service,
      shell: shell,
      bar: adaptations[tile.pluginId] ? dashboardBar : (shell ? shell.bar : null)
    }
    try {
      if (typeof page.initializeDashboard === "function") page.initializeDashboard(context)
      else if (typeof page.initializeSidePanel === "function") page.initializeSidePanel({
        sidePanel: targetHost, sidePanelItem: tile, pluginId: tile.pluginId,
        settings: context.settings, service: service, bar: context.bar
      })
      else {
        assignProperty(page, "dashboard", targetHost)
        assignProperty(page, "dashboardHost", targetHost)
        assignProperty(page, "dashboardTile", tile)
        assignProperty(page, "sidePanel", targetHost)
        assignProperty(page, "sidePanelHost", targetHost)
        assignProperty(page, "sidePanelItem", tile)
        assignProperty(page, "pluginId", tile.pluginId)
        assignProperty(page, "settings", context.settings)
        assignProperty(page, "service", service)
        assignProperty(page, "shell", shell)
        assignProperty(page, "bar", context.bar)
      }
      if (typeof page.dashboardActivate === "function") page.dashboardActivate(context)
      else if (typeof page.sidePanelActivate === "function") page.sidePanelActivate(context)
      else if (typeof page.open === "function") page.open()
      return true
    } catch (error) {
      console.warn("Dashboard: page initialization failed for " + tile.pluginId + ":", error)
      return false
    }
  }

  function deactivate(page, reason) {
    if (!page) return
    try {
      if (typeof page.dashboardDeactivate === "function") page.dashboardDeactivate(reason || "unload")
      else if (typeof page.sidePanelDeactivate === "function") page.sidePanelDeactivate(reason || "unload")
      else if (typeof page.close === "function") page.close()
    } catch (error) {
      console.warn("Dashboard: page deactivation failed:", error)
    }
  }

  function focusPage(page) {
    if (!page) return
    try {
      if (typeof page.dashboardFocus === "function") page.dashboardFocus()
      else if (typeof page.sidePanelFocus === "function") page.sidePanelFocus()
      else page.forceActiveFocus()
    } catch (error) {
      console.warn("Dashboard: page focus failed:", error)
    }
  }

  function assignProperty(page, name, value) {
    if (!(name in page)) return
    try {
      page[name] = value
    } catch (error) {
      // Standard panels often expose a readonly service binding of their own.
      // Preserve it silently; other assignment failures remain diagnostic.
      if (String(error).indexOf("read-only property") < 0)
        console.warn("Dashboard: cannot inject " + name + ":", error)
    }
  }

  function launchNative(pluginId) {
    if (!nativeAvailable(pluginId) || !shell || typeof shell.summon !== "function") return false
    var result = shell.summon(pluginId)
    if (result && dashboardHost && typeof dashboardHost.close === "function") dashboardHost.close()
    return result === true
  }

  function adaptationEntryPoint(pluginId) {
    var entry = descriptor(pluginId)
    if (!entry) return ""
    var capabilities = PluginPresentation.capabilities(entry.manifest, {
      hasControl: !!PluginControls.profile(pluginId)
    })
    return capabilities.adaptationEntryPoint
  }

  function requestAdaptation(pluginId) {
    if (!pluginId || explicitPageUrl(pluginId) || adaptations[pluginId]
        || adaptationErrors[pluginId] !== undefined || adaptingPluginId) return
    var entry = descriptor(pluginId)
    var entryPoint = adaptationEntryPoint(pluginId)
    if (!entry || !entryPoint) return
    adaptingPluginId = pluginId
    adapter.command = [
      "/usr/bin/python3", "-I", pluginDirectory + "/lib/omarchy_dashboard_adapter.py",
      "--json-output", "--",
      String(entry.manifest.__sourceDir || ""),
      String(entryPoint),
      cacheRoot,
      pluginId,
      pluginDirectory + "/qml/adapters"
    ]
    adapter.running = true
    adapterTimeout.restart()
  }

  function prepareVisiblePanels() {
    if (!active || adaptingPluginId || adapter.running) return
    var visibleTiles = Array.isArray(tiles) ? tiles : []
    for (var index = 0; index < visibleTiles.length; index++) {
      var id = String(visibleTiles[index].pluginId || "")
      var entry = descriptor(id)
      var preference = PluginPresentation.normalizePreference(visibleTiles[index].embedding)
      if (!id || preference === "widget" || preference === "control"
          || (preference === "launcher" && nativeAvailable(id))
          || (preference === "auto" && widgetPageUrl(id))
          || explicitPageUrl(id) || adaptations[id] || adaptationErrors[id] !== undefined
          || !entry || !adaptationEntryPoint(id)) continue
      requestAdaptation(id)
      return
    }
  }

  function setAdaptationError(id, message) {
    id = safePluginId(id)
    if (!id) return
    var next = ({})
    for (var key in adaptationErrors) next[key] = adaptationErrors[key]
    next[id] = boundedText(message || "Standard panel embedding is unavailable.", 1024)
    adaptationErrors = next
  }

  function resetRegistry() {
    pluginEpoch += 1
    adaptations = ({})
    adaptationErrors = ({})
    requestIconScan()
    Qt.callLater(prepareVisiblePanels)
  }

  onActiveChanged: if (active) Qt.callLater(prepareVisiblePanels)
  onTilesChanged: Qt.callLater(prepareVisiblePanels)
  onAdaptationsChanged: Qt.callLater(prepareVisiblePanels)
  onAdaptationErrorsChanged: Qt.callLater(prepareVisiblePanels)

  Connections {
    target: root.registry
    function onPluginsChanged() { root.resetRegistry() }
    function onLocalPluginChanged(pluginId) { root.resetRegistry() }
  }

  Process {
    id: adapter
    clearEnvironment: true
    stdout: StdioCollector { id: adapterOutput; waitForEnd: true }
    stderr: StdioCollector { id: adapterErrors; waitForEnd: true }
    onExited: function(exitCode) {
      adapterTimeout.stop()
      adapterKillTimer.stop()
      var id = root.adaptingPluginId
      root.adaptingPluginId = ""
      if (!id) return
      if (exitCode !== 0) {
        root.setAdaptationError(id, String(adapterErrors.text || "Standard panel embedding is unavailable.").trim())
        return
      }
      if (String(adapterOutput.text || "").length > root.maxHelperOutputLength) {
        root.setAdaptationError(id, "The adapter returned too much metadata.")
        return
      }
      var result
      try {
        result = JSON.parse(String(adapterOutput.text || ""))
      } catch (error) {
        root.setAdaptationError(id, "The adapter returned invalid metadata.")
        return
      }
      var url = String(result && result.url || "")
      var layout = String(result && result.layout || "")
      if (url.indexOf("file://" + root.cacheRoot + "/") !== 0 || url.indexOf("..") >= 0) {
        root.setAdaptationError(id, "The adapter returned an unsafe URL.")
        return
      }
      if (layout !== "padded" && layout !== "edge-to-edge") {
        root.setAdaptationError(id, "The adapter returned an unsupported layout.")
        return
      }
      var next = ({})
      for (var key in root.adaptations) next[key] = root.adaptations[key]
      next[id] = { url: url, layout: layout }
      root.adaptations = next
    }
  }

  Process {
    id: iconScanner
    clearEnvironment: true
    stdout: StdioCollector { id: iconOutput; waitForEnd: true }
    stderr: StdioCollector { waitForEnd: true }
    onExited: function(exitCode) {
      if (exitCode !== 0) return
      try {
        if (String(iconOutput.text || "").length > root.maxHelperOutputLength) {
          console.warn("Dashboard: icon discovery returned too much metadata")
          return
        }
        var parsed = JSON.parse(String(iconOutput.text || "{}"))
        if (!parsed || typeof parsed !== "object" || Array.isArray(parsed)) return
        root.scannedIcons = parsed
      } catch (error) {
        console.warn("Dashboard: icon discovery returned invalid JSON:", error)
      }
    }
  }

  Timer {
    id: adapterTimeout
    interval: 15000
    onTriggered: {
      if (!root.adaptingPluginId) return
      var id = root.adaptingPluginId
      root.adaptingPluginId = ""
      root.setAdaptationError(id, "Preparing this plugin timed out.")
      if (adapter.running) {
        adapter.running = false
        adapterKillTimer.restart()
      }
    }
  }

  Timer {
    id: adapterKillTimer
    interval: 1000
    onTriggered: if (adapter.running) adapter.signal(9)
  }

  Component.onCompleted: requestIconScan()
}
