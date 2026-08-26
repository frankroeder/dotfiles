// Adaptive leftover math for the remix launcher card.
// QML: import "launcher_layout.js" as LauncherGeom
// Node: require("./launcher_layout.js") — no .pragma library so both can load this file.
//
// Reference look is 1920×1080 (card 820 / 1080, fontScale 1.4, margin 17).
// Card width tracks screen width so a 14" 1280×800 laptop does not get the
// 1080-wide overlay, and a 27" 1440p / 4K panel does not keep a tiny 820 card.
// Type and chrome scale from the geometric mean of width×height vs that
// reference, clamped so unscaled 4K does not explode point size.

var REF_W = 1920
var REF_H = 1080
var REF_FONT_SCALE = 1.4
var REF_WIDTH_OVERVIEW = 820
var REF_WIDTH_SIDE = 1080
var WIDTH_OVERVIEW_FRAC = REF_WIDTH_OVERVIEW / REF_W
var WIDTH_SIDE_FRAC = REF_WIDTH_SIDE / REF_W
var UI_SCALE_MIN = 0.78
var UI_SCALE_MAX = 1.50
var FONT_SCALE_MIN = 1.05
var FONT_SCALE_MAX = 1.80

var CARD_MARGIN = 17
var COL_SPACING = 12
var CARD_TOP_FRAC = 0.12
var CARD_MAX_FRAC = 0.76
var CARD_BOTTOM_FRAC = 0.04
var MIN_BOTTOM_GAP = 28
var DIVIDER_H = 1
var SEARCH_H = 42
var TILE_H_COL = 56
var TILE_H_GRID = 112
var TILE_H_COL_MIN = 36
var TILE_H_GRID_MIN = 72
var TILE_GAP_COL = 6
var TILE_GAP_GRID = 12
var ROW_H = 44
var ROW_H_TALL = 56
var ICON_SLOT = 30
var ROW_PAD = 14
var SIDE_MIN = 110
// Monitor layout preview owns leftover pane height (list is content-sized).
// Soft cap keeps the viz from dominating ultra-tall screens; Flickable scrolls
// the list when there are more than ~3 rows.
var VIZ_MAX = 450
var VIZ_MIN = 160
var MIN_LIST = 110
var MON_LIST_MAX = 160
var MON_TOOLBAR_H = 26
var MON_CAPTION_H = 16
var MON_SPACING = 8
var DETAIL_HEADER_BLOCK = 48

function roundPx(n) {
  return Math.round(Number(n) || 0)
}

function clamp(n, lo, hi) {
  const x = Number(n)
  if (x !== x) return lo
  return Math.max(lo, Math.min(hi, x))
}

function uiScale(screenW, screenH) {
  const w = Math.max(1, Number(screenW) || REF_W)
  const h = Math.max(1, Number(screenH) || REF_H)
  return clamp(Math.sqrt((w / REF_W) * (h / REF_H)), UI_SCALE_MIN, UI_SCALE_MAX)
}

function fontScaleFor(scale) {
  const s = scale == null ? 1 : Number(scale) || 1
  return Math.round(clamp(REF_FONT_SCALE * s, FONT_SCALE_MIN, FONT_SCALE_MAX) * 100) / 100
}

function cardWidthFor(screenW, sideActive) {
  const w = Math.max(1, Number(screenW) || REF_W)
  const frac = sideActive ? WIDTH_SIDE_FRAC : WIDTH_OVERVIEW_FRAC
  const gap = Math.max(24, roundPx(w * 0.035))
  const maxW = Math.max(320, w - 2 * gap)
  const minW = Math.min(maxW, sideActive ? 700 : 540)
  return clamp(roundPx(w * frac), minW, maxW)
}

function scaledPx(ref, scale, lo, hi) {
  const n = roundPx(ref * (scale == null ? 1 : Number(scale) || 1))
  if (lo == null && hi == null) return n
  return clamp(n, lo == null ? n : lo, hi == null ? n : hi)
}

function headerHeight(fontScale) {
  const scale = fontScale == null ? REF_FONT_SCALE : fontScale
  return Math.max(40, roundPx(19 * scale) + 4 + roundPx(11 * scale))
}

function hintHeight(fontScale) {
  const scale = fontScale == null ? REF_FONT_SCALE : fontScale
  return roundPx(18 * scale)
}

function cmdLineHeight(fontScale) {
  const scale = fontScale == null ? REF_FONT_SCALE : fontScale
  return Math.max(1, roundPx(11 * scale))
}

