import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Widgets
import "../wallpaper" as Wallpaper
import "../../"

Scope {
  id: root

  property var theme: Wallpaper.DefaultTheme
  property bool shouldShow: false
  property string query: ""
  property int selectedIndex: 0
  property var launcherScreen: null
  property int launcherWorkspaceId: 1
  property int resultCount: 0
  property int deVersion: 0
  property int dictVersion: 0
  property string dictStatus: ""
  property string dictPendingTerm: ""
  property string dictRunningTerm: ""
  property string dictCopyLang: ""
  property string dictError: ""
  property var dictItems: []
  property int fileVersion: 0
  property string fileStatus: ""
  property string filePendingTerm: ""
  property string fileRunningTerm: ""
  property var fileItems: []

  readonly property string binDir: Quickshell.env("HOME") + "/.dotfiles/asahi/bin"
  readonly property string dictIcon: "file://" + Quickshell.env("HOME") + "/.dotfiles/asahi/quickshell/remix/assets/dict-cc.png"
  readonly property string webIconBase: "file://" + Quickshell.env("HOME") + "/.dotfiles/asahi/quickshell/remix/assets/"
  readonly property string websearchJsonPath: Quickshell.env("HOME") + "/.dotfiles/asahi/quickshell/remix/modules/launcher/websearch.json"
  property int webVersion: 0

  readonly property string headerText: {
    const q = root.query.trim()
    if (q.startsWith("=")) return "Calculator"
    if (q.startsWith("!")) return "Web Search"
    if (q.startsWith("@")) return "Documentation"
    if (root.fileTerm(q) !== null) return "File Search"
    if (root.dictTerm(q) !== null) return "Dictionary"
    return "Applications"
  }

  readonly property string resultText: {
    const c = root.resultCount
    const s = c !== 1 ? "s" : ""
    const qq = root.query.trim()
    if (root.fileTerm(qq) !== null) {
      if (root.fileStatus === "loading") return "Searching files..."
      if (root.fileStatus === "error") return "fd search failed"
      if (root.fileStatus === "prompt") return "Type after > to search ~"
      if (root.fileStatus === "no-results") return "No files found"
      const count = root.fileItems.length
      return count + (count === 200 ? "+" : "") + " match" + (count !== 1 ? "es" : "") + " · Enter opens"
    }
    if (root.dictTerm(qq) !== null) {
      if (root.dictStatus === "loading") return "Loading dict.cc"
      if (root.dictStatus === "error") return "dict.cc lookup failed"
      if (root.dictStatus === "prompt") return "Type after dict to translate"
      if (root.dictStatus === "no-results") return "No translations"
      const lang = root.dictCopyLang === "en" ? "English" : (root.dictCopyLang === "de" ? "German" : "translation")
      return c + " result" + s + " · Return copies " + lang
    }
    if (qq.startsWith("=") || qq.startsWith("!") || qq.startsWith("@")) return c + " result" + s
    return c + " application" + s
  }

  onResultCountChanged: {
    const max = Math.max(0, root.resultCount - 1)
    if (resultsList && resultsList.currentIndex > max && max >= 0) {
      resultsList.currentIndex = max
    }
  }
  onDictVersionChanged: root.resetDictSelection()
  onFileVersionChanged: root.resetFileSelection()

  function launchCurrent() {
    let entry = null
    if (resultsList && resultsList.currentItem && resultsList.currentItem.modelData) {
      entry = resultsList.currentItem.modelData
    } else if (filteredApps && filteredApps.values && resultsList.currentIndex < filteredApps.values.length) {
      entry = filteredApps.values[resultsList.currentIndex]
    }
    if (entry) root.launchApp(entry)
  }

  function openLauncher() {
    const mon = Hyprland.focusedMonitor
    launcherScreen = mon ? (Quickshell.screens.find(s => s.name === mon.name) ?? Quickshell.screens[0]) : (Quickshell.screens[0] ?? null)
    launcherWorkspaceId = Hyprland.focusedWorkspace?.id ?? 1
    shouldShow = true
    searchInput.text = ""
    if (resultsList) resultsList.currentIndex = 0
    Qt.callLater(() => { if (searchInput) searchInput.forceActiveFocus() })
  }

  function openFileSearch(term) {
    root.openLauncher()
    searchInput.text = ">" + (term || "")
  }

  function closeLauncher() {
    shouldShow = false
  }

  function shQuote(s) {
    return "'" + String(s).replace(/'/g, "'\\''") + "'"
  }

  function luaQuote(s) {
    return JSON.stringify(String(s))
  }

  function launchDesktopEntry(entry) {
    const command = Array.from(entry.command || [])
    const exec = command.length > 0 ? command.map(root.shQuote).join(" ") : String(entry.execString || "")
    if (exec === "") {
      entry.execute()
      return
    }

    const ws = root.launcherWorkspaceId || Hyprland.focusedWorkspace?.id || 1
    Quickshell.execDetached(["hyprctl", "dispatch", "hl.dsp.focus({ workspace = " + ws + " })"])
    Quickshell.execDetached(["hyprctl", "dispatch", "hl.dsp.exec_cmd(" + root.luaQuote("[workspace " + ws + "] " + exec) + ")"])
  }

  function launchApp(entry) {
    if (!entry) { shouldShow = false; return }
    if (entry.special === "noop") {
      return
    } else if (entry.special === "calc") {
      const res = entry.result || ""
      if (res) Quickshell.execDetached(["bash", "-c", "echo -n '" + res.replace(/'/g, "'\\''") + "' | wl-copy"])
    } else if (entry.special === "dict") {
      const copy = entry.copy || ""
      if (copy) Quickshell.execDetached(["sh", "-c", "printf %s \"$1\" | wl-copy", "sh", copy])
    } else if (entry.special === "file" && entry.path) {
      Quickshell.execDetached(["xdg-open", entry.path])
    } else if ((entry.special === "web" || entry.special === "doc") && entry.url) {
      let u = entry.url
      if (u.includes("%TERM%")) u = u.replace("%TERM%", "")
      u = u.replace(/\?q=$/, "").replace(/\?s=$/, "").replace(/&text=$/, "").replace(/search\?q=$/, "")
      Quickshell.execDetached(["xdg-open", u])
    } else if (entry.execute) {
      shouldShow = false
      Qt.callLater(() => root.launchDesktopEntry(entry))
      return
    }
    shouldShow = false
  }

  function dictTerm(q) {
    const value = (q || "").trim()
    const m = value.match(/^dict(?:\s+(.*))?$/i)
    return m ? (m[1] || "").trim() : null
  }

  function fileTerm(q) {
    const value = (q || "").trim()
    return value.startsWith(">") ? value.substring(1).trim() : null
  }

  function resetFileSelection() {
    if (!resultsList || fileTerm(root.query) === null) return
    resultsList.currentIndex = 0
    resultsList.positionViewAtBeginning()
  }

  function scheduleFileLookup() {
    const term = fileTerm(root.query)
    fileDebounce.stop()
    if (term === null) {
      root.filePendingTerm = ""
      root.fileStatus = ""
      root.fileItems = []
      root.fileVersion++
      return
    }
    root.filePendingTerm = term
    if (!term) {
      root.fileStatus = "prompt"
      root.fileItems = []
      root.fileVersion++
      return
    }
    root.fileStatus = "loading"
    root.fileVersion++
    fileDebounce.restart()
  }

  function startFileLookup() {
    const term = root.filePendingTerm
    if (!term || fileProc.running) return
    root.fileRunningTerm = term
    root.fileStatus = "loading"
    root.fileVersion++
    fileProc.command = [
      "fd",
      "--type", "f",
      "--type", "d",
      "--max-results", "200",
      "--absolute-path",
      "--color", "never",
      "--fixed-strings",
      "--", term, Quickshell.env("HOME")
    ]
    fileProc.running = true
  }

  function finishFileLookup(exitCode, stdoutText, stderrText) {
    const term = root.fileRunningTerm
    if (term === root.filePendingTerm && term === fileTerm(root.query)) {
      if (exitCode !== 0) {
        root.fileStatus = "error"
        root.fileItems = [{
          id: "file-error",
          name: "File search failed",
          comment: stderrText.trim() || ("fd exited " + exitCode),
          icon: "",
          glyph: "󰅙",
          special: "noop"
        }]
      } else {
        const paths = stdoutText.split("\n").filter(line => line.length > 0)
        root.fileItems = root.sortFileResults(paths.map(root.formatFileResult), term)
        root.fileStatus = root.fileItems.length > 0 ? "ready" : "no-results"
      }
      root.fileVersion++
    }
    if (root.filePendingTerm && root.filePendingTerm !== term) fileDebounce.restart()
  }

  function getFileResults(q) {
    const term = fileTerm(q)
    if (term === null) return null
    if (!term) {
      return [{ id: "file-prompt", name: "Search files and folders", comment: "Type > followed by a filename", icon: "", glyph: "󰍉", special: "noop" }]
    }
    if (root.fileStatus === "loading") {
      return [{ id: "file-loading", name: "Searching " + term, comment: "Searching ~ with fd", icon: "", glyph: "󰍉", special: "noop" }]
    }
    if (root.fileStatus === "error") return root.fileItems
    if (root.fileItems.length === 0) {
      return [{ id: "file-empty", name: "No files found", comment: term, icon: "", glyph: "󰍉", special: "noop" }]
    }
    return root.fileItems
  }

  function formatFileResult(rawPath) {
    const isDirectory = rawPath.length > 1 && rawPath.endsWith("/")
    const path = isDirectory ? rawPath.substring(0, rawPath.length - 1) : rawPath
    const parts = path.split("/")
    const name = parts.pop() || path
    const parent = parts.join("/") || "/"
    return {
      id: "file-" + path,
      name: name,
      comment: root.displayFilePath(parent),
      accessory: isDirectory ? "DIR" : "",
      icon: "",
      glyph: root.fileGlyph(name, isDirectory),
      special: "file",
      path: path,
      isDirectory: isDirectory
    }
  }

  function displayFilePath(path) {
    const home = Quickshell.env("HOME")
    if (path === home) return "~"
    return path.startsWith(home + "/") ? "~" + path.substring(home.length) : path
  }

  function sortFileResults(items, term) {
    const query = term.toLowerCase()
    return items.sort((a, b) => {
      const ar = root.fileRank(a.name.toLowerCase(), query)
      const br = root.fileRank(b.name.toLowerCase(), query)
      if (ar !== br) return ar - br
      if (a.isDirectory !== b.isDirectory) return a.isDirectory ? -1 : 1
      if (a.name.toLowerCase() !== b.name.toLowerCase()) return a.name.toLowerCase().localeCompare(b.name.toLowerCase())
      return a.path.length - b.path.length
    })
  }

  function fileRank(name, query) {
    if (name === query) return 0
    if (name.startsWith(query)) return 1
    if (name.includes(query)) return 2
    return 3
  }

  function fileGlyph(name, isDirectory) {
    if (isDirectory) return "󰉋"
    const ext = name.includes(".") ? name.split(".").pop().toLowerCase() : ""
    if (["jpg", "jpeg", "png", "gif", "svg", "webp", "bmp", "ico"].includes(ext)) return "󰋩"
    if (["mp3", "wav", "flac", "ogg", "m4a", "aac"].includes(ext)) return "󰎆"
    if (["mp4", "mkv", "avi", "mov", "webm"].includes(ext)) return "󰎁"
    if (["zip", "tar", "gz", "bz2", "xz", "7z", "rar"].includes(ext)) return "󰀼"
    return "󰈔"
  }

  Timer {
    id: fileDebounce
    interval: 250
    onTriggered: root.startFileLookup()
  }

  Process {
    id: fileProc
    stdout: StdioCollector { id: fileStdout }
    stderr: StdioCollector { id: fileStderr }
    onExited: code => root.finishFileLookup(code, fileStdout.text, fileStderr.text)
  }

  function resetDictSelection() {
    if (!resultsList || dictTerm(root.query) === null) return
    resultsList.currentIndex = 0
    resultsList.positionViewAtBeginning()
  }

  function scheduleDictLookup() {
    const term = dictTerm(root.query)
    dictDebounce.stop()
    if (term === null) {
      root.dictPendingTerm = ""
      root.dictStatus = ""
      root.dictCopyLang = ""
      root.dictError = ""
      root.dictItems = []
      root.dictVersion++
      return
    }
    root.dictPendingTerm = term
    if (!term) {
      root.dictStatus = "prompt"
      root.dictCopyLang = ""
      root.dictError = ""
      root.dictItems = []
      root.dictVersion++
      return
    }
    root.dictStatus = "loading"
    root.dictCopyLang = ""
    root.dictError = ""
    root.dictItems = []
    root.dictVersion++
    dictDebounce.restart()
  }

  function startDictLookup() {
    const term = root.dictPendingTerm
    if (!term || dictProc.running) return
    root.dictRunningTerm = term
    root.dictStatus = "loading"
    root.dictVersion++
    dictProc.running = true
  }

  function finishDictLookup(text) {
    const term = root.dictRunningTerm
    if (term === root.dictPendingTerm && term === dictTerm(root.query)) {
      try {
        const data = JSON.parse((text || "").trim())
        root.dictStatus = data.status || "error"
        root.dictCopyLang = data.copyLang || ""
        root.dictError = data.error || ""
        root.dictItems = data.items || []
      } catch (_) {
        root.dictStatus = "error"
        root.dictCopyLang = ""
        root.dictError = "Invalid lookup response"
        root.dictItems = []
      }
      root.dictVersion++
    }
    if (root.dictPendingTerm && root.dictPendingTerm !== term) dictDebounce.restart()
  }

  function formatDictMeta(meta) {
    if (!meta || typeof meta !== "object") return ""
    const join = parts => (parts || []).filter(Boolean).join(", ")
    return [
      join(meta.abbreviations),
      join(meta.wordClassDefinitions),
      join(meta.comments),
      join(meta.optionalData)
    ].filter(s => s.length > 0).join(" · ")
  }

  function getDictResults(q) {
    const term = dictTerm(q)
    if (term === null) return null
    if (!term) {
      return [{
        id: "dict-prompt",
        name: "Translate with dict.cc",
        comment: "Type dict followed by a word · en de Term for language override",
        icon: root.dictIcon,
        special: "noop"
      }]
    }
    if (root.dictStatus === "loading") {
      return [{ id: "dict-loading", name: "Looking up " + term, comment: "dict.cc DE↔EN", icon: root.dictIcon, special: "noop" }]
    }
    if (root.dictStatus === "error") {
      return [{
        id: "dict-error",
        name: "dict.cc lookup failed",
        comment: root.dictError || "Network or parser error",
        icon: root.dictIcon,
        special: "noop"
      }]
    }
    if (root.dictStatus === "no-results" || root.dictItems.length === 0) {
      return [{ id: "dict-empty", name: "No dict.cc results", comment: term, icon: root.dictIcon, special: "noop" }]
    }
    return root.dictItems.map((it, i) => {
      const metaLine = root.formatDictMeta(it.meta)
      return {
        id: "dict-" + i,
        name: it.target || it.copy || "",
        comment: (it.source || "") + (metaLine ? " · " + metaLine : ""),
        accessory: (it.copyLang || root.dictCopyLang || "").toUpperCase(),
        icon: root.dictIcon,
        special: "dict",
        copy: it.copy || it.target || ""
      }
    })
  }

  Timer {
    id: dictDebounce
    interval: 250
    onTriggered: root.startDictLookup()
  }

  Process {
    id: dictProc
    command: ["python3", root.binDir + "/asahi-dictcc.py", root.dictRunningTerm]
    stdout: StdioCollector { id: dictStdout }
    onExited: () => root.finishDictLookup(dictStdout.text)
  }

  // websearch: @ uses engines[] (fuzzy lists + prefix direct). ! passes the literal text to Kagi via defaultSearchUrl.
  // Icons prepared exactly like dictIcon so they render in the launcher results list.
  property var webEngines: [
    { name: "Kagi", prefix: "kagi", url: "https://kagi.com/search?q=%TERM%", icon: root.webIconBase + "kagi.png" },
    { name: "Jax Documentation", prefix: "jaxdoc", url: "https://docs.jax.dev/en/latest/search.html?q=%TERM%", icon: root.webIconBase + "jax.png" },
    { name: "Flax Documentation", prefix: "flaxdoc", url: "https://flax.readthedocs.io/en/stable/search.html?q=%TERM%", icon: root.webIconBase + "flax.png" },
    { name: "dict.cc", prefix: "dcc", url: "https://www.dict.cc/?s=%TERM%", icon: root.webIconBase + "dict-cc.png" },
    { name: "NumPy Documentation", prefix: "npdoc", url: "https://numpy.org/doc/stable/search.html?q=%TERM%", icon: root.webIconBase + "numpy.png" },
    { name: "Kagi Translate", prefix: "kt", url: "https://translate.kagi.com/?from=auto&to=en_us&text=%TERM%", icon: root.webIconBase + "kagi.png" },
    { name: "PyTorch Documentation", prefix: "ptdoc", url: "https://docs.pytorch.org/docs/stable/search.html?q=%TERM%", icon: root.webIconBase + "pytorch.png" },
    { name: "Optax Documentation", prefix: "optax", url: "https://optax.readthedocs.io/en/latest/search.html?q=%TERM%", icon: root.webIconBase + "optax.png" },
    { name: "Grokipedia", prefix: "grokip", url: "https://grokipedia.com/search?q=%TERM%", icon: root.webIconBase + "grokipedia.png" }
  ]
  property string defaultSearchUrl: "https://kagi.com/search?q=%s"

  // Robust loading of websearch engines + icons from json (better than XHR).
  // Edit the json to add/remove engines; put matching PNGs in assets/.
  // Icons resolved at load time using the same base as dictIcon.
  FileView {
    id: websearchConfig
    path: root.websearchJsonPath
    watchChanges: true
    onLoaded: root.parseWebsearchConfig(text)
    onTextChanged: if (root) root.parseWebsearchConfig(text)
  }

  Connections {
    target: DesktopEntries
    function onApplicationsChanged() { root.deVersion++ }
  }

  function calculate(expr) {
    expr = (expr || "").trim()
    if (!expr) return null
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

  function parseWebsearchConfig(text) {
    try {
      var data = JSON.parse(text || "{}")
      if (data.engines && data.engines.length > 0) {
        var base = root.webIconBase
        webEngines = data.engines.map(function(e) {
          var ic = e.icon || ""
          var iconPath = ic
          if (ic && ic.indexOf(".") > 0 && !ic.startsWith("file://")) {
            iconPath = base + ic
          }
          var r = { name: e.name, prefix: e.prefix, url: e.url, icon: iconPath }
          if (e.description) r.description = e.description
          return r
        })
      }
      if (data.defaultSearchUrl) defaultSearchUrl = data.defaultSearchUrl
      webVersion++
    } catch (e) {
      console.warn("websearch.json parse failed")
    }
  }

  function getSpecialResults(qq) {
    const q = (qq || "").trim()
    if (!q) return null
    const fileResults = getFileResults(q)
    if (fileResults) return fileResults
    const dictResults = getDictResults(q)
    if (dictResults) return dictResults
    if (q.startsWith("=")) {
      const res = calculate(q.substring(1))
      if (res !== null) {
        return [{ id: "calc-" + res, name: "= " + res, comment: "Calculator — Enter to copy", icon: "󰃀", special: "calc", result: res }]
      }
      return null
    }
    if (q.startsWith("!")) {
      // Literal pass-through to Kagi (defaultSearchUrl). Whatever you type after ! is sent as the query string.
      const t = q.trim()
      if (t) {
        const tpl = root.defaultSearchUrl
        return [{
          id: "web",
          name: t,
          comment: "Kagi — Enter to search",
          icon: "󰖟",
          special: "web",
          url: tpl.replace("%s", encodeURIComponent(t))
        }]
      }
      return null
    }
    if (q.startsWith("@")) {
      const after = q.substring(1).trim()
      const la = after.toLowerCase()

      const engines = root.webEngines.length > 0 ? root.webEngines : [{
        name: "Kagi", prefix: "kagi", url: "https://kagi.com/search?q=%TERM%", icon: root.webIconBase + "kagi.png"
      }]

      // tiny subsequence fuzzy (for suggestion lists when typing partial @)
      const fuzzy = (hay, ned) => {
        if (!ned) return true
        hay = hay.toLowerCase(); ned = ned.toLowerCase()
        let i = 0
        for (const c of hay) { if (c === ned[i]) i++; if (i === ned.length) return true }
        return false
      }

      // exact prefix match for direct search (e.g. @ptdoc hello → PyTorch docs with the term)
      for (const e of engines) {
        const p = e.prefix
        if (la === p || la.startsWith(p + " ")) {
          let raw = after.substring(p.length).trim()
          const term = raw.replace(/^["'\s]+|["'\s]+$/g, "")
          let u = e.url
          if (term) u = u.replace("%TERM%", encodeURIComponent(term))
          else u = u.replace("%TERM%", "").replace(/\?q=$/, "").replace(/\?s=$/, "").replace(/&text=$/, "").replace(/search\?q=$/, "")
          return [{
            id: "doc-" + p,
            name: e.name + (term ? " — " + term : ""),
            comment: "Docs search — Enter to open",
            icon: e.icon,
            special: "doc",
            url: u
          }]
        }
      }

      // fuzzy list (matches prefix or name via subsequence) for @partial
      const f = engines.filter(e => fuzzy(e.prefix, la) || fuzzy(e.name, la) || la === "")
      if (f.length > 0) {
        return f.map(e => ({
          id: "doclist-" + e.prefix,
          name: e.name,
          comment: e.description || ("@" + e.prefix + " — select to search"),
          icon: e.icon,
          special: "doc",
          url: e.url.replace("%TERM%", "")
        }))
      }

      // fallback
      const t = after || ""
      const u = root.defaultSearchUrl.replace("%s", encodeURIComponent(t))
      return [{ id: "docdef", name: "Kagi — " + t, comment: "Enter to search", icon: "󰖟", special: "doc", url: u }]
    }
    return null
  }

  ScriptModel {
    id: filteredApps
    objectProp: "id"
    values: {
      root.deVersion
      root.dictVersion
      root.fileVersion
      root.webVersion
      const specials = root.getSpecialResults(root.query)
      if (specials && specials.length > 0) return specials
      let all = [...DesktopEntries.applications.values]
      all = all.filter(d => !d.noDisplay)
      const q = root.query.trim().toLowerCase()
      if (q === "") {
        return all.sort((a, b) => (a.name || "").localeCompare(b.name || ""))
      }
      const filtered = all.filter(d =>
        (d.name && d.name.toLowerCase().includes(q)) ||
        (d.genericName && d.genericName.toLowerCase().includes(q)) ||
        (d.keywords && d.keywords.some(k => k.toLowerCase().includes(q))) ||
        (d.categories && d.categories.some(c => c.toLowerCase().includes(q)))
      )
      return filtered.sort((a, b) => {
        const an = (a.name || "").toLowerCase()
        const bn = (b.name || "").toLowerCase()
        const aStarts = an.startsWith(q)
        const bStarts = bn.startsWith(q)
        if (aStarts && !bStarts) return -1
        if (!aStarts && bStarts) return 1
        return an.localeCompare(bn)
      })
    }
  }

  PanelWindow {
    id: launcherPanel
    visible: root.shouldShow
    focusable: true
    color: "transparent"

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
    WlrLayershell.namespace: "quickshell-launcher"
    exclusionMode: ExclusionMode.Ignore

    screen: root.launcherScreen

    anchors {
      top: true
      bottom: true
      left: true
      right: true
    }

    // Dark overlay backdrop
    MouseArea {
      anchors.fill: parent
      onClicked: root.shouldShow = false

      Rectangle {
        anchors.fill: parent
        color: root.theme.bgOverlay
      }
    }

    // Centered launcher box
    Rectangle {
      id: launcherBox
      anchors.centerIn: parent
      width: 580
      height: 480
      radius: 16
      color: root.theme.bgBase
      border.color: root.theme.bgBorder
      border.width: 1

      ColumnLayout {
        anchors.fill: parent
        anchors.margins: 16
        spacing: 12

        // Header
        Text {
          text: root.headerText
          color: root.theme.accentPrimary
          font.pixelSize: 14
          font.family: "Hack Nerd Font"
          font.bold: true
        }

        // Search bar
        Rectangle {
          Layout.fillWidth: true
          height: 44
          radius: 10
          color: root.theme.bgSurface
          border.color: searchInput.activeFocus ? root.theme.accentPrimary : root.theme.bgBorder
          border.width: 1

          Behavior on border.color {
            ColorAnimation { duration: 150 }
          }

          RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 14
            anchors.rightMargin: 14
            spacing: 10

            Text {
              text: "󰍉"
              color: root.theme.textMuted
              font.pixelSize: 18
              font.family: "Hack Nerd Font"
              Layout.alignment: Qt.AlignVCenter
            }

            TextInput {
              id: searchInput
              Layout.fillWidth: true
              Layout.alignment: Qt.AlignVCenter
              color: root.theme.textPrimary
              font.pixelSize: 15
              font.family: "Hack Nerd Font"
              clip: true
              focus: true
              Accessible.role: Accessible.EditableText
              Accessible.name: "Search applications"

              Text {
                anchors.fill: parent
                text: "Type to search..."
                color: root.theme.textMuted
                font: parent.font
                visible: !parent.text && !parent.activeFocus
                verticalAlignment: Text.AlignVCenter
              }

              onTextChanged: {
                root.query = text
                root.scheduleDictLookup()
                root.scheduleFileLookup()
                if (resultsList) resultsList.currentIndex = 0
              }

              Keys.onEscapePressed: root.shouldShow = false
              Keys.onReturnPressed: root.launchCurrent()
              Keys.onEnterPressed: root.launchCurrent()

              Keys.onPressed: event => {
                const max = Math.max(0, root.resultCount - 1)
                if (event.key === Qt.Key_Down) {
                  event.accepted = true
                  resultsList.currentIndex = Math.min(resultsList.currentIndex + 1, max)
                  resultsList.positionViewAtIndex(resultsList.currentIndex, ListView.Contain)
                } else if (event.key === Qt.Key_Up) {
                  event.accepted = true
                  resultsList.currentIndex = Math.max(resultsList.currentIndex - 1, 0)
                  resultsList.positionViewAtIndex(resultsList.currentIndex, ListView.Contain)
                } else if (event.key === Qt.Key_Tab) {
                  event.accepted = true
                  resultsList.currentIndex = Math.min(resultsList.currentIndex + 1, max)
                  resultsList.positionViewAtIndex(resultsList.currentIndex, ListView.Contain)
                }
              }
            }
          }
        }

        // Results count
        Text {
          text: root.resultText
          color: root.theme.textMuted
          font.pixelSize: 11
          font.family: "Hack Nerd Font"
        }

        // App list
        ListView {
          id: resultsList
          Layout.fillWidth: true
          Layout.fillHeight: true
          model: filteredApps
          clip: true
          spacing: 2
          boundsBehavior: Flickable.StopAtBounds
          currentIndex: 0
          highlightMoveDuration: 150
          highlightMoveVelocity: -1

          onCountChanged: root.resultCount = count
          onCurrentIndexChanged: if (currentIndex >= 0) root.selectedIndex = currentIndex

          highlight: Rectangle {
            radius: 8
            color: root.theme.bgSelected

            Rectangle {
              width: 3
              height: 24
              radius: 2
              color: root.theme.accentPrimary
              anchors.left: parent.left
              anchors.leftMargin: 2
              anchors.verticalCenter: parent.verticalCenter
            }
          }

          delegate: Rectangle {
            id: delegateRoot
            required property var modelData
            required property int index

            Accessible.role: Accessible.Button
            Accessible.name: (modelData.name ?? "Application") + (modelData.genericName ? " - " + modelData.genericName : "")

            width: resultsList.width
            height: 44
            radius: 8
            color: hoverArea.containsMouse && resultsList.currentIndex !== index ? root.theme.bgHover : "transparent"

            Behavior on color {
              ColorAnimation { duration: 100 }
            }

            RowLayout {
              anchors.fill: parent
              anchors.leftMargin: 12
              anchors.rightMargin: 12
              spacing: 12

              // App icon
              Item {
                width: 28
                height: 28
                Layout.alignment: Qt.AlignVCenter

                IconImage {
                  anchors.fill: parent
                  source: Quickshell.iconPath(delegateRoot.modelData.icon ?? "", true)
                  visible: (delegateRoot.modelData.icon ?? "") !== "" && !(delegateRoot.modelData.icon ?? "").startsWith("file://")
                }

                Image {
                  anchors.fill: parent
                  source: delegateRoot.modelData.icon ?? ""
                  fillMode: Image.PreserveAspectFit
                  visible: (delegateRoot.modelData.icon ?? "").startsWith("file://")
                }

                // Fallback letter icon
                Text {
                  anchors.centerIn: parent
                  text: delegateRoot.modelData.glyph ?? (delegateRoot.modelData.name ?? "?").charAt(0).toUpperCase()
                  color: root.theme.accentPrimary
                  font.pixelSize: 16
                  font.family: "Hack Nerd Font"
                  font.bold: true
                  visible: (delegateRoot.modelData.icon ?? "") === ""
                }
              }

              // App info
              ColumnLayout {
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignVCenter
                spacing: 1

                Text {
                  text: delegateRoot.modelData.name ?? ""
                  color: resultsList.currentIndex === delegateRoot.index ? root.theme.textPrimary : root.theme.textSecondary
                  font.pixelSize: 13
                  font.family: "Hack Nerd Font"
                  font.bold: resultsList.currentIndex === delegateRoot.index
                  elide: Text.ElideRight
                  Layout.fillWidth: true
                }

                Text {
                  text: delegateRoot.modelData.genericName ?? delegateRoot.modelData.comment ?? ""
                  color: root.theme.textMuted
                  font.pixelSize: 11
                  font.family: "Hack Nerd Font"
                  elide: Text.ElideRight
                  Layout.fillWidth: true
                  visible: text !== ""
                }
              }

              Rectangle {
                Layout.alignment: Qt.AlignVCenter
                width: accessoryText.visible ? accessoryText.width + 12 : 0
                height: accessoryText.visible ? 20 : 0
                radius: 5
                color: root.theme.bgSurface
                border.color: root.theme.bgBorder
                border.width: accessoryText.visible ? 1 : 0
                visible: accessoryText.visible

                Text {
                  id: accessoryText
                  anchors.centerIn: parent
                  text: delegateRoot.modelData.accessory ?? ""
                  color: root.theme.textMuted
                  font.pixelSize: 10
                  font.family: "Hack Nerd Font"
                  font.bold: true
                  visible: text !== ""
                }
              }
            }

            MouseArea {
              id: hoverArea
              anchors.fill: parent
              hoverEnabled: true
              cursorShape: Qt.PointingHandCursor
              onClicked: root.launchApp(delegateRoot.modelData)
              onEntered: resultsList.currentIndex = delegateRoot.index
            }
          }

          // Empty state
          Text {
            anchors.centerIn: parent
            text: "No results found"
            color: root.theme.textMuted
            font.pixelSize: 14
            font.family: "Hack Nerd Font"
            visible: root.resultCount === 0 && searchInput.text !== ""
          }
        }

        // Footer hint
        RowLayout {
          Layout.fillWidth: true
          spacing: 16

          Row {
            spacing: 4
            Rectangle {
              width: hintUp.width + 8; height: 18; radius: 4; color: Style.moduleBg
              Text { id: hintUp; anchors.centerIn: parent; text: "↑↓"; color: Style.text; font.pixelSize: 10; font.family: "Hack Nerd Font" }
            }
            Text {
              text: "navigate"
              color: Style.text
              font.pixelSize: 10
              font.family: "Hack Nerd Font"
              anchors.verticalCenter: parent.verticalCenter
            }
          }

          Row {
            spacing: 4
            Rectangle {
              width: hintEnter.width + 8; height: 18; radius: 4; color: Style.moduleBg
              Text { id: hintEnter; anchors.centerIn: parent; text: "⏎"; color: Style.text; font.pixelSize: 10; font.family: "Hack Nerd Font" }
            }
            Text {
              text: "launch"
              color: Style.text
              font.pixelSize: 10
              font.family: "Hack Nerd Font"
              anchors.verticalCenter: parent.verticalCenter
            }
          }

          Row {
            spacing: 4
            Rectangle {
              width: hintEsc.width + 8; height: 18; radius: 4; color: Style.moduleBg
              Text { id: hintEsc; anchors.centerIn: parent; text: "esc"; color: Style.text; font.pixelSize: 10; font.family: "Hack Nerd Font" }
            }
            Text {
              text: "close"
              color: Style.text
              font.pixelSize: 10
              font.family: "Hack Nerd Font"
              anchors.verticalCenter: parent.verticalCenter
            }
          }

          Text {
            text: "=:calc  !:kagi  @:docs  dict:translate  >:files"
            color: Style.text
            font.pixelSize: 10
            font.family: "Hack Nerd Font"
            Layout.alignment: Qt.AlignVCenter
          }
          Item { Layout.fillWidth: true }
        }
      }
    }
  }
}
