pragma Singleton
import QtQuick
import Quickshell
import "modules/wallpaper" as Wallpaper

// Wallpaper palette → shell chrome. DefaultTheme owns colors.json; generation
// bumps so every binding below re-evaluates after asahi-autotheme.
Singleton {
  readonly property int themeGeneration: Wallpaper.DefaultTheme.generation
  readonly property string mode: Wallpaper.DefaultTheme.mode
  readonly property bool isDark: Wallpaper.DefaultTheme.mode === "dark"

  function themed(name) {
    const _ = themeGeneration
    return Wallpaper.DefaultTheme[name]
  }

  function themedAlpha(name, a) {
    const _ = themeGeneration
    return Qt.alpha(Wallpaper.DefaultTheme[name], a)
  }

  readonly property color accent: themed("accent")

  readonly property color bg:        themed("base")
  readonly property color surface:   themed("base")
  readonly property color moduleBg:  themed("surface0")
  readonly property color border:    themed("surface1")

  readonly property color text:      themed("text")
  readonly property color textMuted: themed("subtext0")
  readonly property color textAlt:   themed("subtext1")
  readonly property color muted:     themed("overlay0")

  readonly property color red:       themed("red")
  readonly property color green:     themed("green")
  readonly property color yellow:    themed("yellow")
  readonly property color cyan:      themed("sky")
  readonly property color blue:      themed("blue")
  readonly property color blueAlt:   themed("blue")
  readonly property color magenta:   themed("mauve")
  readonly property color orange:    themed("peach")
  readonly property color lavender:  themed("lavender")

  readonly property color hoverBg:   themed("surface1")
  readonly property color controlBg: themed("surface0")
  readonly property color wsNumBg:   themed("surface0")

  readonly property color wsBg:             themedAlpha("base", 0.72)
  readonly property color wsBorder:         themedAlpha("text", 0.07)
  readonly property color wsActive:         accent
  readonly property color wsActiveAlt:      { const _ = themeGeneration; return Qt.lighter(Wallpaper.DefaultTheme.accent, 1.08) }
  readonly property color wsActiveBorder:   themedAlpha("accent", 0.45)
  readonly property color wsActiveBg:       themedAlpha("accent", 0.20)
  readonly property color wsHoverBg:        themedAlpha("text", 0.10)
  readonly property color wsOccupiedBg:     themedAlpha("text", 0.10)
  readonly property color wsVisibleBg:      themedAlpha("sky", 0.14)
  readonly property color wsEmptyBg:        themedAlpha("text", 0.04)
  readonly property color wsInactiveBorder: themedAlpha("text", 0.14)
  readonly property color wsVisibleBorder:  themedAlpha("sky", 0.30)
  readonly property color wsBadgeActiveBg:     themedAlpha("crust", 0.30)
  readonly property color wsBadgeHoverBg:      themedAlpha("sky", 0.24)
  readonly property color wsBadgeVisibleBg:    themedAlpha("sky", 0.18)
  readonly property color wsBadgeOccupiedBg:   themedAlpha("text", 0.16)
  readonly property color wsBadgeEmptyBg:      themedAlpha("text", 0.08)
  readonly property color wsBadgeBorder:       themedAlpha("text", 0.24)
  readonly property color wsBadgeActiveBorder: themedAlpha("sky", 0.36)
  readonly property color wsBadgeActiveText:   themed("crust")
  readonly property color wsOccupiedText:   themed("text")
  readonly property color wsEmptyText:      themed("overlay1")

  readonly property color barBg:          themedAlpha("surface0", 0.86)
  readonly property color barHoverBg:     themedAlpha("surface1", 0.92)
  readonly property color barBorder:      themedAlpha("text", 0.10)
  readonly property color barHoverBorder: themedAlpha("sky", 0.34)

  readonly property color barStripBg:     themed("mantle")
  readonly property color barStripText:   themed("text")
  readonly property color barStripMuted:  themed("subtext0")
  readonly property color barStripActive: themed("red")
  readonly property color barStripHover:  themedAlpha("text", 0.10)

  readonly property color panelOverlay:         themedAlpha("crust", 0.76)
  readonly property color panelBg:              themedAlpha("base", 0.98)
  readonly property color panelSidebarBg:       themedAlpha("crust", 0.96)
  readonly property color panelMainBg:          themed("base")
  readonly property color panelCardBg:          themedAlpha("surface0", 0.74)
  readonly property color panelCardHover:       themedAlpha("surface1", 0.82)
  readonly property color panelCardActive:      themedAlpha("accent", 0.18)
  readonly property color panelCardBorder:      themedAlpha("text", 0.09)
  readonly property color panelCardBorderHover: themedAlpha("accent", 0.32)
  readonly property color panelInputBg:         themedAlpha("surface0", 0.92)
  readonly property color panelControlBg:       themedAlpha("surface1", 0.54)
  readonly property color panelControlHover:    themedAlpha("surface2", 0.62)
  readonly property color panelAccentBg:        themedAlpha("accent", 0.20)
  readonly property color panelAccentBorder:    themedAlpha("accent", 0.40)
  readonly property color panelSuccessBg:       themedAlpha("green", 0.16)
  readonly property color panelDangerBg:        themedAlpha("red", 0.15)
  readonly property color panelWarningBg:       themedAlpha("peach", 0.16)
  readonly property color panelDivider:         themedAlpha("text", 0.10)

  // Launcher / menu — omarchy [menu]: focus + selected-text = accent,
  // selected-background = foreground @ 0.08.
  readonly property color menuBg:      themed("mantle")
  readonly property color menuInk:     themed("text")
  readonly property color menuInkDeep: themed("subtext0")
  readonly property color menuInkMuted: themed("overlay1")
  readonly property color menuSumi:    themed("overlay0")
  readonly property color menuAccent:  accent
  readonly property color menuSeal:    accent
  readonly property color menuIndigo:  themed("sapphire")
  readonly property color menuSealAlt: themed("teal")
  readonly property color menuSep:     themedAlpha("text", 0.08)
  readonly property color menuHairline: themedAlpha("text", 0.08)
  readonly property color menuRowHi:   themedAlpha("text", 0.04)
  readonly property color menuRowSel:  themedAlpha("text", 0.08)
  readonly property color menuDim:     themedAlpha("crust", 0.50)
  readonly property color menuCardBg:  themedAlpha("text", 0.05)
  readonly property color menuControlBg: themedAlpha("text", 0.05)
  readonly property color menuOnAccent: themed("crust")
  readonly property color menuOverlayLight: Qt.rgba(1, 1, 1, 0.92)
  readonly property color menuSuccessWash: themedAlpha("green", 0.28)
  // Accent line + glass body for the launcher card.
  readonly property color menuNeon:    accent
  readonly property color menuNeonAlt: themed("sapphire")
  readonly property color menuGlass:   themedAlpha("mantle", 0.93)
  readonly property int menuRadius: 8
  readonly property int menuRail: 2
  readonly property real menuTitleSpacing: 0.6
  readonly property real menuLabelSpacing: 0.3
  readonly property int menuAnimMs: 140
  readonly property int menuAnimOutMs: 120
  readonly property string menuMono: "JetBrainsMono Nerd Font"
  readonly property string menuSans: "JetBrainsMono Nerd Font"
  readonly property string menuDisplay: "JetBrainsMono Nerd Font"
  readonly property string menuSerif: "serif"

  readonly property int scrollbarWidth: 5
  readonly property color scrollbarThumb: themedAlpha("text", 0.28)
  readonly property color scrollbarThumbHover: themedAlpha("text", 0.48)
  readonly property color scrollbarTrack: themedAlpha("text", 0.06)

  readonly property color crust:      themed("crust")
  readonly property color mantle:     themed("mantle")
  readonly property color base:       themed("base")
  readonly property color surface0:   themed("surface0")
  readonly property color surface1:   themed("surface1")
  readonly property color surface2:   themed("surface2")
  readonly property color overlay0:   themed("overlay0")
  readonly property color overlay1:   themed("overlay1")
  readonly property color overlay2:   themed("overlay2")
  readonly property color rosewater:  themed("rosewater")
  readonly property color flamingo:   themed("flamingo")
  readonly property color pink:       themed("pink")
  readonly property color mauve:      themed("mauve")
  readonly property color sky:        themed("sky")
  readonly property color maroon:     themed("maroon")
  readonly property color teal:       themed("teal")
  readonly property color sapphire:   themed("sapphire")
  readonly property color bgOverlay:  themed("bgOverlay")
  readonly property color bgSelected: themed("bgSelected")
  readonly property color bgBase:     themed("bgBase")
  readonly property color bgSurface:  themed("bgSurface")
  readonly property color bgHover:    themed("bgHover")
  readonly property color bgBorder:   themed("bgBorder")
  readonly property color textPrimary:   themed("textPrimary")
  readonly property color textSecondary: themed("textSecondary")
  readonly property color accentPrimary: accent
  readonly property color accentCyan:    themed("sky")
  readonly property color accentGreen:   themed("green")
  readonly property color accentOrange:  themed("peach")
  readonly property color accentRed:     themed("red")
  readonly property color primary:         accent
  readonly property color onPrimary:       themed("crust")
  readonly property color urgencyLow:      themed("subtext0")
  readonly property color urgencyNormal:   accent
  readonly property color urgencyCritical: themed("red")
  readonly property color batteryGood:     themed("green")
  readonly property color batteryWarning:  themed("peach")
  readonly property color batteryCritical: themed("red")

  readonly property int radius: 8
  readonly property int radiusSm: 6
  readonly property int radiusLg: 14

  readonly property int barHeight: 36
  readonly property int barFontBody: 15
  readonly property int barFontIcon: 23
  readonly property int barFontGlyph: 23
  readonly property int barFontMicVolIcon: 21
  readonly property int barFontCaption: 12
  readonly property int barEdgeMargin: 10
  readonly property int barIconSlot: 30
  readonly property int barChipInset: 4
  readonly property int barWsIcon: 21
  readonly property int barWsSlot: 24

  readonly property string fontFamily: "JetBrainsMono Nerd Font"
  readonly property int fontSize: 16
  readonly property int fontSizeSm: 13
  readonly property int fontSizeTiny: 12
}
