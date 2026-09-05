import QtQuick

Item {
  id: root

  property var tiles: []
  property alias model: records

  function roles(tile) {
    var source = tile || ({})
    return {
      tileId: String(source.id || ""), tilePluginId: String(source.pluginId || ""),
      tileLabel: String(source.label || ""), tileEmbedding: String(source.embedding || "auto"),
      tileSpaceId: String(source.spaceId || ""), tileBackground: source.background !== false,
      tileX: Number(source.x) || 0, tileY: Number(source.y) || 0,
      tileW: Number(source.w) || 0, tileH: Number(source.h) || 0
    }
  }

  function synchronize(nextTiles) {
    var next = Array.isArray(nextTiles) ? nextTiles : []
    var wanted = ({})
    for (var index = 0; index < next.length; index++) wanted[String(next[index].id)] = true
    for (var removeIndex = records.count - 1; removeIndex >= 0; removeIndex--)
      if (!wanted[records.get(removeIndex).tileId]) records.remove(removeIndex)

    // Reconcile by tile identity: adding, removing or reordering a different
    // tile must not destroy a retained plugin's Loader and local state.
    for (var target = 0; target < next.length; target++) {
      var changed = roles(next[target])
      var existing = target
      while (existing < records.count && records.get(existing).tileId !== changed.tileId) existing++
      if (existing === records.count) records.insert(target, changed)
      else {
        if (existing !== target) records.move(existing, target, 1)
        for (var name in changed)
          if (records.get(target)[name] !== changed[name]) records.setProperty(target, name, changed[name])
      }
    }
  }

  onTilesChanged: synchronize(tiles)
  Component.onCompleted: synchronize(tiles)

  ListModel { id: records }
}
