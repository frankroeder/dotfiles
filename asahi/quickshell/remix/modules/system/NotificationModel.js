// Notification logic for NotificationCenter.qml (also run by notification_model_test.js under node).
// Deck layout, code detection, the body sanitiser and the URL check are ports of omarchy v4.5.0-rc3
// shell/plugins/notifications (Layout.js, Detect.js, Markup.js, Security.js; MIT, ex-Omapager).

// --- Decks: one per sender, newest card in front ------------------------------------------------
// Collapsed: the front card plus up to two slivers behind it, each PEEK px lower, SHRINK smaller and
// fainter, all at the front card's height (tall back cards must not stick out). Open: spread out.
var VISIBLE = 3
var PEEK = 10
var SHRINK = 0.035
var CARD_GAP = 8
var DECK_GAP = 12
var FALLBACK_HEIGHT = 76
var DEPTH_OPACITY = [1, 0.85, 0.55]

// toasts newest first; decks keep the order of their newest card.
function decks(toasts) {
  var out = [], idx = Object.create(null)  // a sender may be named constructor
  for (var i = 0; i < toasts.length; i++) {
    var t = toasts[i], g = String(t.group || t.key)
    if (idx[g] === undefined) { idx[g] = out.length; out.push({ key: g, cards: [] }) }
    out[idx[g]].cards.push(t)
  }
  return out
}

function heightOf(heights, key) {
  var h = Number(heights && heights[key])
  return h > 0 ? h : FALLBACK_HEIGHT
}

// -> { places: {key: {y, height, scale, opacity, depth, front, open}}, decks: [{key, top, bottom}], height }
function layout(toasts, heights, openDeck) {
  var places = {}, spans = [], y = 0, list = decks(toasts)
  for (var d = 0; d < list.length; d++) {
    var deck = list[d], n = deck.cards.length, top = d > 0 ? y + DECK_GAP : y
    y = top
    if (deck.key === openDeck) {
      for (var r = 0; r < n; r++) {
        var h = heightOf(heights, deck.cards[r].key)
        places[deck.cards[r].key] = { y: y, height: h, scale: 1, opacity: 1, depth: r, front: r === 0, open: true }
        y += h + (r < n - 1 ? CARD_GAP : 0)
      }
    } else {
      var front = heightOf(heights, deck.cards[0].key)
      for (var b = 0; b < n; b++) {
        places[deck.cards[b].key] = {
          y: top + Math.min(b, VISIBLE - 1) * PEEK, height: front, scale: Math.max(0.7, 1 - b * SHRINK),
          opacity: b < VISIBLE ? DEPTH_OPACITY[b] : 0, depth: b, front: b === 0, open: false
        }
      }
      y = top + front + Math.min(n - 1, VISIBLE - 1) * PEEK
    }
    spans.push({ key: deck.key, top: top, bottom: y })
  }
  return { places: places, decks: spans, height: y }
}

// Deck under the pointer; half the deck gap counts to each side, so crossing it keeps one open.
function deckAt(lay, y) {
  for (var i = 0; i < lay.decks.length; i++) {
    var s = lay.decks[i]
    if (y >= s.top - DECK_GAP / 2 && y <= s.bottom + DECK_GAP / 2) return s.key
  }
  return ""
}

// Cards past maxDecks senders, or past perDeck in one deck (each is a tracked live object).
function overflowKeys(toasts, maxDecks, perDeck) {
  var out = [], list = decks(toasts)
  for (var d = 0; d < list.length; d++) {
    for (var r = 0; r < list[d].cards.length; r++) {
      if (d >= maxDecks || r >= perDeck) out.push(list[d].cards[r].key)
    }
  }
  return out
}

// An identical repeat (same sender and text) bumps the card's ×N instead of adding one.
function sameContent(a, b) {
  return !!a && !!b && a.group === b.group && a.appName === b.appName && a.summary === b.summary && a.body === b.body
}

// --- Markup --------------------------------------------------------------------------------------
var ENTITIES = { amp: "&", lt: "<", gt: ">", quot: "\"", apos: "'", nbsp: " " }

// Own keys only: "constructor" / "toString" must not find Object.prototype.
function own(map, key) {
  return Object.prototype.hasOwnProperty.call(map, key) ? map[key] : undefined
}

