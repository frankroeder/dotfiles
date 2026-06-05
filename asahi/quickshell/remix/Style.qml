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
  readonly property color wsActiveAlt:      Qt.lighter(Wallpaper.DefaultTheme.sky, 1.08)
  readonly property color wsActiveBorder:   Qt.alpha(Wallpaper.DefaultTheme.sky, 0.45)
  readonly property color wsActiveBg:       Qt.alpha(Wallpaper.DefaultTheme.sky, 0.20)
  readonly property color wsHoverBg:        Qt.alpha(Wallpaper.DefaultTheme.text, 0.10)
  readonly property color wsOccupiedBg:     Qt.alpha(Wallpaper.DefaultTheme.text, 0.10)
  readonly property color wsVisibleBg:      Qt.alpha(Wallpaper.DefaultTheme.sky, 0.14)
  readonly property color wsEmptyBg:        Qt.alpha(Wallpaper.DefaultTheme.text, 0.04)
  readonly property color wsInactiveBorder: Qt.alpha(Wallpaper.DefaultTheme.text, 0.14)
  readonly property color wsVisibleBorder:  Qt.alpha(Wallpaper.DefaultTheme.sky, 0.30)
  readonly property color wsBadgeActiveBg:     Qt.alpha(Wallpaper.DefaultTheme.crust, 0.30)
  readonly property color wsBadgeHoverBg:      Qt.alpha(Wallpaper.DefaultTheme.sky, 0.24)
  readonly property color wsBadgeVisibleBg:    Qt.alpha(Wallpaper.DefaultTheme.sky, 0.18)
  readonly property color wsBadgeOccupiedBg:   Qt.alpha(Wallpaper.DefaultTheme.text, 0.16)
  readonly property color wsBadgeEmptyBg:      Qt.alpha(Wallpaper.DefaultTheme.text, 0.08)
  readonly property color wsBadgeBorder:       Qt.alpha(Wallpaper.DefaultTheme.text, 0.24)
  readonly property color wsBadgeActiveBorder: Qt.alpha(Wallpaper.DefaultTheme.sky, 0.36)
  readonly property color wsBadgeActiveText:   "#ffffff"
  readonly property color wsOccupiedText:   Wallpaper.DefaultTheme.text
  readonly property color wsEmptyText:      Wallpaper.DefaultTheme.overlay1

  readonly property color barBg:          Qt.alpha(Wallpaper.DefaultTheme.surface0, 0.86)
  readonly property color barHoverBg:     Qt.alpha(Wallpaper.DefaultTheme.surface1, 0.92)
  readonly property color barBorder:      Qt.alpha(Wallpaper.DefaultTheme.text, 0.10)
  readonly property color barHoverBorder: Qt.alpha(Wallpaper.DefaultTheme.sky, 0.34)

  readonly property color panelOverlay:         Qt.alpha(Wallpaper.DefaultTheme.crust, 0.76)
  readonly property color panelBg:              Qt.alpha(Wallpaper.DefaultTheme.base, 0.98)
  readonly property color panelSidebarBg:       Qt.alpha(Wallpaper.DefaultTheme.crust, 0.96)
  readonly property color panelMainBg:          Wallpaper.DefaultTheme.base
  readonly property color panelCardBg:          Qt.alpha(Wallpaper.DefaultTheme.surface0, 0.74)
  readonly property color panelCardHover:       Qt.alpha(Wallpaper.DefaultTheme.surface1, 0.82)
  readonly property color panelCardActive:      Qt.alpha(Wallpaper.DefaultTheme.sky, 0.18)
  readonly property color panelCardBorder:      Qt.alpha(Wallpaper.DefaultTheme.text, 0.09)
  readonly property color panelCardBorderHover: Qt.alpha(Wallpaper.DefaultTheme.sky, 0.32)
  readonly property color panelInputBg:         Qt.alpha(Wallpaper.DefaultTheme.surface0, 0.92)
  readonly property color panelControlBg:       Qt.alpha(Wallpaper.DefaultTheme.surface1, 0.54)
  readonly property color panelControlHover:    Qt.alpha(Wallpaper.DefaultTheme.surface2, 0.62)
  readonly property color panelAccentBg:        Qt.alpha(Wallpaper.DefaultTheme.sky, 0.20)
  readonly property color panelAccentBorder:    Qt.alpha(Wallpaper.DefaultTheme.sky, 0.40)
  readonly property color panelSuccessBg:       Qt.alpha(Wallpaper.DefaultTheme.green, 0.16)
  readonly property color panelDangerBg:        Qt.alpha(Wallpaper.DefaultTheme.red, 0.15)
  readonly property color panelWarningBg:       Qt.alpha(Wallpaper.DefaultTheme.peach, 0.16)
  readonly property color panelDivider:         Qt.alpha(Wallpaper.DefaultTheme.text, 0.10)

  // Omni-inspired menu chrome (Asahi palette, not omarchy paths)
  readonly property color menuPaper:   Wallpaper.DefaultTheme.crust
  readonly property color menuInk:     Wallpaper.DefaultTheme.text
  readonly property color menuInkDeep: Wallpaper.DefaultTheme.subtext0
  readonly property color menuInkMuted: Wallpaper.DefaultTheme.overlay1
  readonly property color menuSumi:    Wallpaper.DefaultTheme.overlay0
  readonly property color menuSeal:    Wallpaper.DefaultTheme.peach
  readonly property color menuIndigo:  Wallpaper.DefaultTheme.sapphire
  readonly property color menuSealAlt: Wallpaper.DefaultTheme.peach
  readonly property color menuBg:      Qt.rgba(menuPaper.r, menuPaper.g, menuPaper.b, 0.96)
  readonly property color menuSep:     Qt.rgba(menuInk.r, menuInk.g, menuInk.b, 0.16)
  readonly property color menuRowHi:   Qt.rgba(menuInk.r, menuInk.g, menuInk.b, 0.07)
  readonly property color menuRowSel:  Qt.rgba(menuSeal.r, menuSeal.g, menuSeal.b, 0.20)
  readonly property color menuDim:     Qt.rgba(0, 0, 0, 0.52)
  readonly property color menuCardBg:  Qt.rgba(menuInk.r, menuInk.g, menuInk.b, 0.05)
  readonly property color menuControlBg: Qt.rgba(menuInk.r, menuInk.g, menuInk.b, 0.08)
  readonly property int menuRadius: 6
  readonly property int menuTitleSpacing: 4
  readonly property int menuLabelSpacing: 2
  readonly property string menuMono: "JetBrainsMono Nerd Font"
  readonly property string menuSerif: "serif"

  // Full re-export for complete delegation (no hex dups; enables Style. for all DefaultTheme names)
  readonly property color crust:      Wallpaper.DefaultTheme.crust
  readonly property color mantle:     Wallpaper.DefaultTheme.mantle
  readonly property color base:       Wallpaper.DefaultTheme.base
  readonly property color surface0:   Wallpaper.DefaultTheme.surface0
  readonly property color surface1:   Wallpaper.DefaultTheme.surface1
  readonly property color surface2:   Wallpaper.DefaultTheme.surface2
  readonly property color overlay1:   Wallpaper.DefaultTheme.overlay1
  readonly property color overlay2:   Wallpaper.DefaultTheme.overlay2
  readonly property color rosewater:  Wallpaper.DefaultTheme.rosewater
  readonly property color flamingo:   Wallpaper.DefaultTheme.flamingo
  readonly property color pink:       Wallpaper.DefaultTheme.pink
  readonly property color mauve:      Wallpaper.DefaultTheme.mauve
  readonly property color sky:        Wallpaper.DefaultTheme.sky
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
