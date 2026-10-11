.pragma library
// Word diff for the Writing Tools card: original (top, deletions struck) vs
// suggestion (bottom, insertions marked). Pure: no Qt, tested by writing_diff_test.js.

// Whitespace runs, words (apostrophes / hyphens stay inside), single punctuation marks.
function tokenize(s) {
  return String(s).match(/\s+|[^\s.,;:!?()\[\]{}"“”„«»…]+|\S/g) || []
}

// Model output → replacement text: drop stray fences / <text> tags, keep the
// selection's own leading and trailing whitespace (a selected trailing newline stays).
function fitOutput(original, output) {
  var s = String(output).replace(/^\s*```[a-z]*\n/, "").replace(/\n```\s*$/, "")
  s = s.replace(/^\s*<text>\s*/, "").replace(/\s*<\/text>\s*$/, "").trim()
  var o = String(original)
  return o.match(/^\s*/)[0] + s + o.match(/\s*$/)[0]
}

// LCS edit script over two token arrays: [[op, token], ...].
function lcs(a2, b2) {
  var n = a2.length, m = b2.length, raw = []
  if (n * m > 1500000) {
    // Too big for the LCS table: one change block.
    a2.forEach(function (t) { raw.push(["del", t]) })
    b2.forEach(function (t) { raw.push(["ins", t]) })
    return raw
  }
  // L[i][j] = LCS length of a2[i:] and b2[j:].
  var w = m + 1, L = new Int32Array((n + 1) * w)
  for (var i = n - 1; i >= 0; i--)
    for (var j = m - 1; j >= 0; j--)
      L[i * w + j] = a2[i] === b2[j] ? L[(i + 1) * w + j + 1] + 1 : Math.max(L[(i + 1) * w + j], L[i * w + j + 1])
  var x = 0, y = 0
  while (x < n && y < m) {
    if (a2[x] === b2[y]) { raw.push(["eq", a2[x]]); x++; y++ }
    else if (L[(x + 1) * w + y] >= L[x * w + y + 1]) raw.push(["del", a2[x++]])
    else raw.push(["ins", b2[y++]])
  }
  while (x < n) raw.push(["del", a2[x++]])
  while (y < m) raw.push(["ins", b2[y++]])
  return raw
}

// Character marks inside one replaced block ("tomorow" → "tomorrow": only the "r").
// null when the two sides share too little: then the whole block is the change.
function charDiff(a, b) {
  var raw = lcs(a.split(""), b.split("")), out = [], same = 0
  raw.forEach(function (t) {
    if (t[0] === "eq") same++
    if (out.length && out[out.length - 1].op === t[0]) out[out.length - 1].text += t[1]
    else out.push({ op: t[0], text: t[1] })
  })
  return 2 * same / (a.length + b.length) >= 0.5 ? out : null
}

// [{op: "eq"|"del"|"ins", text, chars?}], dels before inss inside a change block.
// A del followed by its ins carries `chars` (charDiff) on both.
function diff(a, b) {
  var A = tokenize(a), B = tokenize(b)
  var pre = 0
  while (pre < A.length && pre < B.length && A[pre] === B[pre]) pre++
  var suf = 0
  while (suf < A.length - pre && suf < B.length - pre && A[A.length - 1 - suf] === B[B.length - 1 - suf]) suf++
  var raw = lcs(A.slice(pre, A.length - suf), B.slice(pre, B.length - suf))
  var toks = A.slice(0, pre).map(function (t) { return ["eq", t] }).concat(raw)
    .concat(A.slice(A.length - suf).map(function (t) { return ["eq", t] }))
  // A lone space between two changes belongs to the change: "a b" → "c d" is one block, not two.
  for (var k = 1; k < toks.length - 1; k++)
    if (toks[k][0] === "eq" && /^[ \t]+$/.test(toks[k][1]) && toks[k - 1][0] !== "eq" && toks[k + 1][0] !== "eq")
      toks.splice(k, 1, ["del", toks[k][1]], ["ins", toks[k][1]])
  var out = [], del = "", ins = ""
  function flush() {
    // Char marks only for one word → one word; across words they read as noise.
    var chars = del && ins && !/\s/.test(del + ins) ? charDiff(del, ins) : null
    if (del) out.push(chars ? { op: "del", text: del, chars: chars } : { op: "del", text: del })
    if (ins) out.push(chars ? { op: "ins", text: ins, chars: chars } : { op: "ins", text: ins })
    del = ins = ""
  }
  toks.forEach(function (t) {
    if (t[0] === "del") del += t[1]
    else if (t[0] === "ins") ins += t[1]
    else {
      flush()
      if (out.length && out[out.length - 1].op === "eq") out[out.length - 1].text += t[1]
      else out.push({ op: "eq", text: t[1] })
    }
  })
  flush()
  return out
}

// Change blocks (a del/ins run between two equal runs).
function changes(ops) {
  var n = 0
  for (var i = 0; i < ops.length; i++)
    if (ops[i].op !== "eq" && (i === 0 || ops[i - 1].op === "eq")) n++
  return n
}

function esc(s) {
  return s.replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;")
}

// Rich text for one side; colors: { del, delBg, delMark, ins, insBg, insMark } as #rrggbb.
// A changed block is tinted (…Bg); with `chars`, its changed characters get the strong …Mark.
function html(ops, side, colors) {
  var mine = side === "old" ? "del" : "ins"
  function span(text, bg) {
    return '<span style="color:' + colors[mine] + ";background-color:" + bg
      + (mine === "del" ? ";text-decoration:line-through" : "") + '">' + esc(text) + "</span>"
  }
  var body = ops.map(function (o) {
    if (o.op === "eq") return esc(o.text)
    if (o.op !== mine) return ""
    if (!o.chars) return span(o.text, colors[mine + "Mark"])
    return o.chars.map(function (c) {
      if (c.op === "eq") return span(c.text, colors[mine + "Bg"])
      return c.op === mine ? span(c.text, colors[mine + "Mark"]) : ""
    }).join("")
  }).join("")
  return '<div style="white-space:pre-wrap">' + body + "</div>"
}
