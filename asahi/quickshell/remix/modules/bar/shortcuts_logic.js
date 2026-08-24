// Hyprland bindings.lua → shortcut-list parser (no QML). Turns hl.bind /
// media_bind calls + their -- section comments into { title, rows } for the
// bar popup. Mirrors sketchybar/top/shortcuts_logic.lua.
// QML: import "shortcuts_logic.js" as ShortcutsLogic
// Node: require("./shortcuts_logic.js")

var MOD_ORDER = ["super", "ctrl", "alt", "shift"]
var MOD_GLYPH = { super: "⌘", ctrl: "⌃", alt: "⌥", shift: "⇧" }
var MOD_ALIASES = {
  super: "super",
  mainmod: "super",
  mod: "super",
  control: "ctrl",
  ctrl: "ctrl",
  alt: "alt",
  shift: "shift"
}

var KEY_GLYPH = {
  space: "Space",
  left: "←",
  right: "→",
  up: "↑",
  down: "↓",
  return: "↩",
  tab: "⇥",
  escape: "⎋",
  delete: "⌫",
  page_up: "⇞",
  page_down: "⇟",
  caps_lock: "Caps",
  mouse_down: "Scroll↓",
  mouse_up: "Scroll↑",
  "mouse:272": "LMB",
  "mouse:273": "RMB",
  xf86audioraisevolume: "Vol+",
  xf86audiolowervolume: "Vol-",
  xf86audiomute: "Mute",
  xf86audiomicmute: "Mic",
  xf86audioplay: "Play",
  xf86audiopause: "Pause",
  xf86audionext: "Next",
  xf86audioprev: "Prev",
  xf86monbrightnessup: "Bright+",
  xf86monbrightnessdown: "Bright-",
  xf86search: "Kbd+",
  xf86launcha: "Kbd-"
}

function trim(s) {
  return String(s || "").replace(/^\s+|\s+$/g, "")
}

function capitalize(s) {
  s = String(s || "")
  return s.replace(/^\s*\S/, function (ch) { return ch.toUpperCase() })
}

function prettyDesc(s) {
  s = trim(s)
  s = s.replace(/\(([A-Za-z])\)/g, "$1")
  var dash = s.indexOf("—")
  if (dash !== -1) s = s.slice(0, dash)
  var paren = s.indexOf(" (")
  if (paren !== -1) s = s.slice(0, paren)
  var colon = s.indexOf(": ")
  if (colon !== -1) s = s.slice(0, colon)
  s = trim(s).replace(/[.;,]+$/, "")
  return capitalize(s)
}

function deriveDesc(action) {
  var a = String(action || "")
  if (/workspace\s*=\s*"e\+1"/.test(a)) return "Next workspace"
  if (/workspace\s*=\s*"e-1"/.test(a)) return "Previous workspace"
  if (/window\.close/.test(a)) return "Close window"
  if (/window\.float/.test(a)) return "Toggle floating"
  if (/window\.center/.test(a)) return "Center floating window"
  if (/window\.pin/.test(a)) return "Toggle pin window"
  if (/window\.fullscreen/.test(a)) return "Toggle fullscreen"
  if (/window\.pseudo/.test(a)) return "Toggle pseudo"
  if (/group\.toggle/.test(a)) return "Toggle group"
  if (/layout\s*"togglesplit"/.test(a)) return "Toggle split"
  var script = a.match(/asahi-([a-z0-9-]+)/)
  if (script) return capitalize(script[1].replace(/-/g, " "))
  var ident = a.match(/dsp\.([a-zA-Z_]+)/)
  if (ident) return capitalize(ident[1].replace(/_/g, " "))
  return "Shortcut"
}

function displayKey(key) {
  var raw = String(key || "")
  var lower = raw.toLowerCase()
  if (KEY_GLYPH[lower]) return KEY_GLYPH[lower]
  if (/^[a-z]$/.test(lower)) return lower.toUpperCase()
  if (/^\d$/.test(raw)) return raw
  return raw
}