// Relays double-escape, so up to three passes.
function decodeEntities(s) {
  s = String(s || "")
  for (var pass = 0; pass < 3; pass++) {
    var next = s.replace(/&(#x[0-9a-f]{1,6}|#[0-9]{1,7}|[a-z]+);/gi, function(m, e) {
      if (e[0] === "#") {
        var code = e[1] === "x" || e[1] === "X" ? parseInt(e.slice(2), 16) : parseInt(e.slice(1), 10)
        return code > 0 && code <= 0x10ffff && !(code >= 0xd800 && code <= 0xdfff) ? String.fromCodePoint(code) : ""
      }
      var v = own(ENTITIES, e.toLowerCase())
      return v === undefined ? m : v
    })
    if (next === s) break
    s = next
  }
  return s
}

function escapeHtml(s) {
  return String(s).replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;").replace(/"/g, "&quot;")
}

var URL_RE = /https?:\/\/[^\s<>"']+/g
var SIMPLE_TAGS = { b: "b", strong: "b", i: "i", em: "i", u: "u", s: "s" }
var DROP_TAGS = { img: true, span: true, font: true }

// Plain text with bare http(s) URLs as links (escaped, `\n` as <br/>).
function linkify(text, links) {
  var out = "", last = 0, m
  URL_RE.lastIndex = 0
  while (links && (m = URL_RE.exec(text)) !== null) {
    // Trailing punctuation is no part of the URL. A loop: the regex for it was quadratic on long runs.
    var k = m[0].length
    while (k > 0 && ".,;:!?)]}".indexOf(m[0].charAt(k - 1)) >= 0) k--
    var raw = m[0].slice(0, k), url = safeHttpUrl(raw)
    out += escapeHtml(text.slice(last, m.index))
    out += url ? "<a href=\"" + url + "\">" + escapeHtml(raw) + "</a>" : escapeHtml(raw)
    last = m.index + raw.length
    URL_RE.lastIndex = last
  }
  return (out + escapeHtml(text.slice(last))).replace(/\r?\n/g, "<br/>")
}

// Body markup -> StyledText: everything escaped except b/i/u/s, <br> and <a href> with a safe http(s)
// URL; bare URLs become links when the sender sent no anchor. Unknown tags stay text ("Jane <jane@…>",
// Vec<String>); img / span / font are dropped. A tag name ends at a space, / or > ("<s.mueller@…>" is an
// address, not <s>). Tags are read from the raw body and entities decoded only in text and href, so
// "&lt;b&gt;" a sender escaped stays text. rich = false: plain text (dedup, codes).
function markup(raw, rich) {
  var text = String(raw || ""), out = "", last = 0, anchorOpen = false
  var tagRe = /<(\/?)([a-z][a-z0-9]*)(?=[\s\/>])([^<>]*)>/gi, m
  var links = rich && !/<a\s/i.test(text)
  function emitText(t) {
    t = decodeEntities(t)
    out += rich ? linkify(t, links) : t
  }
  while ((m = tagRe.exec(text)) !== null) {
    emitText(text.slice(last, m.index))
    last = tagRe.lastIndex
    var close = m[1] === "/", tag = m[2].toLowerCase(), simple = own(SIMPLE_TAGS, tag)
    if (tag === "br") out += rich ? "<br/>" : "\n"
    else if (simple) { if (rich) out += "<" + (close ? "/" : "") + simple + ">" }
    else if (own(DROP_TAGS, tag)) { }
    else if (tag === "a") {
      if (!rich) continue
      if (close) { if (anchorOpen) { out += "</a>"; anchorOpen = false } continue }
      var href = /href\s*=\s*(?:"([^"]*)"|'([^']*)')/i.exec(m[3])
      var url = href ? safeHttpUrl(decodeEntities(href[1] !== undefined ? href[1] : href[2])) : ""
      if (url && !anchorOpen) { out += "<a href=\"" + url + "\">"; anchorOpen = true }
    }
    else emitText(m[0])
  }
  emitText(text.slice(last))
  if (anchorOpen) out += "</a>"
  return out
}

function richBody(raw) { return markup(raw, true) }
function plainBody(raw) { return markup(raw, false) }
// A body that is plain already (history without a rich copy) as StyledText: escaped, never parsed again
// (its entities are decoded: parsing it would turn a sender's escaped "&lt;b&gt;" into markup).
function textRich(plain) { return linkify(String(plain || ""), false) }

