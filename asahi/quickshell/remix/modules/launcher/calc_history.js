// Calculator: evaluation and input history (bash-style, newest first).
// QML: import "calc_history.js" as CalcHist
// Node: require("./calc_history.js")

var MAX = 20

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

// Scientific calculator: own tokenizer + recursive descent, no eval (a pasted expression must never
// reach code). Radians; `30°` is degrees. `,` separates arguments, `.` is the decimal point.
var PHI = (1 + Math.sqrt(5)) / 2
var CONSTS = { pi: Math.PI, e: Math.E, tau: 2 * Math.PI, phi: PHI }

function isInt(n) { return Number.isInteger(n) }
function fact(n) {
  if (!isInt(n) || n < 0) return NaN
  let r = 1
  for (let i = 2; i <= n && r < Infinity; i++) r *= i
  return r
}
function nCr(n, k) {
  if (!isInt(n) || !isInt(k) || n < 0 || k < 0) return NaN
  if (k > n) return 0
  k = Math.min(k, n - k)
  let r = 1
  for (let i = 1; i <= k; i++) r = r * (n - k + i) / i
  return Math.round(r)
}
function nPr(n, k) {
  if (!isInt(n) || !isInt(k) || n < 0 || k < 0) return NaN
  if (k > n) return 0
  let r = 1
  for (let i = n - k + 1; i <= n; i++) r *= i
  return r
}
function root(x, n) {
  if (n === undefined) n = 2
  return x < 0 && isInt(n) && n % 2 ? -Math.pow(-x, 1 / n) : Math.pow(x, 1 / n) }
function round(x, n) {
  const m = Math.pow(10, n || 0)
  return Math.sign(x) * Math.round(Math.abs(x) * m) / m
}

// name → [min args, max args, fn]
var FUNCS = {
  sin: [1, 1, Math.sin], cos: [1, 1, Math.cos], tan: [1, 1, Math.tan],
  asin: [1, 1, Math.asin], acos: [1, 1, Math.acos], atan: [1, 1, Math.atan], atan2: [2, 2, Math.atan2],
  sinh: [1, 1, Math.sinh], cosh: [1, 1, Math.cosh], tanh: [1, 1, Math.tanh],
  asinh: [1, 1, Math.asinh], acosh: [1, 1, Math.acosh], atanh: [1, 1, Math.atanh],
  ln: [1, 1, Math.log], log2: [1, 1, Math.log2],
  log: [1, 2, function (x, b) { return b === undefined ? Math.log10(x) : Math.log(x) / Math.log(b) }],
  exp: [1, 1, Math.exp], sqrt: [1, 1, Math.sqrt], cbrt: [1, 1, Math.cbrt], root: [1, 2, root],
  abs: [1, 1, Math.abs], sign: [1, 1, Math.sign], floor: [1, 1, Math.floor], ceil: [1, 1, Math.ceil],
  trunc: [1, 1, Math.trunc], round: [1, 2, round],
  ncr: [2, 2, nCr], binom: [2, 2, nCr], choose: [2, 2, nCr], npr: [2, 2, nPr], fact: [1, 1, fact],
  deg: [1, 1, function (x) { return x * 180 / Math.PI }], rad: [1, 1, function (x) { return x * Math.PI / 180 }]
}

function tokenize(s) {
  const toks = []
  let i = 0
  while (i < s.length) {
    const rest = s.substring(i)
    let m
    if ((m = /^\s+/.exec(rest))) {
      // skip
    } else if ((m = /^0x[0-9a-f]+|^0b[01]+|^0o[0-7]+/i.exec(rest))) {
      const base = { x: 16, b: 2, o: 8 }[m[0].charAt(1).toLowerCase()]
      toks.push({ t: "num", v: parseInt(m[0].substring(2), base) })
    } else if ((m = /^(?:\d+\.?\d*|\.\d+)(?:e[+-]?\d+)?/i.exec(rest))) {
      toks.push({ t: "num", v: parseFloat(m[0]) })
    } else if ((m = /^[a-z_][a-z0-9_]*/i.exec(rest))) {
      toks.push({ t: "id", v: m[0].toLowerCase() })
    } else if ((m = /^\*\*|^[-+*\/^()!%,°×÷·−]/.exec(rest))) {
      toks.push({ t: "op", v: { "**": "^", "×": "*", "·": "*", "÷": "/", "−": "-" }[m[0]] || m[0] })
    } else {
      throw new Error("bad char")
    }
    i += m[0].length
  }
  return toks
}

