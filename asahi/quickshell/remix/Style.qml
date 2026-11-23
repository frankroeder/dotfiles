pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Services.UPower
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

  // Captive-portal / limited-link tint, shared by the bar chip and the Network pane.
  // "" when fine: callers fall back to their own default (`|| Style.blueAlt`).
  function connectivityColor(state) {
    if (state === "portal") return red
    if (state === "limited") return orange
    return ""
  }

  readonly property color accent: themed("accent")
  // The lock screen's vivid accent pair (colors.json lock_accent / lock_accent2): the Touch ID orb.
  readonly property color vivid: themed("lockAccent")
  readonly property color vivid2: themed("lockAccent2")

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
  readonly property color barStripPress:  themedAlpha("text", 0.18)   // a chip under the pointer's press

  readonly property color panelSuccessBg:       themedAlpha("green", 0.16)
  readonly property color panelDangerBg:        themedAlpha("red", 0.15)

  // Launcher / menu — omarchy [menu]: focus + selected-text = accent.
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
  readonly property color menuDim:     themedAlpha("crust", 0.50)
  readonly property color menuCardBg:  themedAlpha("text", 0.05)
  readonly property color menuControlBg: themedAlpha("text", 0.05)
  readonly property color menuOnAccent: themed("crust")
  readonly property color menuOverlayLight: Qt.rgba(1, 1, 1, 0.92)
  // Material 3 roles (caelestia-style panels) mapped onto the wallpaper palette.
  // Light palettes run crust > mantle > base > surface* (crust = ink on accent), so base is a mid grey there:
  // panels take mantle (paper) and cards step down from it, mirroring dark's base → surface0 → surface1.
  readonly property color m3surface:            isDark ? themedAlpha("base", 0.96) : themedAlpha("mantle", 0.96)
  // Bar popups are xdg popups (no layer blur): opaque, or windows bleed through.
  readonly property color m3surfaceSolid:       isDark ? themed("base") : themed("mantle")
  // Light card tint base@0.8: card / panel contrast 1.21 (was 1.20 on the grey panel), subtext0 on cards 7.6:1 (was 6.1).
  readonly property color m3container:          isDark ? themed("surface0") : Qt.tint(themed("mantle"), themedAlpha("base", 0.8))
  readonly property color m3containerHigh:      isDark ? themed("surface1") : themed("base")
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
  readonly property int menuPanelRadius: 28
  readonly property int menuRadiusLg: 16
  readonly property int menuRadiusMd: 12
  readonly property int menuRadiusFull: 999
  // Anim: M3 expressive spatial spring + effects curve; exits are shorter and accelerate (M3 emphasized
  // accelerate), so a closing surface gets out of the way instead of springing.
  // Reduced motion on a low battery (on battery below 20 %): the spring and the decorative one-shots (bell swing,
  // usage chip roll) drop out, fades shorten. Bound to UPower: no polling.
  readonly property bool reduceMotion: UPower.onBattery && UPower.displayDevice.ready && UPower.displayDevice.percentage < 0.2
  readonly property int menuAnimMs: reduceMotion ? 100 : 200
  readonly property int menuSpringMs: reduceMotion ? 0 : 500
  readonly property int menuExitMs: reduceMotion ? 100 : 180
  readonly property int menuAnimOutMs: menuExitMs + 20   // unmap after the exit has run
  readonly property int menuStateMs: 120                 // hover / press / toggle colour
  readonly property var menuSpring: [0.38, 1.21, 0.22, 1, 1, 1]
  readonly property var menuEffects: [0.34, 0.8, 0.34, 1, 1, 1]
  readonly property var menuExit: [0.3, 0, 0.8, 0.15, 1, 1]

  // ── Fonts: the one place to change type on every surface. ──
  // UI text: launcher, panes, bar popups, toasts, OSD, cards. Digits that tick add `font.features: Style.fontTabular`.
  readonly property string fontUi: "Adwaita Sans"
  // Bar strip only (converged look): Noto Sans digits are tabular by default, so % keep their width.
  readonly property string fontBar: "Noto Sans"
  // Glyphs and monospace text (file previews): the Nerd Font dnf.sh installs (Ghostty uses it too).
  readonly property string fontMono: "Cascadia Mono NF"
  // Add "zero": 1 for slashed zeros (terminal look); Adwaita Sans also has cv01–cv14 / ss01–ss08.
  readonly property var fontTabular: ({ "tnum": 1 })
  // Popup type scale (bar popups, calendar, sheet, toasts, OSD): text takes one of these; glyphs keep their own size.
  readonly property int typeCaption: 10   // tracked caps, units, counts, chart labels
  readonly property int typeBody: 11      // rows, meta
  readonly property int typeLead: 12      // body copy, primary row values
  readonly property int typeTitle: 13     // popup / card titles, notification summary
  readonly property int typeDisplay: 22   // the one big readout
  readonly property string menuMono: fontMono
  readonly property string menuSans: fontUi
  readonly property string menuDisplay: fontUi

  readonly property int scrollbarWidth: 5
  readonly property color scrollbarThumb: themedAlpha("text", 0.28)
  readonly property color scrollbarThumbHover: themedAlpha("text", 0.48)
  readonly property color scrollbarTrack: themedAlpha("text", 0.06)

  readonly property color crust:      themed("crust")
  readonly property color mantle:     themed("mantle")
  readonly property color surface1:   themed("surface1")
  readonly property color surface2:   themed("surface2")
  readonly property color overlay1:   themed("overlay1")
  readonly property color pink:       themed("pink")
  readonly property color mauve:      themed("mauve")
  readonly property color sky:        themed("sky")
  readonly property color maroon:     themed("maroon")
  readonly property color teal:       themed("teal")
  readonly property color sapphire:   themed("sapphire")

  readonly property int radius: 8
  readonly property int radiusSm: 6

  readonly property int barHeight: 40
  readonly property int barFontBody: 14
  // Nerd glyphs differ in shape: square ones (bell, cup, CPU) need a larger size than tall ones (mic, battery,
  // Bluetooth, VPN shield, thermometer) to read the same height (~14 px of ink each).
  readonly property int barFontGlyph: 24
  readonly property int barFontGlyphTall: 20
  readonly property int barFontCaption: 12
  readonly property int barEdgeMargin: 10
  readonly property int barIconSlot: 22
  readonly property int barChipInset: 4
  readonly property int barWsIcon: 20

  // Bar strip text (see fontBar); glyphs fall back to the Nerd Font.
  readonly property string fontFamily: fontBar
  readonly property int fontSizeTiny: 12
}
