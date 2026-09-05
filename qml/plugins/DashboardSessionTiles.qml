import QtQuick
import "PluginLoadOrder.js" as PluginLoadOrder

Item {
  id: root

  property bool opened: false
  property var spaces: []
  property string activeSpaceId: ""
  property int preloadInterval: 32
  readonly property var tiles: retainedTiles
  readonly property var orderedTiles: opened ? PluginLoadOrder.prioritize(spaces, activeSpaceId) : []
  property var retainedTiles: []
  property var retainedIds: ({})
  property var settledIds: ({})
  readonly property int queuedCount: Math.max(0, orderedTiles.length - retainedTiles.length)
  readonly property int loadingCount: {
    var settled = settledIds
    return retainedTiles.filter(function(tile) { return !settled[tile.id] }).length
  }

  function reportSettled(tileId, settled) {
    if (!opened || !retainedIds[tileId] || settledIds[tileId] === settled) return
    var next = Object.assign({}, settledIds)
    next[tileId] = settled
    settledIds = next
  }

  function schedulePreload() {
    if (opened && queuedCount > 0 && loadingCount === 0) preloadTimer.restart()
    else preloadTimer.stop()
  }

  function preloadNext() {
    if (!opened || loadingCount > 0) return
    for (var index = 0; index < orderedTiles.length; index++) {
      var tile = orderedTiles[index]
      if (retainedIds[tile.id]) continue
      var next = Object.assign({}, retainedIds)
      next[tile.id] = true
      retainedIds = next
      synchronize()
      return
    }
  }

  function synchronize() {
    if (!opened) {
      preloadTimer.stop()
      retainedIds = ({})
      settledIds = ({})
      retainedTiles = []
      return
    }
    var next = []
    var ids = ({})
    var settled = ({})
    for (var index = 0; index < orderedTiles.length; index++) {
      var tile = orderedTiles[index]
      // Foreground admission bypasses the background worker even when it is
      // busy. Existing instances stay resident as their priority changes.
      if (tile.spaceId !== activeSpaceId && !retainedIds[tile.id]) continue
      next.push(tile)
      ids[tile.id] = true
      if (settledIds[tile.id] !== undefined) settled[tile.id] = settledIds[tile.id]
    }
    retainedIds = ids
    settledIds = settled
    retainedTiles = next
    schedulePreload()
  }

  onOpenedChanged: if (!opened) synchronize()
  onOrderedTilesChanged: synchronize()
  onLoadingCountChanged: schedulePreload()
  onQueuedCountChanged: schedulePreload()
  Component.onCompleted: synchronize()

  Timer {
    id: preloadTimer
    interval: root.preloadInterval
    onTriggered: root.preloadNext()
  }
}
