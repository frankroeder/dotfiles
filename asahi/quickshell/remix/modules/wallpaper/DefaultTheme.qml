pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Wallpaper palette for Quickshell. Mocha until asahi-autotheme writes colors.json.
Singleton {
  id: root

  readonly property string stateHome: Quickshell.env("XDG_STATE_HOME") || (Quickshell.env("HOME") + "/.local/state")
  readonly property string colorsPath: root.stateHome + "/asahi-theme/colors.json"
  readonly property string themeNamePath: root.stateHome + "/asahi-theme/theme.name"

  property color crust:  "#11111b"
  property color mantle: "#181825"
  property color base:   "#1e1e2e"
  property color surface0: "#313244"
  property color surface1: "#45475a"
  property color surface2: "#585b70"
  property color overlay0: "#6c7086"
  property color overlay1: "#7f849c"
  property color overlay2: "#9399b2"
  property color text:      "#cdd6f4"
  property color subtext0:  "#a6adc8"
  property color subtext1:  "#bac2de"
  property color rosewater: "#f5e0dc"
  property color flamingo:  "#f2cdcd"
  property color pink:      "#f5c2e7"
  property color mauve:     "#cba6f7"
  property color red:       "#f38ba8"
  property color maroon:    "#eba0ac"
  property color peach:     "#fab387"
  property color yellow:    "#f9e2af"
  property color green:     "#a6e3a1"
  property color teal:      "#94e2d5"
  property color sky:       "#89dceb"
  property color sapphire:  "#74c7ec"
  property color blue:      "#89b4fa"
  property color lavender:  "#b4befe"

  property string mode: "dark"
  readonly property bool isDark: mode === "dark"
  property string wallpaper: ""
  property string variant: "source"
  property color accent: blue
  property int generation: 0

  readonly property color bgBase: base
  readonly property color bgSurface: surface0
  readonly property color bgOverlay: "#88000000"
  readonly property color bgHover: surface1
  readonly property color bgSelected: surface2
  readonly property color bgBorder: surface1

  readonly property color textPrimary: text
  readonly property color textSecondary: subtext1
  readonly property color textMuted: subtext0

  readonly property color accentPrimary: accent
  readonly property color accentCyan: sky
  readonly property color accentGreen: green
  readonly property color accentOrange: peach
  readonly property color accentRed: red
  readonly property color primary: accent
  readonly property color onPrimary: crust

  readonly property color urgencyLow: subtext0
  readonly property color urgencyNormal: accent
  readonly property color urgencyCritical: red
  readonly property color batteryGood: green
  readonly property color batteryWarning: peach
  readonly property color batteryCritical: red

  function applyJson(text) {
    if (!text || !String(text).trim()) return false
    try {
      const data = JSON.parse(text)
      const keys = [
        "crust", "mantle", "base", "surface0", "surface1", "surface2",
        "overlay0", "overlay1", "overlay2", "text", "subtext0", "subtext1",
        "rosewater", "flamingo", "pink", "mauve", "red", "maroon", "peach",
        "yellow", "green", "teal", "sky", "sapphire", "blue", "lavender"
      ]
      for (let i = 0; i < keys.length; i++) {
        const k = keys[i]
        if (data[k]) root[k] = data[k]
      }
      if (data.accent) root.accent = data.accent
      else if (data.blue) root.accent = data.blue
      if (data.mode) root.mode = data.mode
      if (data.wallpaper) root.wallpaper = data.wallpaper
      if (data.variant) root.variant = data.variant
      root.generation += 1
      return true
    } catch (e) {
      console.warn("DefaultTheme: failed to parse colors.json", e)
      return false
    }
  }

  function reloadFromDisk() {
    colorsFile.reload()
    root.applyJson(colorsFile.text())
  }

  FileView {
    id: colorsFile
    path: root.colorsPath
    watchChanges: true
    onFileChanged: root.reloadFromDisk()
    onLoaded: root.applyJson(colorsFile.text())
  }

  FileView {
    id: themeMarker
    path: root.themeNamePath
    watchChanges: true
    onFileChanged: root.reloadFromDisk()
    onLoaded: root.reloadFromDisk()
  }

  Timer {
    interval: 400
    running: true
    repeat: false
    onTriggered: root.reloadFromDisk()
  }

  Timer {
    interval: 2000
    running: true
    repeat: false
    onTriggered: root.reloadFromDisk()
  }

  Component.onCompleted: root.reloadFromDisk()
}
