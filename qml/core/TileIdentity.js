.pragma library

function sameTile(left, right) {
  return !!left && !!right
    && String(left.id || "") === String(right.id || "")
    && String(left.pluginId || "") === String(right.pluginId || "")
    && String(left.label || "") === String(right.label || "")
    && String(left.embedding || "") === String(right.embedding || "")
    && Number(left.x) === Number(right.x) && Number(left.y) === Number(right.y)
    && Number(left.w) === Number(right.w) && Number(left.h) === Number(right.h)
}
