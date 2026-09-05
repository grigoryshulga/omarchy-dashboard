.pragma library

// Rebuild priority from the current Space rather than keeping stale FIFO
// requests from pages the user has already left.
function prioritize(spaces, activeSpaceId) {
  var foreground = []
  var background = []
  var pages = Array.isArray(spaces) ? spaces : []
  pages.forEach(function(page) {
    var target = page.id === activeSpaceId ? foreground : background
    var tiles = Array.isArray(page.tiles) ? page.tiles : []
    tiles.forEach(function(tile) {
      target.push(Object.assign({}, tile, { spaceId: page.id }))
    })
  })
  return foreground.concat(background)
}