// --- URLs (omarchy Security.safeHttpUrl, narrower than a browser's parser) -------------------------
// No userinfo, control characters, encoded control / % / backslash, odd ports, single-label hosts
// (localhost), loopback names (*.localhost, localhost.localdomain: one click opened CUPS) or a numeric
// last label (IPv4 shorthand that reaches loopback). "" when refused.
function safeHttpUrl(url) {
  var s = String(url || "").trim()
  if (s.length === 0 || s.length > 4096) return ""
  if (/[\u0000-\u0020\u007f<>"'\\`]/.test(s)) return ""
  if (/%(?:[01][0-9a-f]|7f|25|5c)/i.test(s)) return ""
  var m = /^(https?):\/\/([^\/?#]+)([\/?#].*)?$/i.exec(s)
  if (!m) return ""
  var hp = /^([a-z0-9.-]+?)\.?(?::(\d{1,5}))?$/i.exec(m[2])
  if (!hp) return ""
  var host = hp[1].toLowerCase(), labels = host.split(".")
  if (labels.length < 2 || host.length > 253) return ""
  for (var i = 0; i < labels.length; i++) {
    if (labels[i] === "" || labels[i].length > 63 || /^-|-$/.test(labels[i])) return ""
  }
  if (/^(\d+|0x[0-9a-f]*)$/i.test(labels[labels.length - 1])) return ""
  if (/(^|\.)localhost$/.test(host) || /^localhost\d*\.localdomain\d*$/.test(host)) return ""
  var port = hp[2] !== undefined ? Number(hp[2]) : 0
  if (hp[2] !== undefined && (port < 1 || port > 65535)) return ""
  return m[1].toLowerCase() + "://" + host + (port ? ":" + port : "") + (m[3] || "/")
}

// --- Verification codes (omarchy Detect.js): a false positive is worse than a miss -----------------
// German compounds ("Bestätigungscode") hide "code" from \b; a TAN is the bank's one-time code.
var CODE_WORDS = new RegExp("\\b(code|otp|one[\\s-]?time|verification|verify|passcode|pin|2fa|two[\\s-]factor|security key|" +
  "confirm(?:ation)?|tan|(?:bestätigungs|sicherheits|anmelde|einmal|verifizierungs|zugangs)code)\\b", "gi")
var NEAR_BEFORE = 24
var NEAR_AFTER = 72
var MAX_CODES = 8

// "Claude Code", "VS Code": a capitalised "Code" right after a capitalised word that is no keyword. Not
// after a possessive, article or login word: "Your Code: 482910", "Login Code", "Ihr Code lautet" are codes.
var CODE_OWNERS = /^(your|my|the|this|login|security|access|ihr|ihre|dein|deine|der|die|das)$/i
function isProductName(text, idx, word) {
  if (word !== "Code") return false
  var prev = /([A-Za-z]+)\s+$/.exec(text.slice(0, idx))
  return !!prev && /^[A-Z]/.test(prev[1]) && !new RegExp("^" + CODE_WORDS.source + "$", "i").test(prev[1])
    && !CODE_OWNERS.test(prev[1])
}

// "exit code 2", "status code 404", "Pin 2 messages": the keyword names a short number of its own,
// so the digits nearby are no login code ("code is 938 271" goes on: a group follows).
function namesShortNumber(text, end) {
  return /^\s*(?:is\s+|[:#=]\s*)?\d{1,3}(?!\d|[ \t\n-]\d)/.test(text.slice(end, end + 16))
}

function detectCodes(text) {
  text = String(text || "").slice(0, 4096)  // the scan is matches x keywords
  var windows = [], m
  CODE_WORDS.lastIndex = 0
  while ((m = CODE_WORDS.exec(text)) !== null) {
    if (m[0] !== "TAN" && /^tan$/i.test(m[0])) continue  // "Mr Tan": banks write TAN
    var end = m.index + m[0].length
    if (!isProductName(text, m.index, m[0]) && !namesShortNumber(text, end)) windows.push([m.index - NEAR_BEFORE, end + NEAR_AFTER])
  }
  if (windows.length === 0) return []
  function near(i) { return windows.some(function(w) { return i >= w[0] && i <= w[1] }) }
  function scan(re, accept) {
    var out = []
    re.lastIndex = 0
    while ((m = re.exec(text)) !== null && out.length < MAX_CODES) {
      var start = m.index + m[0].indexOf(m[1]), code = accept(m[1])
      // "#4821" is an issue / PR / order number.
      if (code && near(start) && text.charAt(start - 1) !== "#" && out.indexOf(code) < 0) out.push(code)
    }
    return out
  }
  var digits = scan(/(?:^|[^\w-])((?:[A-Za-z]-)?\d{2,4}[ \t\n-]\d{2,5}|(?:[A-Za-z]-)?\d{4,8})(?![\w-])/g, function(c) {
    c = c.replace(/^[A-Za-z]-/, "").replace(/[\s-]/g, "")
    return /^\d{4,8}$/.test(c) && !/^(19|20)\d\d$/.test(c) ? c : ""
  })
  if (digits.length > 0) return digits
  return scan(/(?:^|[^\w-])([A-Z0-9]{5,8})(?![\w-])/g, function(c) {
    return /\d/.test(c) && /[A-Z]/.test(c) ? c : ""
  })
}

// A code worth breaking Do Not Disturb for: one next to an unambiguous phrase (the windows above also
// open on "code", "pin", "confirm", which "PR 4821 ... verify" or "confirm: meeting at 1530" trip).
// "your code" / "Ihr Code" only right before the code: "Your code review is ready (PR 4821)" is none.
var LOGIN_WORDS = new RegExp("\\b(otp|one[\\s-]?time|verification|passcode|2fa|two[\\s-]factor|security (?:key|code)|" +
  "(?:login|sign[\\s-]?in|access) (?:code|pin)|your (?:code|pin)(?=\\s*(?:is\\b|:|\\d))|" +
  "(?:bestätigungs|sicherheits|anmelde|einmal|verifizierungs|zugangs)code|einmalpasswort|(?:zwei|2)[\\s-]?faktor|" +
  "(?:ihr|ihre|dein|deine) (?:code|pin|tan)(?=\\s*(?:lautet|ist\\b|:|\\d)))\\b", "i")
function isLoginCode(text, codes) {
  return !!codes && codes.length > 0 && LOGIN_WORDS.test(String(text || ""))
}

// History keeps the text with only the codes blanked: a false hit loses a number, not the message.
var CODE_SPAN = /(^|[^\w-])((?:[A-Za-z]-)?\d{2,4}[ \t\n-]\d{2,5}|(?:[A-Za-z]-)?\d{4,8}|[A-Z0-9]{5,8})(?![\w-])/g
function maskCodes(text, codes) {
  return String(text || "").replace(CODE_SPAN, function(m, pre, c) {
    var v = c.replace(/^[A-Za-z]-/, "").replace(/[\s-]/g, "")
    return pre + (codes.indexOf(v) >= 0 ? "••••" : c)
  })
}

// --- Buttons and history -------------------------------------------------------------------------
var MAX_ACTIONS = 4
var MAX_LABEL = 24  // a pill wider than the card is clipped, and Flow cannot wrap a single item

function ellipsize(s) {
  if (s.length <= MAX_LABEL) return s
  var n = MAX_LABEL - 1, c = s.charCodeAt(n - 1)
  if (c >= 0xd800 && c <= 0xdbff) n--  // never cut an emoji (surrogate pair) in half
  return s.slice(0, n) + "…"
}

// Sender actions as {id, text}: no `default` (the card click runs it, as the spec has it: senders send it
// unlabelled), no settings / empty ids, at most MAX_ACTIONS.
function actionList(actions) {
  var out = []
  for (var i = 0; i < (actions ? actions.length : 0); i++) {
    var id = String(actions[i].identifier || ""), label = String(actions[i].text || "").trim()
    if (id === "" || id === "default" || id.length > 256 || /^settings$/i.test(id)) continue
    out.push({ id: id, text: ellipsize(label || id) })
  }
  return out.slice(0, MAX_ACTIONS)
}

// What the history file keeps: no live-only fields; codes blanked in the text (no rich copy: the card
// shows the masked plain body as text, textRich), and no image (it may show the code).
function historyCopy(entry) {
  var e = {}
  for (var k in entry) if (k !== "actions" && k !== "group") e[k] = entry[k]
  if (e.codes && e.codes.length > 0) {
    e.summary = maskCodes(e.summary, e.codes)
    e.body = maskCodes(e.body, e.codes)
    delete e.rich
    e.image = ""
    e.codes = []
  }
  return e
}
