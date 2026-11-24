// Lyrics line lookup for services/Lyrics.qml. ES2018, node-testable (asahi/apple-music/lyrics_test.js).

// Index of the line sung at `s` seconds: the last one starting at or before it (lines sorted by `t`), -1 before
// the first.
function indexAt(lines, s) {
  var lo = 0, hi = (lines ? lines.length : 0) - 1, at = -1
  while (lo <= hi) {
    var mid = (lo + hi) >> 1
    if (lines[mid].t <= s) { at = mid; lo = mid + 1 } else hi = mid - 1
  }
  return at
}

if (typeof module !== "undefined" && module.exports) {
  module.exports = { indexAt: indexAt }
}