function parse(toks, ans) {
  let p = 0
  const peek = function () { return toks[p] }
  const isOp = function (v) { return toks[p] && toks[p].t === "op" && toks[p].v === v }
  const eat = function (v) { if (!isOp(v)) throw new Error("expected " + v); p++ }

  function expr() {
    let v = term()
    while (isOp("+") || isOp("-")) v = toks[p++].v === "+" ? v + term() : v - term()
    return v
  }
  // implicit multiplication (2pi, 3(4+1), 2sin(x)) binds like *
  function term() {
    let v = unary()
    for (;;) {
      const t = peek()
      if (isOp("*")) { p++; v *= unary() }
      else if (isOp("/")) { p++; v /= unary() }
      else if (isOp("%") || (t && t.t === "id" && t.v === "mod")) { p++; v %= unary() }
      else if (t && (t.t === "id" || isOp("("))) v *= power()
      else return v
    }
  }
  function unary() {
    if (isOp("-")) { p++; return -unary() }
    if (isOp("+")) { p++; return unary() }
    return power()
  }
  // right-associative, below unary: -2^2 = -4, 2^3^2 = 512, 2^-1 = 0.5
  function power() {
    const v = postfix()
    if (isOp("^")) { p++; return Math.pow(v, unary()) }
    return v
  }
  function postfix() {
    let v = primary()
    while (isOp("!") || isOp("°")) v = toks[p++].v === "!" ? fact(v) : v * Math.PI / 180
    return v
  }
  function primary() {
    const t = toks[p++]
    if (!t) throw new Error("unexpected end")
    if (t.t === "num") return t.v
    if (isOpTok(t, "(")) { const v = expr(); eat(")"); return v }
    if (t.t === "id") {
      if (t.v === "ans") { if (typeof ans !== "number" || !isFinite(ans)) throw new Error("no ans"); return ans }
      if (CONSTS.hasOwnProperty(t.v)) return CONSTS[t.v]
      if (FUNCS.hasOwnProperty(t.v)) {
        const f = FUNCS[t.v]
        eat("(")
        const args = [expr()]
        while (isOp(",")) { p++; args.push(expr()) }
        eat(")")
        if (args.length < f[0] || args.length > f[1]) throw new Error("arity")
        return f[2].apply(null, args)
      }
    }
    throw new Error("unexpected " + t.v)
  }
  function isOpTok(t, v) { return t.t === "op" && t.v === v }

  const v = expr()
  if (p < toks.length) throw new Error("trailing")
  return v
}

// 12 significant digits (0.1+0.2 = 0.3); exact integers up to 2^53, past that exponent form (no fake digits).
function format(v) {
  if (v === 0) return "0"
  if (isInt(v) && Math.abs(v) > 9007199254740992) return v.toExponential(11).replace(/\.?0+e/, "e")
  if (isInt(v)) return v.toString()
  return parseFloat(v.toPrecision(12)).toString()
}

// "=" query → result string, or null. `ans` = last copied result; a leading * / ^ continues from it.
function calculate(expr, ans) {
  expr = String(expr || "").trim()
  if (!expr) return null
  if (/^[*\/^×÷]/.test(expr)) expr = "ans" + expr
  try {
    const v = parse(tokenize(expr), typeof ans === "string" ? parseFloat(ans) : ans)
    return typeof v === "number" && isFinite(v) ? format(v) : null
  } catch (_) { return null }
}

// Units ("=10 km to mi", "=5 GiB in MB", "=72 f to c"; to / in / ->): factor to the dimension's base unit, exact
// spelling first, then case-insensitive ("gb"). Temperature is affine (via °C). The value part is any expression.
var UNITS = {
  length: { mm: 1e-3, cm: 1e-2, m: 1, km: 1e3, in: 0.0254, ft: 0.3048, yd: 0.9144, mi: 1609.344, nmi: 1852 },
  mass: { mg: 1e-6, g: 1e-3, kg: 1, t: 1e3, oz: 0.028349523125, lb: 0.45359237 },
  time: { ms: 1e-3, s: 1, min: 60, h: 3600, d: 86400, wk: 604800 },
  data: { bit: 0.125, B: 1, kB: 1e3, MB: 1e6, GB: 1e9, TB: 1e12, KiB: 1024, MiB: 1048576, GiB: 1073741824, TiB: 1099511627776 },
  speed: { "m/s": 1, "km/h": 1 / 3.6, mph: 0.44704, kn: 1852 / 3600 },
  volume: { ml: 1e-3, l: 1, gal: 3.785411784, floz: 0.0295735295625 },
  energy: { J: 1, kJ: 1e3, cal: 4.184, kcal: 4184, Wh: 3600, kWh: 3.6e6 }
}
var TEMPS = {
  c: { to: function (x) { return x }, from: function (x) { return x } },
  f: { to: function (x) { return (x - 32) * 5 / 9 }, from: function (x) { return x * 9 / 5 + 32 } },
  k: { to: function (x) { return x - 273.15 }, from: function (x) { return x + 273.15 } }
}
function unit(name) {
  for (const dim in UNITS) if (Object.prototype.hasOwnProperty.call(UNITS[dim], name)) return { dim: dim, name: name, f: UNITS[dim][name] }
  const low = name.toLowerCase()
  for (const dim in UNITS) for (const u in UNITS[dim]) if (u.toLowerCase() === low) return { dim: dim, name: u, f: UNITS[dim][u] }
  return null
}
// → { value, unit, per } or null; 6 significant digits (a conversion, not a computation).
function fmt6(v) { return parseFloat(v.toPrecision(6)).toString() }
function convert(expr, ans) {
  const m = String(expr || "").trim().match(/^(.*?)\s*(°?[a-zA-Z][a-zA-Z\/]*)\s+(?:to|in|->|→)\s+(°?[a-zA-Z][a-zA-Z\/]*)$/)
  if (!m || m[1] === "") return null
  const num = calculate(m[1], ans)
  if (num === null) return null
  const x = parseFloat(num)
  const a = m[2].replace("°", ""), b = m[3].replace("°", "")
  const own = k => Object.prototype.hasOwnProperty.call(TEMPS, k) ? TEMPS[k] : null   // "constructor" is no unit
  const ta = own(a.toLowerCase()), tb = own(b.toLowerCase())
  if (ta && tb) return { value: fmt6(tb.from(ta.to(x))), unit: b.toLowerCase() === "k" ? "K" : "°" + b.toUpperCase(), per: "" }
  const ua = unit(a), ub = unit(b)
  if (!ua || !ub || ua.dim !== ub.dim) return null
  return { value: fmt6(x * ua.f / ub.f), unit: ub.name, per: "1 " + ua.name + " = " + fmt6(ua.f / ub.f) + " " + ub.name }
}

