// Cached wallpaper preview paths for the Quick / picker grids.
// QML: import "wallpaper_thumbs.js" as WallThumbs
// Node: require("./wallpaper_thumbs.js")

// 2x the old 160x96: grid cells render ~200-240px wide, so 160px thumbs were
// upscaled blurry. Still tiny to decode (~15 KB JPEG).
var THUMB_W = 320
var THUMB_H = 192

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
    wheelStep: wheelStep,
    clampedContentY: clampedContentY
  }
}
