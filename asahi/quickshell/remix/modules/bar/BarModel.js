// Notch + layout helpers adapted from omarchy-mac (quattro). Apple notched panels
// expose rows above the 16:10 area; the bar must be at least that tall on eDP-1.

function isPlainObject(value) {
  return !!value && typeof value === "object" && !Array.isArray(value)
}

// The cutout is exactly the rows the panel carries above its 16:10 area: 3024x1964
// is 1964 - 1890 = 74 physical rows, which is also macOS's 37pt menu bar at 2x. A
// per-panel lookup table used to override this with 64 and left a 10px band of window
// content behind the camera housing at scale 1.333 — the geometry is the measurement.
function notchHeight(screenName, logicalWidth, logicalHeight) {
  if (String(screenName || "").indexOf("eDP") !== 0) return 0

  var width = Number(logicalWidth)
  var height = Number(logicalHeight)
  if (!(width > 0) || !(height > 0)) return 0

  var strip = height - (width * 10) / 16
  if (strip <= 0 || strip > height / 20) return 0
  return Math.ceil(strip)
}

function formatAge(sinceUnix, nowUnix) {
  var since = Number(sinceUnix)
  var now = Number(nowUnix)
  if (!(since > 0) || !(now >= since)) return ""
  var sec = Math.floor(now - since)
  var d = Math.floor(sec / 86400)
  var h = Math.floor((sec % 86400) / 3600)
  var m = Math.floor((sec % 3600) / 60)
  if (d > 0) return d + "d " + h + "h"
  if (h > 0) return h + "h " + m + "m"
  return m + "m"
}

function notchRegionInset(contentWidth, spacerWidth) {
  // sketchybar's `bar notch_width` in QML terms: the cutout is a hole the layout may
  // not use, not a spacer. Returns the distance from either bar edge to the near edge
  // of that hole, so the left cluster owns [0, width - inset] and the right cluster
  // owns [inset, width]. 0 means the whole strip is usable (no notch on this screen).
  var width = Number(contentWidth) || 0
  var spacer = Number(spacerWidth) || 0
  if (!(width > 0) || !(spacer > 0)) return 0
  return Math.ceil((width + spacer) / 2)
}

// Tray icons arrive either as a path or as "name?path=/dir"; both the bar and the panel
// need the file URL, and both want the tooltip with the app's own name trimmed off
// ("Nextcloud: Last sync ..." under a row already titled Nextcloud).
function trayIcon(icon) {
  var raw = String(icon || "")
  var at = raw.indexOf("?path=")
  if (at < 0) return raw
  var name = raw.slice(0, at)
  return "file://" + raw.slice(at + 6) + "/" + name.slice(name.lastIndexOf("/") + 1)
}

function trayDetail(title, tooltipTitle) {
  var name = String(title || "").trim()
  var tip = String(tooltipTitle || "").trim()
  if (name !== "" && tip.indexOf(name) === 0)
    tip = tip.slice(name.length).replace(/^[\s:·-]+/, "")
  var squash = function (s) { return s.replace(/\s+/g, "").toLowerCase() }
  return squash(tip) === squash(name) ? "" : tip
}

function notchSpacerWidth(screenName, logicalWidth) {
  // Reserve horizontal center gap on the built-in panel so widgets don't sit under the camera.
  if (String(screenName || "").indexOf("eDP") !== 0) return 0
  var width = Number(logicalWidth)
  if (!(width > 0)) return 0
  // ~15% of panel width matches the physical cutout band on 14" Pro at 1.5 scale.
  var spacer = Math.round(width * 0.15)
  return Math.max(180, Math.min(spacer, Math.round(width * 0.22)))
}
