// Wallpaper color index: dominant-color bucket, dark/light tone, palette swatches.
// QML: import "wallpaper_colors.js" as WallColors
// Node: require("./wallpaper_colors.js")
//
// Input is the cached `colors.tsv` (see wallpaper_thumbs.colorIndexScript):
//   <wallpaper path>\t#hex,#hex,...   swatches ordered most-used first.

// Same threshold asahi-autotheme uses to pick dark vs light
// (theme/palette.py LIGHT_MODE_THRESHOLD), so the Dark/Light chips predict the
// theme a wallpaper will actually produce rather than guessing at it.
var LIGHT_MODE_THRESHOLD = 0.62
var MONO_CHROMA = 0.035

// Hue ranges in OKLCH plus a fixed dot color, so the filter row reads the same
// whatever palette the shell is currently wearing.
var BUCKETS = [
  { key: "mono",   label: "Mono",   swatch: "#8a8a8a", from: 0,   to: 0 },
  { key: "red",    label: "Red",    swatch: "#e05252", from: 0,   to: 35 },
  { key: "orange", label: "Orange", swatch: "#e0883c", from: 35,  to: 75 },
  { key: "yellow", label: "Yellow", swatch: "#d3bc46", from: 75,  to: 115 },
  { key: "green",  label: "Green",  swatch: "#5aa35a", from: 115, to: 175 },
  { key: "cyan",   label: "Cyan",   swatch: "#46a7b0", from: 175, to: 225 },
  { key: "blue",   label: "Blue",   swatch: "#4f7fd4", from: 225, to: 285 },
  { key: "purple", label: "Purple", swatch: "#9b6bd6", from: 285, to: 325 },
  { key: "pink",   label: "Pink",   swatch: "#d15c9a", from: 325, to: 360 }
]

// Icons are restricted to glyphs the shell already uses elsewhere, so they are
// known to exist in JetBrainsMono Nerd Font rather than rendering as tofu.
var SORTS = [
  { key: "name",  label: "Name",  icon: "󰈔" },
  { key: "color", label: "Color", icon: "󰸉" },
  { key: "tone",  label: "Tone",  icon: "󰃠" }
]

// Mirrors theme/palette.py FLAVORS (`asahi-autotheme --variant`), plainest first.
// wallpaper_colors_test.js fails if the two lists drift apart.
var FLAVORS = [
  { key: "source",  label: "Source",  hint: "closest to the wallpaper" },
  { key: "content", label: "Content", hint: "panels washed in the wallpaper's own hues" },
  { key: "vibrant", label: "Vibrant", hint: "accents at full strength, panels kept neutral" },
  { key: "calm",    label: "Calm",    hint: "soft, desaturated, recessive" },
  { key: "mono",    label: "Mono",    hint: "greyscale" }
]

function flavorHint(key) {
  for (let i = 0; i < FLAVORS.length; i++) if (FLAVORS[i].key === key) return FLAVORS[i].hint
  return ""
}

function _srgbToLinear(v) {
  return v <= 0.04045 ? v / 12.92 : Math.pow((v + 0.055) / 1.055, 2.4)
}

// sRGB hex -> OKLCH, same coefficients as theme/oklab.py.
function oklch(hex) {
  const s = String(hex || "").replace("#", "")
  if (s.length !== 6) return null
  const r = parseInt(s.slice(0, 2), 16)
  const g = parseInt(s.slice(2, 4), 16)
  const b = parseInt(s.slice(4, 6), 16)
  if (isNaN(r) || isNaN(g) || isNaN(b)) return null
  const lr = _srgbToLinear(r / 255)
  const lg = _srgbToLinear(g / 255)
  const lb = _srgbToLinear(b / 255)
  const l = Math.cbrt(0.4122214708 * lr + 0.5363325363 * lg + 0.0514459929 * lb)
  const m = Math.cbrt(0.2119034982 * lr + 0.6806995451 * lg + 0.1073969566 * lb)
  const t = Math.cbrt(0.0883024619 * lr + 0.2817188376 * lg + 0.6299787005 * lb)
  const L = 0.2104542553 * l + 0.7936177850 * m - 0.0040720468 * t
  const A = 1.9779984951 * l - 2.4285922050 * m + 0.4505937099 * t
  const B = 0.0259040371 * l + 0.7827717662 * m - 0.8086757660 * t
  let H = Math.atan2(B, A) * 180 / Math.PI
  if (H < 0) H += 360
  return { L: L, C: Math.sqrt(A * A + B * B), H: H }
}

function bucketOf(chroma, hue) {
  if (!(chroma > MONO_CHROMA)) return "mono"
  const h = ((Number(hue) || 0) % 360 + 360) % 360
  for (let i = 1; i < BUCKETS.length; i++) {
    if (h >= BUCKETS[i].from && h < BUCKETS[i].to) return BUCKETS[i].key
  }
  return "red"
}

