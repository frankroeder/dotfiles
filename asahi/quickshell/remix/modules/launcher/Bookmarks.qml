import QtQuick
import Quickshell
import Quickshell.Io
import "Data.js" as Data

// Minimal port of launcher Bookmarks: favs + history persisted to cache json. Ctrl+S toggles star.
Item {
  id: bm

  property var favourites: []
  property var history: []
  readonly property int historyCap: 30
  readonly property string statePath: Quickshell.env("HOME") + "/.cache/quickshell/remix-launcher/state.json"

  readonly property var favouriteItems: Data.annotate(bm.favourites)
  readonly property var historyItems: Data.annotate(bm.history)

  readonly property var favouriteKeys: {
    const out = {}
    for (let i = 0; i < bm.favourites.length; i++) {
      out[Data.itemKey(bm.favourites[i])] = true
    }
    return out
  }

  function snapshot(item) {
    return {
      title: item.title || item.name || "",
      icon: item.icon || "",
      category: item.category || "",
      exec: item.exec || "",
      path: item.path || "",
      keywords: item.keywords || "",
      special: item.special || "",
      glyph: item.glyph || ""
    }
  }

  function isFavourite(item) {
    return !!bm.favouriteKeys[Data.itemKey(item)]
  }

  function toggleFavourite(item) {
    if (!item) return
    const k = Data.itemKey(item)
    if (!k) return
    const next = []
    let found = false
    for (let i = 0; i < bm.favourites.length; i++) {
      if (Data.itemKey(bm.favourites[i]) === k) { found = true; continue }
      next.push(bm.favourites[i])
    }
    if (!found) next.unshift(bm.snapshot(item))
    bm.favourites = next
    bm.save()
  }

  function record(item) {
    if (!item || item.isCategory || item.special === "noop") return
    const k = Data.itemKey(item)
    if (!k) return
    const snap = bm.snapshot(item)
    const nextH = bm.history.filter(h => Data.itemKey(h) !== k)
    nextH.unshift(snap)
    bm.history = nextH.slice(0, bm.historyCap)
    bm.save()
  }

  function save() {
    saveProc.command = ["sh", "-c",
      "mkdir -p \"$(dirname \"$1\")\" && printf %s \"$2\" > \"$1\"",
      "sh", bm.statePath, JSON.stringify({ favourites: bm.favourites, history: bm.history })]
    saveProc.running = true
  }

  function load() {
    loadProc.command = ["cat", bm.statePath]
    loadProc.running = true
  }

  Process { id: saveProc; running: false }

  Process {
    id: loadProc
    onExited: code => {
      if (code !== 0) return
      try {
        const txt = (loadStdout.text || "").trim()
        if (!txt) return
        const j = JSON.parse(txt)
        if (j.favourites) bm.favourites = j.favourites
        if (j.history) bm.history = j.history
      } catch (_) {}
    }
    stdout: StdioCollector { id: loadStdout }
  }

  Component.onCompleted: load()
}
