.pragma library

function editDirectionAction(alt, ctrl, shift) {
  if (shift && !alt && !ctrl) return "resize"
  if (alt && !ctrl && !shift) return "move"
  return ""
}
