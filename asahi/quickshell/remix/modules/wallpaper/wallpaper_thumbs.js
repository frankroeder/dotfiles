// Cached wallpaper preview paths for the Quick / picker grids.
// QML: import "wallpaper_thumbs.js" as WallThumbs
// Node: require("./wallpaper_thumbs.js")

// Centre window of the picker is ~640px wide. 320px thumbs went soft there.
// Cache dir is size-versioned, so this regenerates instead of reusing the old set.
var THUMB_W = 640
var THUMB_H = 360

// Size-versioned subdir so a thumb-size bump regenerates instead of reusing
// stale smaller thumbs (the batch script's freshness check is mtime-only).
function cacheDir(home) {
  const h = String(home || "").replace(/\/$/, "")
  return h + "/.cache/asahi/wallpaper-thumbs/" + THUMB_W + "x" + THUMB_H
}

function thumbName(original) {
  const s = String(original || "")
  let h = 2166136261
  for (let i = 0; i < s.length; i++) {
    h ^= s.charCodeAt(i)
    h = (h * 16777619) | 0
  }
  const tail = s.replace(/[^A-Za-z0-9._-]+/g, "_").slice(-48)
  return (h >>> 0).toString(16) + (tail ? ("_" + tail) : "")
}

function thumbPath(original, dir) {
  const base = String(dir || "").replace(/\/$/, "")
  return base + "/" + thumbName(original) + ".jpg"
}

function previewSource(original, dir, thumbExists) {
  if (!original) return ""
  if (!thumbExists) return ""
  const dest = thumbPath(original, dir)
  if (!dest || dest === original) return ""
  return "file://" + dest
}

function convertCommand(original, dest, w, h) {
  const width = w == null ? THUMB_W : w
  const height = h == null ? THUMB_H : h
  return [
    "/usr/bin/convert",
    original,
    "-thumbnail",
    width + "x" + height + "^",
    "-gravity",
    "center",
    "-extent",
    width + "x" + height,
    "-strip",
    dest
  ]
}

