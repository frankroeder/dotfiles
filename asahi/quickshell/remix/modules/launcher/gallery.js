// Screenshot vs recording gallery helpers. Videos are a tab on the shots pane.
// QML: import "gallery.js" as Gallery

// Tiles show a small JPEG: a screenshot scaled down (decoding the full PNGs made the grid crawl), a recording's frame
// at 0.5 s (its first frame is often the fading selection). Thumb = full file name + ".jpg", so a.png and a.jpg do
// not collide; recordings have their own folder (each scan drops the thumbs whose file left its folder).
function thumbDir(home, video) {
  return String(home || "").replace(/\/$/, "") + "/.cache/asahi/" + (video ? "video-thumbs" : "shot-thumbs")
}
function thumbPath(path, home) {
  return thumbDir(home, /\.mp4$/i.test(String(path || ""))) + "/" + String(path || "").split("/").pop() + ".jpg"
}

function scanCommand(kind, home) {
  const h = String(home || "").replace(/\/$/, "")
  const video = kind === "videos"
  const s = h + (video ? "/Videos" : "/screenshots")
  // Recordings by name (newest first); else every image in the folder, whatever tool named it, newest (mtime) first.
  const list = video
    ? "find \"" + s + "\" -maxdepth 1 -type f -name 'recording-*.mp4' 2>/dev/null | sort -r | head -200"
    : "find \"" + s + "\" -maxdepth 1 -type f \\( -iname '*.png' -o -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.webp' \\)" +
      " -printf '%T@ %p\\n' 2>/dev/null | sort -rn | head -200 | cut -d' ' -f2-"
  // $1 = file, $2 = thumb folder. A take still being written has no index yet: an empty thumb (no frame);
  // the growing file stays newer than it, so the next scan tries again.
  const make = video
    ? "ffmpeg -v error -y -ss 0.5 -i \"$1\" -frames:v 1 -vf scale=480:300:force_original_aspect_ratio=increase,crop=480:300" +
      " -q:v 4 \"$2/${1##*/}.jpg\" </dev/null 2>/dev/null || : >\"$2/${1##*/}.jpg\""
    : "magick \"$1\" -thumbnail 480x300^ -gravity center -extent 480x300 -quality 85 \"$2/${1##*/}.jpg\""
  // Before listing: thumb every file that has none or an older one (annotated in place; magick,
  // 4 at a time; benchmarked against vips/ffmpeg), drop thumbs whose file is gone.
  return "d=\"" + thumbDir(h, video) + "\"; mkdir -p \"$d\"; l=$(" + list + "); " +
    "printf '%s\\n' \"$l\" | while IFS= read -r f; do [ -n \"$f\" ] && [ \"$f\" -nt \"$d/${f##*/}.jpg\" ] && printf '%s\\0' \"$f\"; done | " +
    "xargs -0 -r -P4 -I{} sh -c '" + make + "' _ {} \"$d\"; " +
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
