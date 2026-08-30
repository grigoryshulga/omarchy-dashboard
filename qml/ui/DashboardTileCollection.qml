import QtQuick

Item {
  id: root

  property var tiles: []
  property alias model: records

  function equal(left, right) {
    return JSON.stringify(left || ({})) === JSON.stringify(right || ({}))
  }

  function synchronize(nextTiles) {
    var next = Array.isArray(nextTiles) ? nextTiles : []
    var sameOrder = records.count === next.length
    for (var index = 0; index < next.length && sameOrder; index++)
      sameOrder = String(JSON.parse(records.get(index).tileRecordJson).id || "") === String(next[index].id || "")
    if (!sameOrder) {
      records.clear()
      for (var appendIndex = 0; appendIndex < next.length; appendIndex++)
        records.append({ tileRecordJson: JSON.stringify(next[appendIndex]) })
      return
    }
    for (var updateIndex = 0; updateIndex < next.length; updateIndex++)
      if (!equal(JSON.parse(records.get(updateIndex).tileRecordJson), next[updateIndex]))
        records.setProperty(updateIndex, "tileRecordJson", JSON.stringify(next[updateIndex]))
  }

  onTilesChanged: synchronize(tiles)
  Component.onCompleted: synchronize(tiles)

  ListModel { id: records }
}
