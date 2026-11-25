pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.UPower
import "modules/wallpaper" as Wallpaper

// Wallpaper palette → shell chrome. DefaultTheme owns colors.json; generation
// bumps so every binding below re-evaluates after asahi-autotheme.
Singleton {
  id: root

  // ── Look knobs: every type / radius / duration token below multiplies by its scale. Defaults here; the optional
  // look.json overrides them and the three font families ({"uiScale": 1.1, "fontUi": "Noto Sans"}), live on save.
  property var look: ({})
  readonly property real uiScale: look.uiScale || 1          // text + launcher geometry
  readonly property real radiusScale: look.radiusScale || 1  // corner radii (full-round pills stay round)
  readonly property real motionScale: look.motionScale || 1  // durations: < 1 = snappier
  // OpenType features on every number (merged into fontTabular), e.g. { "zero": 1 } = slashed zeros.
  readonly property var fontFeatures: look.fontFeatures || ({})
  FileView {
    path: Quickshell.env("ASAHI_LOOK") || (Quickshell.env("HOME") + "/.config/asahi/look.json")
    watchChanges: true
    printErrors: false   // no file = defaults
    onFileChanged: reload()
    onLoaded: root.look = JSON.parse(text())
    onLoadFailed: root.look = ({})
  }

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
  // Two line weights: `menuHairline` = rims / outlines of cards and controls; `m3outlineVariant` = divider lines
  // (Menu.MenuDivider). Dark rims and dividers are one device pixel: `rim(Screen.devicePixelRatio)`.
  readonly property color menuHairline: themedAlpha("text", 0.08)
  function rim(dpr) { return isDark ? 1 / dpr : 1 }
  readonly property color menuRowHi:   themedAlpha("text", 0.04)
  readonly property color menuDim:     themedAlpha("crust", 0.50)
  readonly property color menuCardBg:  themedAlpha("text", 0.05)
  readonly property color menuControlBg: themedAlpha("text", 0.05)
  readonly property color menuMeterTrack: themedAlpha("text", 0.12)   // every progress meter (Menu.MenuMeter)
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
  readonly property color m3statePress:         themedAlpha("text", 0.14)   // M3 pressed layer (hover 0.08 + press)
  // Selected row / tile: accent tint + hairline; dark themes need more fill to read.
  readonly property color menuSelFill:   themedAlpha("accent", isDark ? 0.18 : 0.12)
  readonly property color menuSelBorder: themedAlpha("accent", isDark ? 0.45 : 0.35)
  // Text fields: two heights, filled, no idle outline; focus = one accent ring.
  readonly property int fieldHeight: 40     // dialogs: passwords, package search
  readonly property int fieldHeightSm: 30   // inline pane fields: filters, rename, detail edits
  readonly property color focusRing: accent
  readonly property int focusRingWidth: 2
  readonly property color m3shadow:             themedAlpha("crust", 0.55)
  readonly property int menuPanelRadius: Math.round(28 * radiusScale)
  readonly property int menuRadiusLg: Math.round(16 * radiusScale)
  readonly property int menuRadiusMd: Math.round(12 * radiusScale)
  readonly property int menuRadiusSm: Math.round(8 * radiusScale)
  readonly property int menuRadiusXs: Math.round(4 * radiusScale)
  // Bar popups / prompt cards: one inner padding and one gap between blocks; the header is a MenuGlyphTile + title.
  readonly property int popupPad: 14
  readonly property int popupGap: 12
  readonly property int menuRadiusFull: 999
  // Concentric corners: a child `pad` px inside a surface of radius `outer`.
  function inset(outer, pad) { return Math.max(menuRadiusSm, outer - pad) }
  // One device pixel in logical px (a singleton has no screen): `height: Style.hairline(Screen.devicePixelRatio)`.
  function hairline(dpr) { return 1 / Math.max(1, dpr || 1) }
  readonly property int menuPaneRadius: inset(menuPanelRadius, 12)   // pane cards inside the launcher card: 16
  readonly property int menuSelRadius: inset(menuPanelRadius, 16)    // launcher result / rail selection: 12
  readonly property int menuRowRadius: inset(menuRadiusLg, 8)        // list rows inside a pane card: 8
  // Pane metrics: one hero recipe (padding + gap between ring / tile and text) and one nested-card padding.
  // Hardware and Servers keep their tighter hero on purpose (they must fit 767 × 636 without scrolling).
  readonly property int menuHeroPad: 14
  readonly property int menuHeroGap: 16
  readonly property int menuCardPad: 12
  // Anim: M3 expressive spatial spring + effects curve; exits are shorter and accelerate (M3 emphasized
  // accelerate), so a closing surface gets out of the way instead of springing.
  // Reduced motion on a low battery (on battery below 20 %): the spring and the decorative one-shots (bell swing,
  // usage chip roll) drop out, fades shorten. Bound to UPower: no polling.
  readonly property bool reduceMotion: UPower.onBattery && UPower.displayDevice.ready && UPower.displayDevice.percentage < 0.2
  readonly property int menuAnimMs: Math.round((reduceMotion ? 100 : 200) * motionScale)
  readonly property int menuSpringMs: Math.round((reduceMotion ? 0 : 500) * motionScale)
  readonly property int menuSpringFastMs: Math.round((reduceMotion ? 0 : 350) * motionScale)   // switch, chips, badges
  readonly property int menuExitMs: Math.round((reduceMotion ? 100 : 180) * motionScale)
  readonly property int menuAnimOutMs: menuExitMs + 20   // unmap after the exit has run
  readonly property int menuStateMs: Math.round(120 * motionScale)   // hover / press / toggle colour
  readonly property var menuSpring: [0.38, 1.21, 0.22, 1, 1, 1]
  readonly property var menuSpringFast: [0.42, 1.67, 0.21, 0.9, 1, 1]   // M3 expressive fast spatial
  readonly property var menuEffects: [0.34, 0.8, 0.34, 1, 1, 1]
  readonly property var menuExit: [0.3, 0, 0.8, 0.15, 1, 1]
  readonly property var menuEnter: [0.05, 0.7, 0.1, 1, 1, 1]   // M3 emphasized decelerate: a surface growing into place

  // ── Fonts: the one place to change type on every surface. ──
  // UI text: launcher, panes, bar popups, toasts, OSD, cards. Digits that tick add `font.features: Style.fontTabular`.
  readonly property string fontUi: look.fontUi || "Adwaita Sans"
  // Bar strip only (converged look): Noto Sans digits are tabular by default, so % keep their width.
  readonly property string fontBar: "Noto Sans"
  // Glyphs and monospace text (file previews): the Nerd Font dnf.sh installs (Ghostty uses it too).
  readonly property string fontMono: look.fontMono || "Cascadia Mono NF"
  // Machine strings (IPs, MACs, versions, serials, paths, commands): Adwaita Sans's mono sibling, so data reads as
  // data next to UI text. No Nerd glyphs in it: glyphs stay on fontMono.
  readonly property string fontData: look.fontData || "Adwaita Mono"
  // Numbers only: Adwaita Sans's tnum also widens - : . (names read "firefox - bin"), so names / labels never take it.
  // More features (slashed zero; Adwaita Sans also has cv01–cv14 / ss01–ss08) come from the fontFeatures knob.
  readonly property var fontTabular: Object.assign({ "tnum": 1 }, fontFeatures)
  // Dark palettes: Adwaita Sans reads thin on dark, so body 400 → 450 and Medium titles 500 → 550 on its wght axis
  // (font.weight 450 / 550 snap to the 400 / 600 instances: only variableAxes reaches the axis). Light: unchanged.
  // Never on StyledText / RichText: the axis overrides <b> spans (they drop to a synthetic bold on 450).
  readonly property var wghtBody: isDark ? ({ "wght": 450 }) : ({})
  readonly property var wghtTitle: isDark ? ({ "wght": 550 }) : ({})
  // Optical size: Adwaita Sans (Inter) is variable on `opsz` 14–32 and Qt draws every size with the 14 text cut.
  // Big readouts and titles take `font.variableAxes: Style.opsz(<their size expression>)` (never `font.pixelSize`:
  // a binding loop): from ~17 px the display cut (tighter, finer), same family, no new font. Others ignore the axis.
  function opsz(px) { return { "opsz": Math.max(14, Math.min(32, px)) } }
  // Popup type scale (bar popups, calendar, sheet, toasts, OSD): text takes one of these; glyphs keep their own size.
  readonly property int typeCaption: Math.round(10 * uiScale)   // tracked caps, units, counts, chart labels
  readonly property int typeBody: Math.round(11 * uiScale)      // rows, meta
  readonly property int typeLead: Math.round(12 * uiScale)      // body copy, primary row values
  readonly property int typeTitle: Math.round(13 * uiScale)     // popup / card titles, notification summary
  readonly property int typeHeadline: Math.round(16 * uiScale)  // pane / dialog headline
  readonly property int typeDisplay: Math.round(22 * uiScale)   // the one big readout
  readonly property int typeHero: Math.round(28 * uiScale)      // lock / OSD-size numerals
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
  // Menu.MenuGlyph: a glyph's font size = its tile's side × glyphRatio; tall glyphs shrink by the bar's ratio.
  readonly property real glyphRatio: 0.6
  readonly property real glyphTallScale: barFontGlyphTall / barFontGlyph
  readonly property int barFontCaption: 12
  readonly property int barEdgeMargin: 10
  readonly property int barIconSlot: 22
  readonly property int barChipInset: 4
  readonly property int barWsIcon: 20

  // Bar strip text (see fontBar); glyphs fall back to the Nerd Font.
  readonly property string fontFamily: fontBar
  readonly property int fontSizeTiny: 12
}
