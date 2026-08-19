// Cached wallpaper preview paths for the Quick / picker grids.
// QML: import "wallpaper_thumbs.js" as WallThumbs
// Node: require("./wallpaper_thumbs.js")

var THUMB_W = 160
var THUMB_H = 96

function cacheDir(home) {
  const h = String(home || "").replace(/\/$/, "")
  return h + "/.cache/asahi/wallpaper-thumbs"
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

function thumbBatchScript(originals, dir, w, h) {
  const lines = ["mkdir -p " + shellQuote(dir)]
  const list = originals || []
  for (let i = 0; i < list.length; i++) {
    const src = list[i]
    if (!src) continue
    const dest = thumbPath(src, dir)
    const cmd = convertCommand(src, dest, w, h)
    lines.push(
      "if [ ! -f " + shellQuote(dest) + " ] || [ " + shellQuote(src) + " -nt " + shellQuote(dest) + " ]; then"
    )
    lines.push("  " + cmd.map(shellQuote).join(" ") + " || true")
    lines.push("fi")
  }
  lines.push("echo THUMBS_DONE")
  return lines.join("\n")
}

if (typeof module !== "undefined" && module.exports) {
  module.exports = {
    THUMB_W: THUMB_W,
    THUMB_H: THUMB_H,
    cacheDir: cacheDir,
    thumbName: thumbName,
    thumbPath: thumbPath,
    previewSource: previewSource,
    convertCommand: convertCommand,
    shellQuote: shellQuote,
    thumbBatchScript: thumbBatchScript
  }
}
