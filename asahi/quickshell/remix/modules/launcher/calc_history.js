// Calculator: evaluation and input history (bash-style, newest first).
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

// "=" query → result string, or null. Arithmetic only: it runs eval() on every keystroke, so a pasted
// expression must never reach code (it used to see the launcher's ids).
function calculate(expr) {
  expr = String(expr || "").trim()
  if (!expr || !/^(?:[\d\s+\-*\/%^().]|pi|π|e|sqrt)*$/i.test(expr)) return null
  try {
    let e = expr.replace(/π/g, "Math.PI").replace(/pi/gi, "Math.PI")
    e = e.replace(/e\b/g, "Math.E")
    e = e.replace(/sqrt\(/gi, "Math.sqrt(")
    e = e.replace(/\^/g, "**")
    const val = eval(e)
    if (typeof val === "number" && isFinite(val)) {
      return Number.isInteger(val) ? val.toString() : parseFloat(val.toFixed(8)).toString()
    }
    return null
  } catch (_) { return null }
}

if (typeof module !== "undefined" && module.exports) {
  module.exports = { MAX: MAX, push: push, step: step, calculate: calculate }
}
