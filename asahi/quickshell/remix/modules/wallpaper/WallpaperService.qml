pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import "wallpaper_thumbs.js" as WallThumbs
import "wallpaper_colors.js" as WallColors

Singleton {
  id: root

  property list<string> wallpapers: []
  property string currentWallpaper: ""
  property string backend: "hyprpaper"
  property string defaultFit: "cover"   // default fit mode passed to hyprpaper (cover, stretch, etc.)
  property bool hyprpaperIpcErrorShown: false   // show the "restart hyprpaper" message only once per session
  readonly property string stateHome: Quickshell.env("XDG_STATE_HOME") || (Quickshell.env("HOME") + "/.local/state")
  property string wallpaperConf: stateHome + "/quickshell/wallpaper.conf"
  readonly property string lockWallpaper: stateHome + "/asahi/lock-wallpaper"
  property int thumbsEpoch: 0
  readonly property string thumbCacheDir: WallThumbs.cacheDir(Quickshell.env("HOME"))

  // Live preview (caelestia Wallpapers.preview): the carousel's centre item is
  // shown on the desktop, its palette is applied to the shell without touching
  // colors.json, and Ghostty is rethemed (`asahi-autotheme --preview`).
  // stopPreview() restores all three; commitPreview() applies for real.
  //
  // Opt-in: Shift in the picker arms it, and from then on every preselected
  // wallpaper repaints in real time. Disarmed, browsing is thumbnails only —
  // no hyprpaper churn and no autotheme per keystroke.
  property bool liveMode: false
  property string browsePath: ""    // centre tile, previewed only while armed
  property string previewPath: ""
  property bool previewApplied: false
  property string fadePath: ""
  // A full autotheme pass is ~110ms, so this only has to swallow key-repeat:
  // the timer restarts per browse step and fires once the user pauses.
  readonly property int previewWaitMs: 70
  readonly property int previewThemeDelayMs: 100
  readonly property int previewFadeMs: 320
  readonly property string autotheme: Quickshell.env("HOME") + "/.dotfiles/asahi/bin/asahi-autotheme"

  // Flavour (matugen scheme analogue). autotheme records it in colors.json, so
  // this binding restores the last choice at startup and pins once setFlavor runs.
  property string flavor: DefaultTheme.variant || "source"

  function preview(path) {
    if (!path) return
    root.browsePath = path
    if (!root.liveMode || path === root.previewPath) return
    root.previewPath = path
    previewDebounce.restart()
  }
  function setLive(on) {
    if (root.liveMode === on) return
    root.liveMode = on
    if (on) root.preview(root.browsePath)
    else root.stopPreview()
  }
  // Re-theme without touching the wallpaper: refresh the preview while one is
  // running, otherwise apply for real — a flavour chip is a deliberate choice.
  property bool flavorDirty: false   // picked mid-preview, not yet written to disk

  function applyFlavor() {
    root.flavorDirty = false
    if (!root.currentWallpaper) return
    themeProc.command = [root.autotheme, "--variant", root.flavor, root.currentWallpaper]
    if (themeProc.running) themeProc.running = false
    themeProc.running = true
  }
  function setFlavor(name) {
    if (!name || name === root.flavor) return
    root.flavor = name
    if (root.previewPath !== "") { root.flavorDirty = true; previewThemeDelay.restart(); return }
    root.applyFlavor()
  }
  function stopPreview() {
    previewDebounce.stop()
    previewThemeDelay.stop()
    root.previewPath = ""
    const wasApplied = root.previewApplied
    root.previewApplied = false
    if (wasApplied) {
      if (root.currentWallpaper) root.showOnDesktop(root.currentWallpaper)
      DefaultTheme.reloadFromDisk()
    }
    if (!root.currentWallpaper) { root.flavorDirty = false; return }
    // A flavour picked mid-preview is a lasting choice, so commit it here — the
    // preview only ever painted the shell, colors.json still holds the old one.
    if (root.flavorDirty) { root.applyFlavor(); return }
    if (!wasApplied) return
    if (previewThemeProc.running) previewThemeProc.running = false
    previewThemeProc.command = [root.autotheme, "--preview", "--variant", root.flavor, root.currentWallpaper]
    previewThemeProc.running = true
  }
  function commitPreview() {
    const p = root.previewPath
    previewDebounce.stop()
    previewThemeDelay.stop()
    root.previewPath = ""
    root.previewApplied = false
    if (p) root.setWallpaper(p)
  }
  // hyprpaper takes up to a second per full-size image and a Process ignores
  // `running = true` while busy, so keep only the newest request and replay it
  // when the current load exits. Otherwise fast browsing leaves the desktop one
  // step behind the centre tile (or on a preview after closing).
  property string wallQueued: ""
  function showOnDesktop(path) {
    if (previewWallProc.running) { root.wallQueued = path; return }
    root.wallQueued = ""
    previewWallProc.command = ["sh", "-c",
      "hyprctl hyprpaper wallpaper \",$1,$2\" >/dev/null 2>&1; hyprctl hyprpaper unload unused >/dev/null 2>&1",
      "sh", path, root.defaultFit]
    previewWallProc.running = true
  }
  function randomWallpaper() {
    const n = root.wallpapers.length
    return n ? root.wallpapers[Math.floor(Math.random() * n)] : ""
  }

  Timer {
    id: previewDebounce
    interval: root.previewWaitMs
    onTriggered: {
      if (root.previewPath === "" || (root.previewPath === root.currentWallpaper && !root.previewApplied)) return
      root.fadePath = root.previewPath
      root.previewApplied = true
      root.showOnDesktop(root.previewPath)
      previewThemeDelay.restart()
    }
  }
  Timer {
    id: previewThemeDelay
    interval: root.previewThemeDelayMs
    onTriggered: {
      if (root.previewPath === "") return
      if (previewThemeProc.running) previewThemeProc.running = false
      previewThemeProc.command = [root.autotheme, "--preview", "--variant", root.flavor, root.previewPath]
      previewThemeProc.running = true
    }
  }
  Process {
    id: previewThemeProc
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: if (root.previewPath !== "") DefaultTheme.applyJson(text)
    }
  }
  Process {
    id: previewWallProc
    onExited: function() {
      const p = root.wallQueued
      root.wallQueued = ""
      if (!p) return
      // A stale preview must not overtake a wallpaper applied meanwhile.
      if (root.previewPath === "" && p !== root.currentWallpaper) return
      root.showOnDesktop(p)
    }
  }

  function previewSource(original) {
    const _ = root.thumbsEpoch
    if (!original) return ""
    return WallThumbs.previewSource(original, root.thumbCacheDir, root.thumbsEpoch > 0)
  }

  function rebuildThumbs() {
    const paths = []
    for (let i = 0; i < root.wallpapers.length; i++) paths.push(root.wallpapers[i])
    const script = WallThumbs.thumbBatchScript(paths, root.thumbCacheDir)
    thumbProc.command = ["sh", "-c", script]
    if (thumbProc.running) thumbProc.running = false
    thumbProc.running = true
  }

  // Dominant-color index: six colors per wallpaper, sampled from the thumbs, for
  // the picker's color/tone filters and the palette strip (wallpaper_colors.js).
  // ~1.3s over 230 cold, a single `find` once warm — so it chases the thumbs.
  property var colorIndex: ({})
  readonly property string colorIndexPath: WallThumbs.colorIndexPath(root.thumbCacheDir)

  function colorEntry(path) { return (path && root.colorIndex[path]) || null }

  // Picker filters live here so the compact card and the launcher pane agree.
  property string filterTone: ""     // "" | dark | light
  property string filterBucket: ""   // "" | a wallpaper_colors BUCKETS key
  property string sortKey: "name"    // name | color | tone

  function arranged(query) {
    return WallColors.arrange(root.wallpapers, root.colorIndex,
      { query: query || "", tone: root.filterTone, bucket: root.filterBucket, sort: root.sortKey })
  }
  function filterCounts(query) {
    return WallColors.counts(root.wallpapers, root.colorIndex,
      { query: query || "", tone: root.filterTone, bucket: root.filterBucket })
  }
  function clearFilters() { root.filterTone = ""; root.filterBucket = ""; root.sortKey = "name" }

  function rebuildColorIndex() {
    const paths = []
    for (let i = 0; i < root.wallpapers.length; i++) paths.push(root.wallpapers[i])
    if (paths.length === 0) return
    colorProc.command = ["sh", "-c", WallThumbs.colorIndexScript(paths, root.thumbCacheDir)]
    if (colorProc.running) colorProc.running = false
    colorProc.running = true
  }

  function loadColorIndex() {
    colorsFile.reload()
    root.colorIndex = WallColors.parseIndex(colorsFile.text())
  }

  Process {
    id: colorProc
    running: false
    stdout: StdioCollector {
      onStreamFinished: if ((text || "").indexOf("COLORS_DONE") >= 0) root.loadColorIndex()
    }
  }

  FileView {
    id: colorsFile
    path: root.colorIndexPath
    onLoaded: root.colorIndex = WallColors.parseIndex(colorsFile.text())
  }

  // Scan wallpaper directories (our setup uses ~/Pictures/wallpaper).
  // Collected in one shot and assigned ONCE: the old per-line append rebuilt
  // the wallpapers list (and thus reset every wallpaper GridView) once per
  // file, which made opening/rescanning the pickers crawl.
  Process {
    id: scanner
    command: ["sh", "-c",
      "find \"$HOME/Pictures/wallpaper\" \"$HOME/Pictures/Wallpapers\" -maxdepth 2 -type f \\( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' -o -iname '*.webp' \\) 2>/dev/null | sort -u | head -500"
    ]
    running: false
    stdout: StdioCollector {
      onStreamFinished: {
        const found = []
        const lines = (text || "").split("\n")
        for (let i = 0; i < lines.length; i++) {
          const path = lines[i].trim()
          if (path !== "") found.push(path)
        }
        root.wallpapers = found
        // From here, not onExited: the exit signal can race the collector,
        // and rebuildThumbs must see the fresh list.
        root.rebuildThumbs()
      }
    }
  }

  Process {
    id: thumbProc
    running: false
    stdout: StdioCollector {
      onStreamFinished: {
        if ((text || "").indexOf("THUMBS_DONE") >= 0) root.thumbsEpoch += 1
      }
    }
    onExited: {
      if (root.thumbsEpoch === 0) root.thumbsEpoch = 1
      root.rebuildColorIndex()   // the index samples the thumbs, so it waits for them
    }
  }

  // Ensure local wallpaper state exists (silences first-run FileView warn)
  Process {
    id: ensureConf
    running: false
    Component.onCompleted: {
      command = ["sh", "-c", "mkdir -p \"$(dirname \"$1\")\" && touch \"$1\"", "sh", root.wallpaperConf]
      running = true
    }
  }

  // Load saved wallpaper path (now safe, empty file on first run)
  FileView {
    id: configFile
    path: root.wallpaperConf
    onTextChanged: {
      const saved = configFile.text().trim()
      if (saved === "") return
      root.currentWallpaper = saved
      // Re-assert on load: heals a desktop left on a preview if the shell died mid-browse.
      root.showOnDesktop(saved)
      Quickshell.execDetached([
        "sh", "-c",
        "mkdir -p \"$(dirname \"$2\")\" && [ -f \"$1\" ] && ln -sfn \"$1\" \"$2\"",
        "sh", saved, root.lockWallpaper
      ])
    }
  }

  Component.onCompleted: {
    scanner.running = true
  }

  function rescan() {
    wallpapers = []
    scanner.running = true
  }

  function setWallpaper(path) {
    previewDebounce.stop()
    previewThemeDelay.stop()
    root.previewPath = ""
    root.previewApplied = false
    root.wallQueued = ""
    root.flavorDirty = false   // the autotheme call below writes the flavour anyway
    currentWallpaper = path

    // Always save the choice
    saveProcess.command = ["sh", "-c", "mkdir -p \"$(dirname \"$1\")\" \"$(dirname \"$3\")\" && printf \"%s\" \"$2\" > \"$1\" && ln -sfn \"$2\" \"$3\"", "sh", root.wallpaperConf, path, root.lockWallpaper]
    saveProcess.running = true

    // Apply directly (hyprpaper preload IPC returns invalid+exit1 here; wallpaper= cmd works and changes it, matching asahi-wallpaper-menu)
    applyProc.command = ["hyprctl", "hyprpaper", "wallpaper", "," + path + "," + root.defaultFit]
    applyProc.running = true

    // Wallpaper-driven adaptive theme (Quickshell / Ghostty / LibreWolf / Hyprland)
    themeProc.command = [root.autotheme, "--variant", root.flavor, path]
    if (themeProc.running) themeProc.running = false
    themeProc.running = true
  }

  // Preload step
  Process {
    id: preloadProc
    stdout: StdioCollector {}
    stderr: StdioCollector {}
    onExited: (code) => {
      if (code !== 0) {
        const err = (stderr.text + stdout.text).trim()
        console.warn("hyprpaper preload failed (code " + code + "):", err)
        if (err.includes("invalid hyprpaper request")) {
            if (!root.hyprpaperIpcErrorShown) {
                root.hyprpaperIpcErrorShown = true
                console.warn("hyprpaper IPC not enabled. Raw error:", err)
                Quickshell.execDetached([
                    "notify-send", "-a", "Wallpaper",
                    "Hyprpaper IPC not enabled",
                    "Wallpaper saved. Restart hyprpaper to apply:\n  pkill hyprpaper && hyprpaper &"
                ])
            }
            return
        }
        const msg = err || "code " + code
        Quickshell.execDetached(["notify-send", "-a", "Wallpaper", "Hyprpaper preload failed", msg])
        return
      }
      // Simple global apply (no jq dependency)
      // Format: hyprctl hyprpaper wallpaper ",<path>,<fit_mode>"
      applyProc.command = ["hyprctl", "hyprpaper", "wallpaper", "," + root.currentWallpaper + "," + root.defaultFit]
      applyProc.running = true
    }
  }

  // Apply step
  Process {
    id: applyProc
    stdout: StdioCollector {}
    stderr: StdioCollector {}
    onExited: (code) => {
      if (code !== 0) {
        const err = (stderr.text + stdout.text).trim()
        console.warn("hyprpaper wallpaper apply failed (code " + code + "):", err)
        if (err.includes("invalid hyprpaper request")) {
            if (!root.hyprpaperIpcErrorShown) {
                root.hyprpaperIpcErrorShown = true
                console.warn("hyprpaper IPC not enabled. Raw error:", err)
                Quickshell.execDetached([
                    "notify-send", "-a", "Wallpaper",
                    "Hyprpaper IPC not enabled",
                    "Wallpaper saved. Restart hyprpaper to apply:\n  pkill hyprpaper && hyprpaper &"
                ])
            }
            return
        }
        const msg = err || "code " + code
        Quickshell.execDetached(["notify-send", "-a", "Wallpaper", "Hyprpaper apply failed", msg])
      } else {
        Quickshell.execDetached(["notify-send", "-a", "Wallpaper", "Wallpaper changed", root.currentWallpaper.split("/").pop()])
      }
    }
  }

  Process {
    id: saveProcess
    command: []
    running: false
  }

  Process {
    id: themeProc
    command: []
    running: false
    stdout: StdioCollector {}
    stderr: StdioCollector {}
    onExited: (code) => {
      if (code !== 0) {
        const err = ((stderr.text || "") + (stdout.text || "")).trim()
        console.warn("asahi-autotheme failed (code " + code + "):", err)
        return
      }
      // Pull fresh colors into DefaultTheme/Style immediately (FileView can race).
      try { DefaultTheme.reloadFromDisk() } catch (e) {
        console.warn("DefaultTheme reload after autotheme:", e)
      }
    }
  }
}