function displayKeys(keys) {
  if (keys.length > 1) {
    var nums = []
    var allNum = true
    for (var i = 0; i < keys.length; i++) {
      if (!/^\d$/.test(keys[i])) {
        allNum = false
        break
      }
      nums.push(Number(keys[i]))
    }
    if (allNum) {
      var consecutive = true
      for (var n = 1; n < nums.length; n++) {
        if (nums[n] !== nums[n - 1] + 1) {
          consecutive = false
          break
        }
      }
      if (consecutive) return keys[0] + "–" + keys[keys.length - 1]
      // Workspace 1–10 on Hyprland uses key 0 for workspace 10.
      if (nums.length >= 2 && nums[nums.length - 1] === 0 && nums[0] === 1) {
        var wrap = true
        for (var w = 1; w < nums.length - 1; w++) {
          if (nums[w] !== w + 1) {
            wrap = false
            break
          }
        }
        if (wrap) return keys[0] + "–" + keys[keys.length - 1]
      }
    }
  }
  var out = []
  for (var k = 0; k < keys.length; k++) out.push(displayKey(keys[k]))
  return out.join("/")
}

function formatMods(present) {
  var out = []
  for (var i = 0; i < MOD_ORDER.length; i++) {
    if (present[MOD_ORDER[i]]) out.push(MOD_GLYPH[MOD_ORDER[i]])
  }
  return out.join("")
}

function chord(mods, keys) {
  var k = displayKeys(keys)
  if (!mods) return k
  return mods + " " + k
}

function parseChord(expr, loopKey) {
  expr = trim(expr)
  var present = {}
  var keys = []
  if (/\bmod\b/.test(expr) || /\bSUPER\b/.test(expr)) present.super = true

  var strings = []
  expr.replace(/"([^"]*)"/g, function (_, inner) {
    strings.push(inner)
    return ""
  })
  var glued = strings.join("")
  if (/\.\.\s*key\b/.test(expr) && loopKey != null) {
    glued += (glued ? " + " : "") + String(loopKey)
  }

  var tokens = glued.split("+")
  for (var i = 0; i < tokens.length; i++) {
    var tok = trim(tokens[i])
    if (!tok) continue
    var alias = MOD_ALIASES[tok.toLowerCase()]
    if (alias) {
      present[alias] = true
      continue
    }
    keys.push(tok)
  }
  if (keys.length === 0) keys.push("?")
  return { mods: formatMods(present), keys: keys }
}

function extractDesc(opts, loopI) {
  if (!opts) return null
  var m = opts.match(/desc\s*=\s*"([^"]*)"(\s*\.\.\s*(\w+))?/)
  if (!m) return null
  var text = m[1]
  if (m[3] === "i" && loopI != null) text += String(loopI)
  return text
}

function splitTopArgs(s) {
  var args = []
  var buf = ""
  var depth = 0
  var quote = null
  for (var i = 0; i < s.length; i++) {
    var c = s[i]
    if (quote) {
      buf += c
      if (c === quote && s[i - 1] !== "\\") quote = null
      continue
    }
    if (c === '"' || c === "'") {
      quote = c
      buf += c
      continue
    }
    if (c === "(" || c === "{") depth++
    else if (c === ")" || c === "}") depth--
    if (c === "," && depth === 0) {
      args.push(trim(buf))
      buf = ""
      continue
    }
    buf += c
  }
  if (trim(buf)) args.push(trim(buf))
  return args
}

function matchingParen(text, openIdx) {
  var depth = 0
  var quote = null
  for (var i = openIdx; i < text.length; i++) {
    var c = text[i]
    if (quote) {
      if (c === quote && text[i - 1] !== "\\") quote = null
      continue
    }
    if (c === '"' || c === "'") {
      quote = c
      continue
    }
    if (c === "(") depth++
    else if (c === ")") {
      depth--
      if (depth === 0) return i
    }
  }
  return -1
}