function tileMetrics(bodyHeight, tileCount, colMode, scale) {
  const s = scale == null ? 1 : Math.max(0.5, Number(scale) || 1)
  const n = Math.max(0, Number(tileCount) || 0)
  const natural = scaledPx(colMode ? TILE_H_COL : TILE_H_GRID, s)
  const minH = Math.max(colMode ? 36 : 64, scaledPx(colMode ? TILE_H_COL_MIN : TILE_H_GRID_MIN, s))
  const gap = scaledPx(colMode ? TILE_GAP_COL : TILE_GAP_GRID, s)
  const cols = colMode ? 1 : 3
  const body = Math.max(0, Number(bodyHeight) || 0)
  if (n <= 0) {
    return {
      tileH: natural,
      tileGap: gap,
      cols: cols,
      rows: 0,
      tileColumnHeight: 0,
      tilesNeedScroll: false,
      tileScrollBudget: 0
    }
  }
  const rows = Math.ceil(n / cols)
  const naturalCol = rows * natural + Math.max(0, rows - 1) * gap
  let tileH = natural
  let tilesNeedScroll = false
  if (naturalCol > body) {
    const shrink = Math.floor((body - Math.max(0, rows - 1) * gap) / rows)
    if (shrink >= minH) {
      tileH = shrink
    } else {
      tileH = minH
      tilesNeedScroll = true
    }
  }
  const tileColumnHeight = rows * tileH + Math.max(0, rows - 1) * gap
  const tileScrollBudget = tilesNeedScroll ? Math.min(tileColumnHeight, body) : tileColumnHeight
  return {
    tileH: tileH,
    tileGap: gap,
    cols: cols,
    rows: rows,
    tileColumnHeight: tileColumnHeight,
    tilesNeedScroll: tilesNeedScroll,
    tileScrollBudget: tileScrollBudget
  }
}

function monitorsVizHeight(paneH, caps) {
  caps = caps || {}
  const vizMax = caps.vizMax == null ? VIZ_MAX : caps.vizMax
  const vizMin = caps.vizMin == null ? VIZ_MIN : caps.vizMin
  const minList = caps.minList == null ? MIN_LIST : caps.minList
  const toolbar = caps.monToolbarH == null ? MON_TOOLBAR_H : caps.monToolbarH
  const caption = caps.monCaptionH == null ? MON_CAPTION_H : caps.monCaptionH
  const spacing = caps.monSpacing == null ? MON_SPACING : caps.monSpacing
  const pane = Math.max(0, Number(paneH) || 0)
  const leftover = pane - toolbar - caption - 3 * spacing
  if (leftover <= 0) return vizMin
  const forViz = leftover - minList
  if (forViz < vizMin) {
    return Math.max(40, leftover - Math.min(minList, Math.floor(leftover / 2)))
  }
  return Math.max(vizMin, Math.min(vizMax, forViz))
}

function launcherChrome(opts) {
  opts = opts || {}
  const fontScale = opts.fontScale == null ? REF_FONT_SCALE : opts.fontScale
  const quickMode = !!opts.quickMode
  const margin = opts.cardMargin == null ? CARD_MARGIN : opts.cardMargin
  const spacing = opts.colSpacing == null ? COL_SPACING : opts.colSpacing
  const headerH = headerHeight(fontScale)
  const hintH = hintHeight(fontScale)
  const searchH = quickMode ? 0 : (opts.searchH == null ? SEARCH_H : opts.searchH)
  const searchDiv = quickMode ? 0 : DIVIDER_H
  const cmdH = quickMode ? 0 : cmdLineHeight(fontScale)

  const parts = [headerH, DIVIDER_H]
  if (searchH > 0) parts.push(searchH)
  if (searchDiv > 0) parts.push(searchDiv)
  parts.push(DIVIDER_H)
  if (cmdH > 0) parts.push(cmdH)
  parts.push(hintH)

  const itemCount = parts.length + 1
  const gap = spacing * Math.max(0, itemCount - 1)
  let inner = gap
  for (let i = 0; i < parts.length; i++) inner += parts[i]
  const chrome = inner + 2 * margin
  return {
    chrome: chrome,
    innerChrome: inner,
    headerH: headerH,
    hintH: hintH,
    searchH: searchH,
    cmdH: cmdH,
    cardMargin: margin,
    colSpacing: spacing
  }
}

