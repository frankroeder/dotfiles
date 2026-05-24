pragma Singleton
import QtQuick
import Quickshell

// Catppuccin Mocha (dark mode) - source for notification colors + wallpaper picker
Singleton {
  // Full Mocha palette (official)
  readonly property color crust:  "#11111b"
  readonly property color mantle: "#181825"
  readonly property color base:   "#1e1e2e"
  readonly property color surface0: "#313244"
  readonly property color surface1: "#45475a"
  readonly property color surface2: "#585b70"
  readonly property color overlay0: "#6c7086"
  readonly property color overlay1: "#7f849c"
  readonly property color overlay2: "#9399b2"
  readonly property color text:      "#cdd6f4"
  readonly property color subtext0:  "#a6adc8"
  readonly property color subtext1:  "#bac2de"
  readonly property color rosewater: "#f5e0dc"
  readonly property color flamingo:  "#f2cdcd"
  readonly property color pink:      "#f5c2e7"
  readonly property color mauve:     "#cba6f7"
  readonly property color red:       "#f38ba8"
  readonly property color maroon:    "#eba0ac"
  readonly property color peach:     "#fab387"
  readonly property color yellow:    "#f9e2af"
  readonly property color green:     "#a6e3a1"
  readonly property color teal:      "#94e2d5"
  readonly property color sky:       "#89dceb"
  readonly property color sapphire:  "#74c7ec"
  readonly property color blue:      "#89b4fa"
  readonly property color lavender:  "#b4befe"

  // Legacy names for wallpaper picker compatibility (mapped to Mocha)
  readonly property color bgBase: base
  readonly property color bgSurface: surface0
  readonly property color bgOverlay: "#88000000"
  readonly property color bgHover: surface1
  readonly property color bgSelected: surface2
  readonly property color bgBorder: surface1

  readonly property color textPrimary: text
  readonly property color textSecondary: subtext1
  readonly property color textMuted: subtext0

  readonly property color accentPrimary: blue
  readonly property color accentCyan: sky
  readonly property color accentGreen: green
  readonly property color accentOrange: peach
  readonly property color accentRed: red

  // Notification / status colors (Mocha)
  readonly property color urgencyLow: subtext0
  readonly property color urgencyNormal: blue
  readonly property color urgencyCritical: red
  readonly property color batteryGood: green
  readonly property color batteryWarning: peach
  readonly property color batteryCritical: red
}
