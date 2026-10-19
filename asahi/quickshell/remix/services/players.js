// Player choice and naming for services/Players.qml.
// Conservative ES2018 (Quickshell's JS engine), node-testable via module.exports (players_test.js).

// Chromium names its MPRIS player after the browser PID, so only a browser of its own can be told from
// the main one's tabs: asahi-apple-music runs one on a profile directory named *apple-music.
// Chromium rewrites its /proc cmdline into one space-joined string; other programs keep the NULs.
function isAppleMusicCmdline(cmdline) {
  return /(^|[\0 ])--user-data-dir=[^\0 ]*apple-music\/?([\0 ]|$)/.test(String(cmdline || ""))
}

// Pinned, else playing, else the last one seen playing, else the first with a track: Chromium keeps a
// stopped, trackless player around once its tab went quiet.
function pick(list, pinned, recent) {
  if (pinned && list.indexOf(pinned) >= 0) return pinned
  for (var i = 0; i < list.length; i++) if (list[i] && list[i].isPlaying) return list[i]
  if (recent && list.indexOf(recent) >= 0 && recent.trackTitle) return recent
  for (var j = 0; j < list.length; j++) if (list[j] && list[j].trackTitle) return list[j]
  return list[0] || null
}

if (typeof module !== "undefined" && module.exports) {
  module.exports = { isAppleMusicCmdline: isAppleMusicCmdline, pick: pick }
}
