pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import "wallpaper_thumbs.js" as WallThumbs

Singleton {
  id: root

  property list<string> wallpapers: []
  property string currentWallpaper: ""
  property string backend: "hyprpaper"
  property string defaultFit: "cover"   // default fit mode passed to hyprpaper (cover, stretch, etc.)
  property bool hyprpaperIpcErrorShown: false   // show the "restart hyprpaper" message only once per session
  property string wallpaperConf: (Quickshell.env("XDG_STATE_HOME") || (Quickshell.env("HOME") + "/.local/state")) + "/quickshell/wallpaper.conf"
  property int thumbsEpoch: 0
  readonly property string thumbCacheDir: WallThumbs.cacheDir(Quickshell.env("HOME"))

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
      if (saved !== "") root.currentWallpaper = saved
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
    currentWallpaper = path

    // Always save the choice
    saveProcess.command = ["sh", "-c", "mkdir -p \"$(dirname \"$1\")\" && printf \"%s\" \"$2\" > \"$1\"", "sh", root.wallpaperConf, path]
    saveProcess.running = true

    // Apply directly (hyprpaper preload IPC returns invalid+exit1 here; wallpaper= cmd works and changes it, matching asahi-wallpaper-menu)
    applyProc.command = ["hyprctl", "hyprpaper", "wallpaper", "," + path + "," + root.defaultFit]
    applyProc.running = true
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
}
