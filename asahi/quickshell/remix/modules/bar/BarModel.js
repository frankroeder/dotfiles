// Notch + layout helpers adapted from omarchy-mac (quattro). Apple notched panels
// expose rows above the 16:10 area; the bar must be at least that tall on eDP-1.

function isPlainObject(value) {
  return !!value && typeof value === "object" && !Array.isArray(value)
}

var measuredNotchPanels = [
  { width: 3024, height: 1964, cutoutRows: 64 },
  { width: 3456, height: 2234, cutoutRows: 64 },
  { width: 2560, height: 1664, cutoutRows: 56 },
  { width: 2880, height: 1864, cutoutRows: 56 }
]

function measuredCutoutRows(physicalWidth, physicalHeight) {
  for (var i = 0; i < measuredNotchPanels.length; i++) {
    var panel = measuredNotchPanels[i]
    if (Math.abs(physicalWidth - panel.width) <= 4 && Math.abs(physicalHeight - panel.height) <= 4)
      return panel.cutoutRows
  }
  return 0
}

function notchHeight(screenName, logicalWidth, logicalHeight, devicePixelRatio) {
  if (String(screenName || "").indexOf("eDP") !== 0) return 0

  var width = Number(logicalWidth)
  var height = Number(logicalHeight)
  if (!(width > 0) || !(height > 0)) return 0

  var strip = height - (width * 10) / 16
  if (strip <= 0 || strip > height / 20) return 0

  var scale = Number(devicePixelRatio)
  if (scale > 0) {
    var cutout = measuredCutoutRows(Math.round(width * scale), Math.round(height * scale))
    if (cutout > 0) return Math.ceil(cutout / scale)
  }
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

function notchSpacerWidth(screenName, logicalWidth, logicalHeight, devicePixelRatio) {
  // Reserve horizontal center gap on the built-in panel so widgets don't sit under the camera.
  if (String(screenName || "").indexOf("eDP") !== 0) return 0
  var width = Number(logicalWidth)
  if (!(width > 0)) return 0
  // ~15% of panel width matches the physical cutout band on 14" Pro at 1.5 scale.
  var spacer = Math.round(width * 0.15)
  return Math.max(180, Math.min(spacer, Math.round(width * 0.22)))
}
