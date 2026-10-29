.pragma library

// Look Up card (WritingTools.qml, phase "lookup"): `asahi-writing-tools run define` streams
// "key: value" lines (term, pos, lang, definition, translation, wiki). Parsed on every delta, so a
// half-written last line shows as it grows.

var KEYS = ["term", "pos", "lang", "definition", "translation", "wiki"]

function parse(text) {
  var out = {}, last = ""
  text.split("\n").forEach(function (line) {
    var m = /^\s*([a-z]+):\s*(.*)$/.exec(line)
    if (m && KEYS.indexOf(m[1]) >= 0) {
      last = m[1]
      if (!(last in out)) out[last] = m[2].trim()
    } else if (last && line.trim() !== "") {
      out[last] = (out[last] + " " + line.trim()).trim() // a value wrapped onto the next line
    }
  })
  KEYS.forEach(function (k) {
    if (/^none\.?$/i.test(out[k] || "")) delete out[k]
  })
  out.lang = /^[a-z]{2,3}$/.test(out.lang || "") ? out.lang : ""
  return out
}

// German entries go to the German wikis, everything else to the English ones (which cover all
// languages). Special:Search with go jumps straight to an exact title, else lists results.
// Kagi Translate gets the selection as written (context), into English (German for English).
function links(e, selection) {
  var text = selection.trim().replace(/\s+/g, " ")
  var term = e.term || text
  var wiki = e.lang === "de" ? "de" : "en"
  function search(site, q) {
    return "https://" + wiki + "." + site + ".org/wiki/Special:Search?go=Go&search=" + encodeURIComponent(q)
  }
  return {
    wiki: search("wikipedia", e.wiki || term),
    dict: search("wiktionary", term),
    dictcc: "https://www.dict.cc/?s=" + encodeURIComponent(term),
    kagi: "https://translate.kagi.com/?from=auto&to=" + (e.lang === "en" ? "de" : "en") + "&quality=standard&text="
      + encodeURIComponent(text || term),
  }
}

function esc(s) {
  return s.replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;")
}

// Pane body: definition, then the translations in the accent colour (#rrggbb).
function html(e, accent) {
  var out = e.definition ? "<p>" + esc(e.definition) + "</p>" : ""
  if (e.translation)
    out += '<p style="margin-top:8px;color:' + accent + '">→ ' + esc(e.translation) + "</p>"
  return out
}

// Ctrl+C with nothing selected in the pane.
function text(e) {
  return [e.term, e.definition, e.translation].filter(function (s) { return !!s }).join("\n")
}
