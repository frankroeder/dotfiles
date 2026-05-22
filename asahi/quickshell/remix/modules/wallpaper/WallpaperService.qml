pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
  id: root

  property list<string> wallpapers: []
  property string currentWallpaper: ""
  property string backend: "hyprpaper"
  property string defaultFit: "cover"   // default fit mode passed to hyprpaper (cover, stretch, etc.)
  property bool hyprpaperIpcErrorShown: false   // show the "restart hyprpaper" message only once per session

  // Scan wallpaper directories (our setup uses ~/Pictures/wallpaper)
  Process {
    id: scanner
    command: ["sh", "-c",
      "find \"$HOME/Pictures/wallpaper\" \"$HOME/Pictures/Wallpapers\" -maxdepth 2 -type f \\( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' -o -iname '*.webp' \\) 2>/dev/null | sort -u | head -200"
    ]
    running: false
    stdout: SplitParser {
      onRead: data => {
        const path = data.trim()
        if (path !== "") {
          root.wallpapers = [...root.wallpapers, path]
        }
      }
    }
  }

  // Ensure ~/.config/quickshell/ + wallpaper.conf exists (silences first-run FileView warn)
  Process {
    id: ensureConf
    command: ["sh", "-c", "mkdir -p \"$HOME/.config/quickshell\" && touch \"$HOME/.config/quickshell/wallpaper.conf\""]
    running: false
    Component.onCompleted: running = true
  }

  // Load saved wallpaper path (now safe, empty file on first run)
  FileView {
    id: configFile
    path: Quickshell.env("HOME") + "/.config/quickshell/wallpaper.conf"
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
    saveProcess.command = ["sh", "-c", "printf \"%s\" \"$1\" > \"$HOME/.config/quickshell/wallpaper.conf\"", "sh", path]
    saveProcess.running = true

    // Try to apply live via hyprpaper
    preloadProc.command = ["sh", "-c", "hyprctl hyprpaper unload all; hyprctl hyprpaper preload \"$1\"", "sh", path]
    preloadProc.running = true
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
      applyProc.command = ["hyprctl", "hyprpaper", "wallpaper", "," + path + "," + root.defaultFit]
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
        Quickshell.execDetached(["notify-send", "-a", "Wallpaper", "Wallpaper changed", path.split("/").pop()])
      }
    }
  }

  Process {
    id: saveProcess
    command: []
    running: false
  }
}