function launcherLayout(opts) {
  opts = opts || {}
  const screenH = Math.max(1, Number(opts.screenH) || 0)
  const screenW = Math.max(1, Number(opts.screenW) || REF_W)
  const tileCount = opts.tileCount == null ? 10 : Number(opts.tileCount) || 0
  const sideActive = !!opts.sideActive
  const quickMode = opts.quickMode == null ? true : !!opts.quickMode
  const hubMode = !!opts.hubMode
  const colMode = !!(quickMode && sideActive)

  const scale = uiScale(screenW, screenH)
  const fontScale = opts.fontScale == null ? fontScaleFor(scale) : opts.fontScale
  const cardMargin = scaledPx(CARD_MARGIN, scale, 10, 28)
  const colSpacing = scaledPx(COL_SPACING, scale, 6, 18)
  const searchH = scaledPx(SEARCH_H, scale, 32, 56)
  const detailHeaderBlock = scaledPx(DETAIL_HEADER_BLOCK, scale, 36, 64)
  const minBottom = scaledPx(MIN_BOTTOM_GAP, scale, 20, 48)
  const vizMax = scaledPx(VIZ_MAX, scale, 280, 700)
  const vizMin = scaledPx(VIZ_MIN, scale, 110, 240)
  const minList = scaledPx(MIN_LIST, scale, 80, 160)
  const monListMax = scaledPx(MON_LIST_MAX, scale, 110, 240)
  const monToolbarH = scaledPx(MON_TOOLBAR_H, scale, 22, 36)
  const monCaptionH = scaledPx(MON_CAPTION_H, scale, 12, 24)
  const monSpacing = scaledPx(MON_SPACING, scale, 6, 14)
  const cardWidth = cardWidthFor(screenW, sideActive)

  const bottomGap = Math.max(minBottom, roundPx(screenH * CARD_BOTTOM_FRAC))
  const cardY = roundPx(screenH * CARD_TOP_FRAC)
  const maxCard = screenH - cardY - bottomGap
  const cardHeight = Math.min(roundPx(screenH * CARD_MAX_FRAC), maxCard)
  const cardBottom = cardY + cardHeight

  const chromeInfo = launcherChrome({
    fontScale: fontScale,
    quickMode: quickMode,
    cardMargin: cardMargin,
    colSpacing: colSpacing,
    searchH: searchH
  })
  const chrome = chromeInfo.chrome
  const bodyHeight = Math.max(0, cardHeight - chrome)

  const tiles = tileMetrics(bodyHeight, tileCount, colMode, scale)
  const paneHeight = Math.max(0, bodyHeight - (hubMode ? 0 : detailHeaderBlock))
  const vizCaps = {
    vizMax: vizMax,
    vizMin: vizMin,
    minList: minList,
    monToolbarH: monToolbarH,
    monCaptionH: monCaptionH,
    monSpacing: monSpacing
  }
  const vizHeight = monitorsVizHeight(paneHeight, vizCaps)
  const vizWouldOverflow = (paneHeight - monToolbarH - monCaptionH - 3 * monSpacing) < vizMax

  return {
    screenW: screenW,
    screenH: screenH,
    uiScale: scale,
    fontScale: fontScale,
    cardWidth: cardWidth,
    cardY: cardY,
    cardHeight: cardHeight,
    cardBottom: cardBottom,
    bottomGap: bottomGap,
    cardMargin: cardMargin,
    colSpacing: colSpacing,
    searchH: searchH,
    chrome: chrome,
    bodyHeight: bodyHeight,
    colMode: colMode,
    hubMode: hubMode,
    tileH: tiles.tileH,
    tileGap: tiles.tileGap,
    tileColumnHeight: tiles.tileColumnHeight,
    tilesNeedScroll: tiles.tilesNeedScroll,
    tileScrollBudget: tiles.tileScrollBudget,
    paneHeight: paneHeight,
    panePad: scaledPx(8, scale, 4, 14),
    rowH: scaledPx(ROW_H, scale, 36, 64),
    rowHTall: scaledPx(ROW_H_TALL, scale, 44, 80),
    iconSlot: scaledPx(ICON_SLOT, scale, 22, 42),
    rowPad: scaledPx(ROW_PAD, scale, 8, 22),
    sideMin: scaledPx(SIDE_MIN, scale, 88, 160),
    sidePad: scaledPx(10, scale, 6, 16),
    accMax: scaledPx(180, scale, 120, 260),
    accMaxKeys: scaledPx(340, scale, 220, 480),
    vizHeight: vizHeight,
    vizMax: vizMax,
    vizMin: vizMin,
    minList: minList,
    monListMax: monListMax,
    monToolbarH: monToolbarH,
    monCaptionH: monCaptionH,
    monSpacing: monSpacing,
    vizWouldOverflow: vizWouldOverflow
  }
}

if (typeof module !== "undefined" && module.exports) {
  module.exports = {
    REF_W: REF_W,
    REF_H: REF_H,
    CARD_MARGIN: CARD_MARGIN,
    VIZ_MAX: VIZ_MAX,
    VIZ_MIN: VIZ_MIN,
    MIN_LIST: MIN_LIST,
    MON_LIST_MAX: MON_LIST_MAX,
    TILE_H_COL: TILE_H_COL,
    uiScale: uiScale,
    fontScaleFor: fontScaleFor,
    cardWidthFor: cardWidthFor,
    launcherLayout: launcherLayout,
    launcherChrome: launcherChrome,
    tileMetrics: tileMetrics,
    monitorsVizHeight: monitorsVizHeight,
    headerHeight: headerHeight,
    hintHeight: hintHeight
  }
}
