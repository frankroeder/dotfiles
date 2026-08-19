// Pure leftover math for the remix launcher card.
// QML: import "launcher_layout.js" as LauncherGeom
// Node: require("./launcher_layout.js") — no .pragma library so both can load this file.

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
var VIZ_MAX = 420
var VIZ_MIN = 96
var MIN_LIST = 52
var MON_TOOLBAR_H = 26
var MON_CAPTION_H = 16
var MON_SPACING = 8
var DETAIL_HEADER_BLOCK = 48

function roundPx(n) {
  return Math.round(Number(n) || 0)
}

function headerHeight(fontScale) {
  const scale = fontScale == null ? 1.4 : fontScale
  return Math.max(40, roundPx(19 * scale) + 4 + roundPx(11 * scale))
}

function hintHeight(fontScale) {
  const scale = fontScale == null ? 1.4 : fontScale
  return roundPx(18 * scale)
}

function cmdLineHeight(fontScale) {
  const scale = fontScale == null ? 1.4 : fontScale
  return Math.max(1, roundPx(11 * scale))
}

function tileMetrics(bodyHeight, tileCount, colMode) {
  const n = Math.max(0, Number(tileCount) || 0)
  const natural = colMode ? TILE_H_COL : TILE_H_GRID
  const minH = colMode ? TILE_H_COL_MIN : TILE_H_GRID_MIN
  const gap = colMode ? TILE_GAP_COL : TILE_GAP_GRID
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

function monitorsVizHeight(paneH) {
  const pane = Math.max(0, Number(paneH) || 0)
  const leftover = pane - MON_TOOLBAR_H - MON_CAPTION_H - 3 * MON_SPACING
  if (leftover <= 0) return VIZ_MIN
  const forViz = leftover - MIN_LIST
  if (forViz < VIZ_MIN) {
    return Math.max(40, leftover - Math.min(MIN_LIST, Math.floor(leftover / 2)))
  }
  return Math.max(VIZ_MIN, Math.min(VIZ_MAX, forViz))
}

function launcherChrome(opts) {
  opts = opts || {}
  const fontScale = opts.fontScale == null ? 1.4 : opts.fontScale
  const quickMode = !!opts.quickMode
  const headerH = headerHeight(fontScale)
  const hintH = hintHeight(fontScale)
  const searchH = quickMode ? 0 : SEARCH_H
  const searchDiv = quickMode ? 0 : DIVIDER_H
  const cmdH = quickMode ? 0 : cmdLineHeight(fontScale)

  const parts = [headerH, DIVIDER_H]
  if (searchH > 0) parts.push(searchH)
  if (searchDiv > 0) parts.push(searchDiv)
  parts.push(DIVIDER_H)
  if (cmdH > 0) parts.push(cmdH)
  parts.push(hintH)

  const itemCount = parts.length + 1
  const spacing = COL_SPACING * Math.max(0, itemCount - 1)
  let inner = spacing
  for (let i = 0; i < parts.length; i++) inner += parts[i]
  const chrome = inner + 2 * CARD_MARGIN
  return {
    chrome: chrome,
    innerChrome: inner,
    headerH: headerH,
    hintH: hintH,
    searchH: searchH,
    cmdH: cmdH
  }
}

function launcherLayout(opts) {
  opts = opts || {}
  const screenH = Math.max(1, Number(opts.screenH) || 0)
  const tileCount = opts.tileCount == null ? 10 : Number(opts.tileCount) || 0
  const sideActive = !!opts.sideActive
  const quickMode = opts.quickMode == null ? true : !!opts.quickMode
  const hubMode = !!opts.hubMode
  const fontScale = opts.fontScale == null ? 1.4 : opts.fontScale
  const colMode = !!(quickMode && sideActive)

  const bottomGap = Math.max(MIN_BOTTOM_GAP, roundPx(screenH * CARD_BOTTOM_FRAC))
  const cardY = roundPx(screenH * CARD_TOP_FRAC)
  const maxCard = screenH - cardY - bottomGap
  const cardHeight = Math.min(roundPx(screenH * CARD_MAX_FRAC), maxCard)
  const cardBottom = cardY + cardHeight

  const chromeInfo = launcherChrome({ fontScale: fontScale, quickMode: quickMode })
  const chrome = chromeInfo.chrome
  const bodyHeight = Math.max(0, cardHeight - chrome)

  const tiles = tileMetrics(bodyHeight, tileCount, colMode)
  const paneHeight = Math.max(0, bodyHeight - (hubMode ? 0 : DETAIL_HEADER_BLOCK))
  const vizHeight = monitorsVizHeight(paneHeight)
  const vizWouldOverflow = (paneHeight - MON_TOOLBAR_H - MON_CAPTION_H - 3 * MON_SPACING) < VIZ_MAX

  return {
    screenH: screenH,
    cardY: cardY,
    cardHeight: cardHeight,
    cardBottom: cardBottom,
    bottomGap: bottomGap,
    cardMargin: CARD_MARGIN,
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
    vizHeight: vizHeight,
    vizMax: VIZ_MAX,
    vizWouldOverflow: vizWouldOverflow
  }
}

if (typeof module !== "undefined" && module.exports) {
  module.exports = {
    CARD_MARGIN: CARD_MARGIN,
    VIZ_MAX: VIZ_MAX,
    TILE_H_COL: TILE_H_COL,
    launcherLayout: launcherLayout,
    launcherChrome: launcherChrome,
    tileMetrics: tileMetrics,
    monitorsVizHeight: monitorsVizHeight,
    headerHeight: headerHeight,
    hintHeight: hintHeight
  }
}
