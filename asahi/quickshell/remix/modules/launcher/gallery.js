// Screenshot vs recording gallery helpers. Videos are a tab on the shots pane.
// QML: import "gallery.js" as Gallery

// Screenshot tiles show a small JPEG (decoding the full PNGs made the grid crawl).
// Thumb = full file name + ".jpg", so a.png and a.jpg do not collide.
function thumbDir(home) {
  return String(home || "").replace(/\/$/, "") + "/.cache/asahi/shot-thumbs"
}
function thumbPath(path, home) {
  return thumbDir(home) + "/" + String(path || "").split("/").pop() + ".jpg"
}

function scanCommand(kind, home) {
  const h = String(home || "").replace(/\/$/, "")
  const dir = kind === "videos" ? "/Videos" : "/screenshots"
  if (kind === "videos")
    return "find \"" + h + dir + "\" -maxdepth 1 -type f -name 'recording-*.mp4' 2>/dev/null | sort -r | head -200"
  // Every image in the folder, whatever tool named it, newest (mtime) first.
  const s = h + dir
  const list = "find \"" + s + "\" -maxdepth 1 -type f \\( -iname '*.png' -o -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.webp' \\)" +
    " -printf '%T@ %p\\n' 2>/dev/null | sort -rn | head -200 | cut -d' ' -f2-"
  // Before listing: thumb every image that has none (magick, 4 at a time; benchmarked
  // against vips/ffmpeg), drop thumbs whose image is gone.
  return "d=\"" + thumbDir(h) + "\"; mkdir -p \"$d\"; l=$(" + list + "); " +
    "printf '%s\\n' \"$l\" | while IFS= read -r f; do [ -n \"$f\" ] && [ ! -f \"$d/${f##*/}.jpg\" ] && printf '%s\\0' \"$f\"; done | " +
    "xargs -0 -r -P4 -I{} sh -c 'magick \"$1\" -thumbnail 480x300^ -gravity center -extent 480x300 -quality 85 \"$2/${1##*/}.jpg\"' _ {} \"$d\"; " +
    "for t in \"$d\"/*.jpg; do [ -e \"$t\" ] || continue; " +
    "b=${t##*/}; [ -e \"" + s + "/${b%.jpg}\" ] || rm -f \"$t\"; done; " +
    "printf '%s\\n' \"$l\""
}

// "…/screenshot-2026-09-14_12-00-00.png" → "2026-09-14_12-00-00"
function label(path) {
  return String(path || "").split("/").pop().replace(/^(screenshot|recording)[-_]/, "").replace(/\.(png|jpe?g|webp|mp4)$/i, "")
}

function mapPaths(text) {
  return String(text || "").trim().split("\n").filter(function (l) { return l.length > 0 })
    .map(function (p) { return { path: p, label: label(p) } })
}

if (typeof module !== "undefined" && module.exports) {
  module.exports = { scanCommand: scanCommand, label: label, mapPaths: mapPaths, thumbDir: thumbDir, thumbPath: thumbPath }
}