// Integer result in the bases the expression itself uses (0x / 0b / 0o), e.g. "0xff · 0b11111111", else "".
function altFormats(expr, res) {
  const n = Number(res)
  if (!isInt(n) || Math.abs(n) > 9007199254740992) return ""
  const sg = n < 0 ? "-" : ""
  const a = Math.abs(n)
  const out = []
  if (/0x[0-9a-f]/i.test(expr)) out.push(sg + "0x" + a.toString(16))
  if (/0b[01]/i.test(expr)) out.push(sg + "0b" + a.toString(2))
  if (/0o[0-7]/i.test(expr)) out.push(sg + "0o" + a.toString(8))
  return out.join(" · ")
}

// Footer legend in "=" mode: [label, lines] per column. Optional arguments show their default.
var LEGEND = [
  ["trig", ["sin cos tan", "asin acos atan", "sinh cosh tanh", "asinh acosh atanh"]],
  ["angle", ["30° degrees", "deg(x) rad(x)", "atan2(y, x)"]],
  ["log · root", ["exp ln log2", "log(x, b=10)", "sqrt cbrt", "root(x, n=2)"]],
  ["round", ["round(x, n=0)", "floor ceil", "trunc", "abs sign"]],
  ["comb · units", ["n!", "nCr(n, k)", "nPr(n, k)", "10 km to mi"]],
  ["more", ["pi e tau phi", "ans", "^ mod", "0x 0b 0o"]]
]

// Launcher rows for "=" mode: result (if any), then the whole history (expr = result; the one ↑↓ loaded is tinted).
function rows(expr, ans, history, results, histIndex) {
  const out = []
  const res = calculate(expr, ans)
  if (res !== null) {
    const alt = altFormats(expr, res)
    out.push({ id: "calc-" + res, name: "= " + res, comment: (alt ? alt + " · " : "") + "Enter to copy", icon: "󰃬", special: "calc", result: res })
  } else {
    const cv = convert(expr, ans)   // copies the number alone (it becomes `ans`)
    if (cv) out.push({ id: "calc-" + cv.value, name: "= " + cv.value + " " + cv.unit, comment: (cv.per ? cv.per + " · " : "") + "Enter to copy",
      icon: "󰃬", special: "calc", result: cv.value })
  }
  ;(history || []).forEach(function (h, i) {
    const r = results && results[h]
    out.push({ id: "calc-hist-" + i, name: h, accessory: r ? "= " + r : "", glyph: "󰋚", special: "calc-hist", expr: h, result: r || "",
      tint: i === histIndex ? "mauve" : "" })
  })
  return out
}

// Saved state (~/.local/state/asahi/calc-history.json): history, a result per entry, ans.
function prune(history, results) {
  const r = {}
  ;(history || []).forEach(function (h) { if (results && typeof results[h] === "string") r[h] = results[h] })
  return r
}
function saveState(history, results, ans) {
  return JSON.stringify({ history: history || [], results: prune(history, results), ans: String(ans || "") })
}
function loadState(text) {
  let d = {}
  try { d = JSON.parse(text) || {} } catch (_) {}
  const history = (Array.isArray(d.history) ? d.history : []).filter(function (h) { return typeof h === "string" && h.trim() }).slice(0, MAX)
  return { history: history, results: prune(history, d.results), ans: typeof d.ans === "string" ? d.ans : "" }
}

if (typeof module !== "undefined" && module.exports) {
  module.exports = { MAX: MAX, push: push, step: step, calculate: calculate, convert: convert, altFormats: altFormats, rows: rows, LEGEND: LEGEND,
    saveState: saveState, loadState: loadState }
}