// The swatch the theme engine would reach for (theme/palette.py _pick "accent"),
// so the dot beside a wallpaper matches the accent it will generate.
function _accentOf(cols) {
  const chromatic = cols.filter(c => c.C >= 0.04)
  const pool = chromatic.length ? chromatic : cols
  let best = pool[0]
  let bestScore = -Infinity
  for (let i = 0; i < pool.length; i++) {
    const score = pool[i].C * 1.4 + (0.5 - Math.abs(pool[i].L - 0.55)) + 0.02 * pool[i].weight
    if (score > bestScore) { bestScore = score; best = pool[i] }
  }
  return best
}

function entryFor(path, swatches) {
  const hexes = (swatches || []).filter(h => /^#[0-9a-fA-F]{6}$/.test(h)).map(h => h.toLowerCase())
  const cols = []
  for (let i = 0; i < hexes.length; i++) {
    const c = oklch(hexes[i])
    if (!c) continue
    c.hex = hexes[i]
    c.weight = hexes.length - i   // the index is ordered most-used first
    cols.push(c)
  }
  if (cols.length === 0) {
    return { path: path, swatches: [], accent: "", L: 0.5, chroma: 0, hue: 0, bucket: "mono", tone: "dark" }
  }
  let tw = 0
  let wl = 0
  for (let i = 0; i < cols.length; i++) { tw += cols[i].weight; wl += cols[i].L * cols[i].weight }
  const L = wl / tw
  const acc = _accentOf(cols)
  return {
    path: path,
    swatches: hexes,
    accent: acc.hex,
    L: L,
    chroma: acc.C,
    hue: acc.H,
    bucket: bucketOf(acc.C, acc.H),
    tone: L < LIGHT_MODE_THRESHOLD ? "dark" : "light"
  }
}

function parseIndex(text) {
  const out = {}
  const lines = String(text || "").split("\n")
  for (let i = 0; i < lines.length; i++) {
    const tab = lines[i].indexOf("\t")
    if (tab <= 0) continue
    const path = lines[i].slice(0, tab)
    const hexes = lines[i].slice(tab + 1).trim().split(",")
    if (hexes.length) out[path] = entryFor(path, hexes)
  }
  return out
}

function _bucketRank(key) {
  // Mono last: sorting a few hundred wallpapers greys-first buries the rest.
  if (key === "mono") return BUCKETS.length
  for (let i = 1; i < BUCKETS.length; i++) if (BUCKETS[i].key === key) return i
  return BUCKETS.length + 1
}

function _byColor(a, b) {
  const ra = a.entry ? _bucketRank(a.entry.bucket) : BUCKETS.length + 2
  const rb = b.entry ? _bucketRank(b.entry.bucket) : BUCKETS.length + 2
  if (ra !== rb) return ra - rb
  const ha = a.entry ? a.entry.hue : 0
  const hb = b.entry ? b.entry.hue : 0
  if (ha !== hb) return ha - hb
  return a.order - b.order
}

function _byTone(a, b) {
  const la = a.entry ? a.entry.L : 2
  const lb = b.entry ? b.entry.L : 2
  if (la !== lb) return la - lb
  return a.order - b.order
}

// One call for the pickers: filter by name / color bucket / dark-light, then order.
function arrange(paths, index, opts) {
  const o = opts || {}
  const idx = index || {}
  const q = String(o.query || "").toLowerCase().trim()
  const rows = []
  for (let i = 0; i < (paths || []).length; i++) {
    const p = paths[i]
    if (!p) continue
    if (q && (p.split("/").pop() || "").toLowerCase().indexOf(q) < 0) continue
    const entry = idx[p] || null
    if (o.bucket && (!entry || entry.bucket !== o.bucket)) continue
    if (o.tone && (!entry || entry.tone !== o.tone)) continue
    rows.push({ path: p, order: i, entry: entry })
  }
  if (o.sort === "color") rows.sort(_byColor)
  else if (o.sort === "tone") rows.sort(_byTone)
  const out = []
  for (let i = 0; i < rows.length; i++) out.push(rows[i].path)
  return out
}

// Chip badges: how many wallpapers sit in each bucket / tone, honouring the
// other active filters so a chip never promises rows the grid will not show.
function counts(paths, index, opts) {
  const o = opts || {}
  const idx = index || {}
  const q = String(o.query || "").toLowerCase().trim()
  const buckets = {}
  const tones = { dark: 0, light: 0 }
  for (let i = 0; i < (paths || []).length; i++) {
    const p = paths[i]
    if (!p) continue
    if (q && (p.split("/").pop() || "").toLowerCase().indexOf(q) < 0) continue
    const e = idx[p]
    if (!e) continue
    if (!o.tone || e.tone === o.tone) buckets[e.bucket] = (buckets[e.bucket] || 0) + 1
    if (!o.bucket || e.bucket === o.bucket) tones[e.tone] += 1
  }
  return { buckets: buckets, tones: tones }
}

if (typeof module !== "undefined" && module.exports) {
  module.exports = {
    LIGHT_MODE_THRESHOLD: LIGHT_MODE_THRESHOLD,
    MONO_CHROMA: MONO_CHROMA,
    BUCKETS: BUCKETS,
    SORTS: SORTS,
    FLAVORS: FLAVORS,
    flavorHint: flavorHint,
    oklch: oklch,
    bucketOf: bucketOf,
    entryFor: entryFor,
    parseIndex: parseIndex,
    arrange: arrange,
    counts: counts
  }
}
