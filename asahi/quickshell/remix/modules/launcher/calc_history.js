// Calculator input history (bash-style). Newest first.
// QML: import "calc_history.js" as CalcHist
// Node: require("./calc_history.js")

var MAX = 50

function push(history, expr) {
  const text = String(expr || "").trim()
  const prev = history || []
  if (!text) return prev
  if (prev[0] === text) return prev
  const h = prev.slice()
  const i = h.indexOf(text)
  if (i > 0) h.splice(i, 1)
  h.unshift(text)
  if (h.length > MAX) h.length = MAX
  return h
}

// index -1 is the live draft. delta +1 is Up (older), -1 is Down (toward draft).
function step(history, draft, index, delta) {
  const h = history || []
  const n = h.length
  const d = String(draft || "")
  if (n < 1) return { index: -1, text: d }
  let i = Number(index)
  if (i !== i || i < -1) i = -1
  let next = i + (Number(delta) || 0)
  if (next < -1) next = -1
  if (next >= n) next = n - 1
  if (next === -1) return { index: -1, text: d }
  return { index: next, text: h[next] }
}

if (typeof module !== "undefined" && module.exports) {
  module.exports = { MAX: MAX, push: push, step: step }
}
