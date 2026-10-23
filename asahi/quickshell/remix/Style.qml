pragma Singleton
import QtQuick
import Quickshell
import "modules/wallpaper" as Wallpaper

// Wallpaper palette → shell chrome. DefaultTheme owns colors.json; generation
// bumps so every binding below re-evaluates after asahi-autotheme.
Singleton {
  readonly property int themeGeneration: Wallpaper.DefaultTheme.generation
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

  readonly property color moduleBg:  themed("surface0")

  readonly property color text:      themed("text")
  readonly property color textMuted: themed("subtext0")
  readonly property color textAlt:   themed("subtext1")

  readonly property color red:       themed("red")
  readonly property color green:     themed("green")
  readonly property color yellow:    themed("yellow")
  readonly property color cyan:      themed("sky")
  readonly property color blue:      themed("blue")
  readonly property color blueAlt:   themed("blue")
  readonly property color magenta:   themed("mauve")
  readonly property color orange:    themed("peach")
  readonly property color lavender:  themed("lavender")

  readonly property color wsActive:         accent
  readonly property color wsActiveAlt:      { const _ = themeGeneration; return Qt.lighter(Wallpaper.DefaultTheme.accent, 1.08) }
  readonly property color wsHoverBg:        themedAlpha("text", 0.10)
  readonly property color wsBadgeActiveText:   themed("crust")
  readonly property color wsOccupiedText:   themed("text")

  // Bar popups (CCU, calendar, SysPanel, media, notification sheet / toasts) float over windows of
  // the same dark tone: one clearly visible outline separates them.
  readonly property color popupBorder:    themedAlpha("overlay1", 0.6)
  readonly property int popupBorderWidth: 2

  readonly property color barBorder:      themedAlpha("text", 0.10)

  readonly property color barStripBg:     themed("mantle")
  readonly property color barStripText:   themed("text")
  readonly property color barStripMuted:  themed("subtext0")
  readonly property color barStripHover:  themedAlpha("text", 0.10)

  readonly property color panelSuccessBg:       themedAlpha("green", 0.16)
  readonly property color panelDangerBg:        themedAlpha("red", 0.15)

  // Launcher / menu — omarchy [menu]: focus + selected-text = accent,
  // selected-background = foreground @ 0.08.
  readonly property color menuBg:      themed("mantle")
  readonly property color menuInk:     themed("text")
  readonly property color menuInkDeep: themed("subtext0")
  readonly property color menuInkMuted: themed("overlay1")
  readonly property color menuAccent:  accent
  readonly property color menuSeal:    accent
  readonly property color menuIndigo:  themed("sapphire")
  readonly property color menuSep:     themedAlpha("text", 0.08)
  readonly property color menuHairline: themedAlpha("text", 0.08)
  readonly property color menuRowHi:   themedAlpha("text", 0.04)
  readonly property color menuRowSel:  themedAlpha("text", 0.08)
  readonly property color menuDim:     themedAlpha("crust", 0.50)
  readonly property color menuCardBg:  themedAlpha("text", 0.05)
  readonly property color menuControlBg: themedAlpha("text", 0.05)
  readonly property color menuOnAccent: themed("crust")
  readonly property color menuOverlayLight: Qt.rgba(1, 1, 1, 0.92)
  // Material 3 roles (caelestia-style panels) mapped onto the wallpaper palette.
  readonly property color m3surface:            themedAlpha("base", 0.96)
  // Bar popups are xdg popups (no layer blur): opaque, or windows bleed through.
  readonly property color m3surfaceSolid:       themed("base")
  readonly property color m3container:          themed("surface0")
  readonly property color m3containerHigh:      themed("surface1")
  readonly property color m3onSurface:          themed("text")
  readonly property color m3onSurfaceVariant:   themed("subtext0")
  readonly property color m3outline:            themed("overlay1")
  readonly property color m3outlineVariant:     themedAlpha("text", 0.12)
  readonly property color m3primary:            accent
  readonly property color m3onPrimary:          themed("crust")
  readonly property color m3primaryContainer:   themedAlpha("accent", 0.22)
  readonly property color m3secondary:          themed("sapphire")
  readonly property color m3secondaryContainer: themedAlpha("sapphire", 0.22)
  readonly property color m3tertiary:           themed("mauve")
  readonly property color m3tertiaryContainer:  themedAlpha("mauve", 0.22)
  readonly property color m3stateHover:         themedAlpha("text", 0.08)
  // Selected row / tile: accent tint + hairline; dark themes need more fill to read.
  readonly property color menuSelFill:   themedAlpha("accent", isDark ? 0.18 : 0.12)
  readonly property color menuSelBorder: themedAlpha("accent", isDark ? 0.45 : 0.35)
  readonly property color m3shadow:             themedAlpha("crust", 0.55)
  readonly property int menuRadius: 12
  readonly property int menuPanelRadius: 28
  readonly property int menuRadiusLg: 16
  readonly property int menuRadiusMd: 12
  readonly property int menuRadiusFull: 999
  readonly property int menuRail: 2
  // Anim: M3 expressive spatial spring + effects curve.
  readonly property int menuAnimMs: 200
  readonly property int menuAnimOutMs: 260
  readonly property int menuSpringMs: 500
  readonly property var menuSpring: [0.38, 1.21, 0.22, 1, 1, 1]
  readonly property var menuEffects: [0.34, 0.8, 0.34, 1, 1, 1]
  // Glyphs and monospace text (file previews): the Nerd Font dnf.sh installs (Ghostty / hyprlock use it too).
  readonly property string menuMono: "Cascadia Mono NF"
  readonly property string menuSans: "Adwaita Sans"
  readonly property string menuDisplay: "Adwaita Sans"

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

  readonly property int radius: 8
  readonly property int radiusSm: 6
  readonly property int radiusLg: 14

  readonly property int barHeight: 40
  readonly property int barFontBody: 14
  readonly property int barFontGlyph: 17
  readonly property int barFontMicVolIcon: 17
  readonly property int barFontCaption: 12
  readonly property int barEdgeMargin: 10
  readonly property int barIconSlot: 22
  readonly property int barChipInset: 4
  readonly property int barWsIcon: 20

  // Bar / popups / OSD text. Noto Sans has tabular digits, so the zero-padded percentages keep their
  // width as they change (Adwaita Sans does not); glyphs fall back to the Nerd Font.
  readonly property string fontFamily: "Noto Sans"
  readonly property int fontSizeTiny: 12
}
