// Screenshot vs recording gallery helpers. Videos are a tab on the shots pane.
// QML: import "gallery.js" as Gallery

function scanCommand(kind, home) {
  const dir = kind === "videos" ? "/Videos" : "/screenshots"
  const glob = kind === "videos" ? "recording-*.mp4" : "screenshot-*.png"
  return "find \"" + String(home || "").replace(/\/$/, "") + dir + "\" -maxdepth 1 -type f -name '" + glob + "' 2>/dev/null | sort -r | head -200"
}

// "…/screenshot-2026-09-14_12-00-00.png" → "2026-09-14_12-00-00"
function label(path) {
  return String(path || "").split("/").pop().replace(/^(screenshot|recording)-/, "").replace(/\.(png|mp4)$/i, "")
}

function mapPaths(text) {
  return String(text || "").trim().split("\n").filter(function (l) { return l.length > 0 })
    .map(function (p) { return { path: p, label: label(p) } })
}

if (typeof module !== "undefined" && module.exports) {
  module.exports = { scanCommand: scanCommand, label: label, mapPaths: mapPaths }
}