function isDecoration(content) {
  return /^[#=\-\s]*$/.test(content)
}

function isDisabledBind(content) {
  return /\b(hl\.bind|media_bind)\s*\(/.test(content)
}

function isSectionComment(content) {
  if (!content || isDecoration(content) || isDisabledBind(content)) return false
  if (/^local\s/.test(content) || /^function\b/.test(content)) return false
  return true
}

function parseForHeader(line) {
  var m = trim(line).match(/^for\s+\w+\s*=\s*(\d+)\s*,\s*(\d+)\s+do\b/)
  if (!m) return null
  return { start: Number(m[1]), end: Number(m[2]) }
}

function parseCall(stmt, loop) {
  var bind = stmt.match(/^\s*(hl\.bind|media_bind)\s*\(/)
  if (!bind) return null
  var open = stmt.indexOf("(")
  var close = matchingParen(stmt, open)
  if (close < 0) return null
  var inner = stmt.slice(open + 1, close)
  var args = splitTopArgs(inner)
  if (args.length < 1) return null
  var opts = args.length >= 3 ? args[2] : args[args.length - 1]
  if (opts && opts.charAt(0) !== "{") opts = ""
  var action = args.length >= 2 ? args[1] : ""

  var iterations = [null]
  if (loop && /\.\.\s*(key|i)\b/.test(args[0] + (opts || ""))) {
    iterations = []
    for (var n = loop.start; n <= loop.end; n++) iterations.push(n)
  }

  var out = []
  for (var i = 0; i < iterations.length; i++) {
    var iter = iterations[i]
    var loopKey = iter == null ? null : String(iter % 10)
    var chordInfo = parseChord(args[0], loopKey)
    var desc = extractDesc(opts || "", iter)
    out.push({
      mods: chordInfo.mods,
      keys: chordInfo.keys.slice(),
      desc: desc,
      action: action
    })
  }
  return out
}

function directionPrefix(desc) {
  var m = String(desc || "").match(/^(.*)\s+(left|right|up|down)$/i)
  return m ? { prefix: m[1], dir: m[2].toLowerCase() } : null
}

function stemDesc(text) {
  return String(text || "").replace(/\s+\d+$/, "")
}

function buildRows(entries) {
  var groups = []
  for (var i = 0; i < entries.length; i++) {
    var e = entries[i]
    var text = stemDesc(e.desc ? prettyDesc(e.desc) : deriveDesc(e.action))
    var prev = groups[groups.length - 1]
    var joins = prev && prev.mods === e.mods && prev.text === text
    if (joins) {
      for (var k = 0; k < e.keys.length; k++) prev.keys.push(e.keys[k])
    } else {
      groups.push({ mods: e.mods, keys: e.keys.slice(), text: text })
    }
  }

  var dirs = []
  for (var d = 0; d < groups.length; d++) {
    var g = groups[d]
    var info = directionPrefix(g.text)
    var last = dirs[dirs.length - 1]
    if (info && last && last.mods === g.mods && last.prefix === info.prefix) {
      for (var dk = 0; dk < g.keys.length; dk++) last.keys.push(g.keys[dk])
    } else if (info) {
      dirs.push({
        mods: g.mods,
        keys: g.keys.slice(),
        text: info.prefix,
        prefix: info.prefix,
        directional: true
      })
    } else {
      dirs.push({ mods: g.mods, keys: g.keys.slice(), text: g.text })
    }
  }

  var merged = []
  for (var m = 0; m < dirs.length; m++) {
    var cur = dirs[m]
    var found = null
    for (var p = 0; p < merged.length; p++) {
      if (merged[p].mods === cur.mods && merged[p].text === cur.text) {
        found = merged[p]
        break
      }
    }
    if (found) {
      for (var ck = 0; ck < cur.keys.length; ck++) found.keys.push(cur.keys[ck])
    } else {
      merged.push({ mods: cur.mods, keys: cur.keys.slice(), text: cur.text })
    }
  }

  var rows = []
  for (var r = 0; r < merged.length; r++) {
    var row = merged[r]
    var uniq = []
    var seen = {}
    for (var u = 0; u < row.keys.length; u++) {
      if (seen[row.keys[u]]) continue
      seen[row.keys[u]] = true
      uniq.push(row.keys[u])
    }
    rows.push({ desc: row.text, keys: chord(row.mods, uniq) })
  }
  return rows
}

function parse(text) {
  var raw = String(text || "").replace(/\r/g, "")
  var lines = raw.split("\n")
  var sections = []
  var current = { title: "General", entries: [] }
  var loop = null
  var loopDepth = 0
  var fnDepth = 0
  var pending = ""
  var i = 0

  function flush() {
    if (current.entries.length > 0) sections.push(current)
  }

  while (i < lines.length) {
    var line = lines[i]
    var trimmed = trim(line)

    if (trimmed === "") {
      i++
      continue
    }

    if (trimmed.indexOf("--") === 0) {
      var content = trim(trimmed.replace(/^--\s?/, ""))
      if (isSectionComment(content)) {
        flush()
        current = { title: capitalize(content), entries: [] }
      }
      i++
      continue
    }

    var forHead = parseForHeader(trimmed)
    if (forHead) {
      loop = forHead
      loopDepth = 1
      i++
      continue
    }

    if (/^\s*(local\s+)?function\b/.test(trimmed)) {
      fnDepth++
      i++
      continue
    }

    if (/^\s*end\b/.test(line)) {
      if (loop && loopDepth > 0) {
        loopDepth--
        if (loopDepth <= 0) loop = null
      } else if (fnDepth > 0) {
        fnDepth--
      }
      i++
      continue
    }

    if (fnDepth > 0) {
      i++
      continue
    }

    if (/^\s*(hl\.bind|media_bind)\s*\(/.test(line) || pending) {
      pending = pending ? pending + "\n" + line : line
      var open = pending.indexOf("(")
      var close = open >= 0 ? matchingParen(pending, open) : -1
      if (close < 0) {
        i++
        continue
      }
      var stmt = pending
      pending = ""
      var parsed = parseCall(stmt, loop)
      if (parsed) {
        for (var p = 0; p < parsed.length; p++) current.entries.push(parsed[p])
      }
      i++
      continue
    }

    i++
  }
  flush()

  var out = []
  for (var s = 0; s < sections.length; s++) {
    var rows = buildRows(sections[s].entries)
    if (rows.length > 0) out.push({ title: sections[s].title, rows: rows })
  }
  return out
}

function flatten(sections) {
  var elems = []
  for (var si = 0; si < sections.length; si++) {
    var sec = sections[si]
    elems.push({
      kind: "header",
      text: String(sec.title || "").toUpperCase(),
      h: 20,
      gap: si > 0 ? 10 : 0
    })
    var rows = sec.rows || []
    for (var r = 0; r < rows.length; r++) {
      elems.push({
        kind: "row",
        desc: rows[r].desc,
        keys: rows[r].keys,
        h: 19,
        gap: 0
      })
    }
  }
  return elems
}

function colHeight(elems, from, to) {
  var h = 0
  for (var i = from; i <= to; i++) {
    h += elems[i].h + (i > from ? elems[i].gap : 0)
  }
  return h
}

function layoutColumns(sections) {
  var elems = flatten(sections)
  var total = 0
  for (var i = 0; i < elems.length; i++) total += elems[i].gap + elems[i].h
  var split = elems.length
  var best = null
  var acc = 0
  for (var e = 0; e < elems.length; e++) {
    if (elems[e].kind === "header" && e > 0) {
      var d = Math.abs(acc - total / 2)
      if (best == null || d < best) {
        best = d
        split = e
      }
    }
    acc += elems[e].gap + elems[e].h
  }
  return {
    left: elems.slice(0, split),
    right: elems.slice(split),
    source: "hypr",
    height: Math.max(colHeight(elems, 0, split - 1), colHeight(elems, split, elems.length - 1))
  }
}

if (typeof module !== "undefined" && module.exports) {
  module.exports = {
    prettyDesc: prettyDesc,
    deriveDesc: deriveDesc,
    parseChord: parseChord,
    displayKeys: displayKeys,
    parse: parse,
    layoutColumns: layoutColumns
  }
}
