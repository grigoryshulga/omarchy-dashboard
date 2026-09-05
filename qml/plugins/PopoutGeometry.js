.pragma library

function positive(value) {
  var number = Number(value)
  return isFinite(number) && number > 0 ? Math.min(8192, number) : 0
}

// Plugin hints describe content; saved user dimensions describe the whole card.
// The visible surround always wins over a plugin's minimum on small screens.
function resolve(metadata, natural, saved, bounds, chrome) {
  var hints = metadata || {}
  var popout = hints.popout || {}
  var intrinsic = natural || {}
  var manual = saved || {}
  var inset = chrome || {}
  var extraW = positive(inset.width)
  var extraH = positive(inset.height)
  var maxW = Math.floor(positive(bounds.width))
  var maxH = Math.floor(positive(bounds.height))
  var minW = Math.min(maxW, (positive(popout.minWidth) || positive(hints.minWidth)
    || positive(intrinsic.minWidth) || 240) + extraW)
  var minH = Math.min(maxH, (positive(popout.minHeight) || positive(hints.minHeight)
    || positive(intrinsic.minHeight) || 160) + extraH)
  var preferredW = positive(popout.preferredWidth) || positive(hints.preferredWidth)
    || positive(intrinsic.width) || 860
  var preferredH = positive(popout.preferredHeight) || positive(hints.preferredHeight)
    || positive(intrinsic.height) || 680
  return {
    width: Math.round(Math.max(minW, Math.min(maxW, positive(manual.width) || preferredW + extraW))),
    height: Math.round(Math.max(minH, Math.min(maxH, positive(manual.height) || preferredH + extraH))),
    minWidth: minW, minHeight: minH, maxWidth: maxW, maxHeight: maxH
  }
}
