pragma Singleton
import QtQuick
import Quickshell
import "modules/wallpaper" as Wallpaper

// Catppuccin Mocha for menu bar - delegates to DefaultTheme.qml (single source)
Singleton {
  readonly property color bg:        Wallpaper.DefaultTheme.base
  readonly property color surface:   Wallpaper.DefaultTheme.base
  readonly property color moduleBg:  Wallpaper.DefaultTheme.surface0
  readonly property color border:    Wallpaper.DefaultTheme.surface1

  readonly property color text:      Wallpaper.DefaultTheme.text
  readonly property color textMuted: Wallpaper.DefaultTheme.subtext0
  readonly property color textAlt:   Wallpaper.DefaultTheme.subtext1
  readonly property color muted:     Wallpaper.DefaultTheme.overlay0

  readonly property color red:       Wallpaper.DefaultTheme.red
  readonly property color green:     Wallpaper.DefaultTheme.green
  readonly property color yellow:    Wallpaper.DefaultTheme.yellow
  readonly property color cyan:      Wallpaper.DefaultTheme.sky
  readonly property color blue:      Wallpaper.DefaultTheme.blue
  readonly property color blueAlt:   Wallpaper.DefaultTheme.blue
  readonly property color magenta:   Wallpaper.DefaultTheme.mauve
  readonly property color orange:    Wallpaper.DefaultTheme.peach
  readonly property color lavender:  Wallpaper.DefaultTheme.lavender

  readonly property color hoverBg:   Wallpaper.DefaultTheme.surface1
  readonly property color controlBg: Wallpaper.DefaultTheme.surface0
  readonly property color wsNumBg:   Wallpaper.DefaultTheme.surface0

  readonly property color wsBg:             Qt.alpha(Wallpaper.DefaultTheme.base, 0.72)
  readonly property color wsBorder:         Qt.alpha(Wallpaper.DefaultTheme.text, 0.07)
  readonly property color wsActive:         Wallpaper.DefaultTheme.teal
  readonly property color wsActiveAlt:      Qt.lighter(Wallpaper.DefaultTheme.mauve, 1.16)
  readonly property color wsActiveBorder:   Qt.alpha(Wallpaper.DefaultTheme.rosewater, 0.45)
  readonly property color wsActiveBg:       Qt.alpha(Wallpaper.DefaultTheme.mauve, 0.20)
  readonly property color wsHoverBg:        Qt.alpha(Wallpaper.DefaultTheme.text, 0.10)
  readonly property color wsOccupiedBg:     Qt.alpha(Wallpaper.DefaultTheme.text, 0.10)
  readonly property color wsEmptyBg:        Qt.alpha(Wallpaper.DefaultTheme.text, 0.04)
  readonly property color wsInactiveBorder: Qt.alpha(Wallpaper.DefaultTheme.text, 0.14)
  readonly property color wsBadgeActiveBg:     Qt.alpha(Wallpaper.DefaultTheme.crust, 0.30)
  readonly property color wsBadgeHoverBg:      Qt.alpha(Wallpaper.DefaultTheme.mauve, 0.24)
  readonly property color wsBadgeOccupiedBg:   Qt.alpha(Wallpaper.DefaultTheme.text, 0.16)
  readonly property color wsBadgeEmptyBg:      Qt.alpha(Wallpaper.DefaultTheme.text, 0.08)
  readonly property color wsBadgeBorder:       Qt.alpha(Wallpaper.DefaultTheme.text, 0.24)
  readonly property color wsBadgeActiveBorder: Qt.alpha(Wallpaper.DefaultTheme.rosewater, 0.36)
  readonly property color wsBadgeActiveText:   "#ffffff"
  readonly property color wsOccupiedText:   Wallpaper.DefaultTheme.text
  readonly property color wsEmptyText:      Wallpaper.DefaultTheme.overlay1

  // Full re-export for complete delegation (no hex dups; enables Style. for all DefaultTheme names)
  readonly property color crust:      Wallpaper.DefaultTheme.crust
  readonly property color mantle:     Wallpaper.DefaultTheme.mantle
  readonly property color surface2:   Wallpaper.DefaultTheme.surface2
  readonly property color overlay1:   Wallpaper.DefaultTheme.overlay1
  readonly property color overlay2:   Wallpaper.DefaultTheme.overlay2
  readonly property color rosewater:  Wallpaper.DefaultTheme.rosewater
  readonly property color flamingo:   Wallpaper.DefaultTheme.flamingo
  readonly property color pink:       Wallpaper.DefaultTheme.pink
  readonly property color maroon:     Wallpaper.DefaultTheme.maroon
  readonly property color teal:       Wallpaper.DefaultTheme.teal
  readonly property color sapphire:   Wallpaper.DefaultTheme.sapphire
  readonly property color bgOverlay:  Wallpaper.DefaultTheme.bgOverlay
  readonly property color bgSelected: Wallpaper.DefaultTheme.bgSelected
  readonly property color bgBase:     Wallpaper.DefaultTheme.bgBase
  readonly property color bgSurface:  Wallpaper.DefaultTheme.bgSurface
  readonly property color bgHover:    Wallpaper.DefaultTheme.bgHover
  readonly property color bgBorder:   Wallpaper.DefaultTheme.bgBorder
  readonly property color textPrimary:   Wallpaper.DefaultTheme.textPrimary
  readonly property color textSecondary: Wallpaper.DefaultTheme.textSecondary
  readonly property color accentPrimary: Wallpaper.DefaultTheme.accentPrimary
  readonly property color accentCyan:    Wallpaper.DefaultTheme.accentCyan
  readonly property color accentGreen:   Wallpaper.DefaultTheme.accentGreen
  readonly property color accentOrange:  Wallpaper.DefaultTheme.accentOrange
  readonly property color accentRed:     Wallpaper.DefaultTheme.accentRed
  readonly property color primary:         Wallpaper.DefaultTheme.primary
  readonly property color onPrimary:       Wallpaper.DefaultTheme.onPrimary
  readonly property color urgencyLow:      Wallpaper.DefaultTheme.urgencyLow
  readonly property color urgencyNormal:   Wallpaper.DefaultTheme.urgencyNormal
  readonly property color urgencyCritical: Wallpaper.DefaultTheme.urgencyCritical
  readonly property color batteryGood:     Wallpaper.DefaultTheme.batteryGood
  readonly property color batteryWarning:  Wallpaper.DefaultTheme.batteryWarning
  readonly property color batteryCritical: Wallpaper.DefaultTheme.batteryCritical

  readonly property int radius: 6
  readonly property int radiusSm: 4

  readonly property string fontFamily: "JetBrainsMono Nerd Font"
  readonly property int fontSize: 16
  readonly property int fontSizeSm: 13
  readonly property int fontSizeTiny: 12
}
