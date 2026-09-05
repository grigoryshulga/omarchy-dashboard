import QtQuick

QtObject {
  id: root

  property bool opened: false
  property var spaces: []
  property string activeSpaceId: ""
  readonly property var tiles: retainedTiles
  property var retainedTiles: []
  property var retainedIds: ({})

  function synchronize() {
    if (!opened) {
      retainedIds = ({})
      retainedTiles = []
      return
    }
    var next = []
    var ids = ({})
    var pages = Array.isArray(spaces) ? spaces : []
    for (var pageIndex = 0; pageIndex < pages.length; pageIndex++) {
      var page = pages[pageIndex]
      var entries = Array.isArray(page.tiles) ? page.tiles : []
      for (var index = 0; index < entries.length; index++) {
        var tile = entries[index]
        if (page.id !== activeSpaceId && !retainedIds[tile.id]) continue
        var retained = ({})
        for (var key in tile) retained[key] = tile[key]
        retained.spaceId = page.id
        next.push(retained)
        ids[tile.id] = true
      }
    }
    retainedIds = ids
    retainedTiles = next
  }

  onOpenedChanged: synchronize()
  onSpacesChanged: synchronize()
  onActiveSpaceIdChanged: synchronize()
  Component.onCompleted: synchronize()
}