function shellQuote(s) {
  return "'" + String(s).replace(/'/g, "'\\''") + "'"
}

// Picker wheel: mouse notches jump multiple rows; touchpad pixel deltas are
// boosted so a large wallpaper grid is not one-row-per-tick.
var WHEEL_PIXEL_BOOST = 2
var WHEEL_ROW_BOOST = 2.5

function wheelStep(pixelDeltaY, angleDeltaY, cellHeight) {
  const cell = Math.max(1, Number(cellHeight) || 0)
  const pixel = Number(pixelDeltaY) || 0
  const angle = Number(angleDeltaY) || 0
  if (pixel !== 0) return pixel * WHEEL_PIXEL_BOOST
  return (angle / 120) * cell * WHEEL_ROW_BOOST
}

function clampedContentY(currentY, step, contentHeight, viewportHeight) {
  const maxY = Math.max(0, (Number(contentHeight) || 0) - (Number(viewportHeight) || 0))
  const next = (Number(currentY) || 0) - (Number(step) || 0)
  if (next < 0) return 0
  if (next > maxY) return maxY
  return next
}

// Skewed window carousel (Ryoku's image picker): one 16:9 window in the centre,
// neighbours are tall leaning slices that overlap it. Proportions are Ryoku's
// fixed frame (768×432, slice 108×390, gap -30, skew 28), scaled to the host
// width so a few slices stay visible on each side. Not a ListView — one sized
// to its own width collapses to a single tile and hides the neighbours.
var CAROUSEL_EXPANDED_W = 768
var CAROUSEL_EXPANDED_H = 432
var CAROUSEL_SLICE_W = 108
var CAROUSEL_SLICE_H = 390
var CAROUSEL_SLICE_GAP = -30
var CAROUSEL_SKEW = 28
var CAROUSEL_NEARBY = 8

function carouselFrame(viewW) {
  const w = Math.max(0, Math.floor(Number(viewW) || 0))
  if (w <= 0) {
    return { viewW: 0, expandedW: 0, expandedH: 0, sliceW: 0, sliceH: 0, gap: 0, skew: 0, step: 0, height: 0 }
  }
  const expandedW = Math.max(1, Math.min(CAROUSEL_EXPANDED_W, Math.round(w * 0.46)))
  const s = expandedW / CAROUSEL_EXPANDED_W
  const expandedH = Math.max(1, Math.round(CAROUSEL_EXPANDED_H * s))
  const sliceW = Math.max(1, Math.round(CAROUSEL_SLICE_W * s))
  const sliceH = Math.max(1, Math.min(expandedH, Math.round(CAROUSEL_SLICE_H * s)))
  const gap = Math.round(CAROUSEL_SLICE_GAP * s)
  const skew = Math.max(0, Math.min(sliceW - 1, Math.round(CAROUSEL_SKEW * s)))
  const step = sliceW + gap
  return { viewW: w, expandedW: expandedW, expandedH: expandedH, sliceW: sliceW, sliceH: sliceH, gap: gap, skew: skew, step: step, height: expandedH }
}

// Where window `i` sits while `index` is the pick. Right-hand slices start
// after the centre window plus the (negative) gap, so they tuck under it.
function carouselWindow(frame, count, index, i) {
  const f = frame || carouselFrame(0)
  const n = Math.max(0, count | 0)
  const cur = n <= 0 ? -1 : Math.max(0, Math.min(n - 1, index | 0))
  const at = i | 0
  const rel = at - cur
  const previewX = (f.viewW - f.expandedW) / 2
  const sideY = (f.expandedH - f.sliceH) / 2
  const selected = rel === 0 && cur >= 0
  let x = previewX
  let y = sideY
  let w = f.sliceW
  let h = f.sliceH
  if (selected) {
    x = previewX
    y = 0
    w = f.expandedW
    h = f.expandedH
  } else if (rel > 0) {
    x = previewX + f.expandedW + f.gap + (rel - 1) * f.step
  } else {
    x = previewX + rel * f.step
  }
  const nearby = cur >= 0 && at >= 0 && at < n && Math.abs(rel) <= CAROUSEL_NEARBY
  return {
    index: at, rel: rel, selected: selected, nearby: nearby,
    x: x, y: y, w: w, h: h,
    z: selected ? 100 : 50 - Math.min(Math.abs(rel), 40)
  }
}

// Parallelogram hit test. Top edge runs [skew, width], bottom [0, width-skew],
// so the top-left and bottom-right corners are outside the window.
function carouselContains(skew, w, h, x, y) {
  const width = Number(w) || 0
  const height = Number(h) || 0
  const px = Number(x) || 0
  const py = Number(y) || 0
  if (height <= 0 || width <= 0) return false
  if (py < 0 || py > height || px < 0 || px > width) return false
  const sk = Math.max(0, Math.min(width, Number(skew) || 0))
  const t = py / height
  const leftX = sk * (1 - t)
  const rightX = width - sk * t
  return px >= leftX && px <= rightX
}

// Converts run 4-wide (backgrounded, `wait` every 4 files) so a cold cache
// fills in seconds instead of minutes; a warm cache is just N stat checks.
function thumbBatchScript(originals, dir, w, h) {
  const lines = ["mkdir -p " + shellQuote(dir)]
  const list = originals || []
  let inFlight = 0
  for (let i = 0; i < list.length; i++) {
    const src = list[i]
    if (!src) continue
    const dest = thumbPath(src, dir)
    const cmd = convertCommand(src, dest, w, h)
    lines.push(
      "if [ ! -f " + shellQuote(dest) + " ] || [ " + shellQuote(src) + " -nt " + shellQuote(dest) + " ]; then"
    )
    lines.push("  " + cmd.map(shellQuote).join(" ") + " >/dev/null 2>&1 &")
    lines.push("fi")
    inFlight++
    if (inFlight % 4 === 0) lines.push("wait")
  }
  lines.push("wait")
  lines.push("echo THUMBS_DONE")
  return lines.join("\n")
}

// Color index: six dominant colors per wallpaper, read back by
// wallpaper_colors.js for the bucket / tone filters and the palette strip.
// Sampled from the cached thumb (not the original). Histogram is 24x24, so the
// larger thumb does not change the index cost.
var HIST_ARGS = ["-resize", "24x24!", "-colors", "6", "-depth", "8", "-format", "%c", "histogram:info:-"]
var HIST_AWK = '{c=$1; sub(/:$/,"",c); h=""; for(i=1;i<=NF;i++) if (substr($i,1,1)=="#") {h=tolower(substr($i,1,7)); break} if (h!="") print c" "h}'

function colorIndexPath(dir) {
  return String(dir || "").replace(/\/$/, "") + "/colors.tsv"
}

// `%c histogram:` is unordered, so sort by pixel count and keep the hex only.
function histogramCommand(thumb) {
  return '"$IM" ' + shellQuote(thumb) + " " + HIST_ARGS.map(shellQuote).join(" ")
    + " 2>/dev/null | awk " + shellQuote(HIST_AWK) + " | sort -rn | cut -d' ' -f2 | paste -sd, -"
}

function colorIndexScript(originals, dir) {
  const lines = [
    "mkdir -p " + shellQuote(dir),
    'IM=/usr/bin/magick; [ -x "$IM" ] || IM=/usr/bin/convert',
    "IDX=" + shellQuote(colorIndexPath(dir)),
    // A warm cache is one find: rebuild only when some thumb is newer than the index.
    'if [ -f "$IDX" ] && [ -z "$(find ' + shellQuote(dir) + ' -name \'*.jpg\' -newer "$IDX" -print -quit 2>/dev/null)" ]; then',
    "  echo COLORS_DONE",
    "  exit 0",
    "fi",
    ': > "$IDX.tmp"'
  ]
  const list = originals || []
  let inFlight = 0
  for (let i = 0; i < list.length; i++) {
    const src = list[i]
    if (!src) continue
    // One short O_APPEND line per job, so the 4-wide workers can share the file.
    lines.push("[ -f " + shellQuote(thumbPath(src, dir)) + " ] && printf '%s\\t%s\\n' " + shellQuote(src)
      + ' "$(' + histogramCommand(thumbPath(src, dir)) + ')" >> "$IDX.tmp" &')
    inFlight++
    if (inFlight % 4 === 0) lines.push("wait")
  }
  lines.push("wait")
  lines.push('mv "$IDX.tmp" "$IDX"')
  lines.push("echo COLORS_DONE")
  return lines.join("\n")
}

if (typeof module !== "undefined" && module.exports) {
  module.exports = {
    THUMB_W: THUMB_W,
    THUMB_H: THUMB_H,
    WHEEL_PIXEL_BOOST: WHEEL_PIXEL_BOOST,
    WHEEL_ROW_BOOST: WHEEL_ROW_BOOST,
    cacheDir: cacheDir,
    thumbName: thumbName,
    thumbPath: thumbPath,
    previewSource: previewSource,
    convertCommand: convertCommand,
    shellQuote: shellQuote,
    thumbBatchScript: thumbBatchScript,
    colorIndexPath: colorIndexPath,
    colorIndexScript: colorIndexScript,
    histogramCommand: histogramCommand,
    wheelStep: wheelStep,
    clampedContentY: clampedContentY,
    carouselFrame: carouselFrame,
    carouselWindow: carouselWindow,
    carouselContains: carouselContains,
    CAROUSEL_NEARBY: CAROUSEL_NEARBY
  }
}
