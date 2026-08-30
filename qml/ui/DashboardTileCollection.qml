import QtQuick

Item {
  id: root

  property var tiles: []
  property alias model: records

  function equal(left, right) {
    return JSON.stringify(left || ({})) === JSON.stringify(right || ({}))
  }

  function roles(tile) {
    var source = tile || ({})
    return {
      tileId: String(source.id || ""), tilePluginId: String(source.pluginId || ""),
      tileLabel: String(source.label || ""), tileEmbedding: String(source.embedding || "auto"),
      tileX: Number(source.x) || 0, tileY: Number(source.y) || 0,
      tileW: Number(source.w) || 0, tileH: Number(source.h) || 0
    }
  }

  function synchronize(nextTiles) {
    var next = Array.isArray(nextTiles) ? nextTiles : []
    var sameOrder = records.count === next.length
    for (var index = 0; index < next.length && sameOrder; index++)
      sameOrder = String(records.get(index).tileId || "") === String(next[index].id || "")
    if (!sameOrder) {
      records.clear()
      for (var appendIndex = 0; appendIndex < next.length; appendIndex++)
        records.append(roles(next[appendIndex]))
      return
    }
    for (var updateIndex = 0; updateIndex < next.length; updateIndex++)
      if (!equal({ id: records.get(updateIndex).tileId, pluginId: records.get(updateIndex).tilePluginId,
                   label: records.get(updateIndex).tileLabel, embedding: records.get(updateIndex).tileEmbedding,
                   x: records.get(updateIndex).tileX, y: records.get(updateIndex).tileY,
                   w: records.get(updateIndex).tileW, h: records.get(updateIndex).tileH }, next[updateIndex])) {
        var changed = roles(next[updateIndex])
        for (var name in changed) records.setProperty(updateIndex, name, changed[name])
      }
  }

  onTilesChanged: synchronize(tiles)
  Component.onCompleted: synchronize(tiles)

  ListModel { id: records }
}
