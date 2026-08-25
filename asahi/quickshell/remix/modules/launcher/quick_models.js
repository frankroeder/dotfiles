// Pure helpers for the launcher quick panels, adapted from omarchy's
// bluetooth/audio/monitor/network panel models (basecamp/omarchy, quattro).
// Conservative ES2018 — quickshell's QML JS engine must run this — and
// node-testable via module.exports (see quick_models_test.js).

// ---------- audio (omarchy.audio) ----------

function nodeProps(node) {
  return node && node.ready && node.properties ? node.properties : {}
}

function friendlyDeviceLabel(text) {
  var label = String(text || "").trim()
  label = label.replace(/^sof-soundwire\s+/i, "")
  label = label.replace(/^built-?in audio\s+/i, "")
  label = label.replace(/\s+Output$/i, "")
  label = label.replace(/\s+Input$/i, "")
  label = label.replace(/\bMicrophones\b/g, "Microphone")
  return label
}

function nodeLabel(node) {
  if (!node) return "Unknown"
  var p = nodeProps(node)
  var nickname = friendlyDeviceLabel(node.nickname || node.nick || p["node.nick"] || p["device.profile.description"] || "")
  if (nickname) return nickname
  return friendlyDeviceLabel(node.description || p["node.description"] || node.name || "Unknown")
}

function isHeadphones(node) {
  if (!node) return false
  var p = nodeProps(node)
  var blob = String([
    node.name, node.description, node.nickname,
    p["device.icon-name"] || "",
    p["device.product.name"] || "",
    p["node.description"] || "",
    p["node.nick"] || ""
  ].join(" ")).toLowerCase()
  return blob.indexOf("headphone") !== -1
    || blob.indexOf("headset") !== -1
    || blob.indexOf("earbud") !== -1
    || blob.indexOf("earphone") !== -1
    || blob.indexOf("airpod") !== -1
}

function sinkGlyph(node) {
  if (!node) return "󰓃"
  if (isHeadphones(node)) return "󰋋"
  var p = nodeProps(node)
  var blob = String([
    node.name, node.description, node.nickname,
    p["device.icon-name"] || "",
    p["device.product.name"] || ""
  ].join(" ")).toLowerCase()
  if (blob.indexOf("bluez") !== -1 || blob.indexOf("bluetooth") !== -1) return "󰂯"
  if (blob.indexOf("hdmi") !== -1 || blob.indexOf("display") !== -1) return "󰍹"
  return "󰓃"
}

function sourceGlyph(node) {
  if (!node) return "󰍬"
  var p = nodeProps(node)
  var blob = String([
    node.name, node.description, node.nickname,
    p["device.icon-name"] || ""
  ].join(" ")).toLowerCase()
  if (blob.indexOf("headset") !== -1) return "󰋋"
  if (blob.indexOf("bluez") !== -1 || blob.indexOf("bluetooth") !== -1) return "󰂯"
  if (blob.indexOf("webcam") !== -1 || blob.indexOf("camera") !== -1) return "󰄀"
  return "󰍬"
}

function rawStreamLabel(node) {
  if (!node) return ""
  var p = nodeProps(node)
  return p["application.name"]
    || node.description
    || p["media.name"]
    || p["node.name"]
    || node.name
    || ""
}

// A playback stream publishes isSink; capture streams publish as sources.
// Avoids reading node.properties for classification (invalid until bound).
function isPlaybackStream(node) {
  if (!node || !node.isStream) return false
  if (node.isSink === true) return true
  var mediaClass = String(node.type || "")
  return mediaClass.indexOf("Stream/Output/Audio") !== -1
    || mediaClass.indexOf("AudioOutStream") !== -1
    || mediaClass.indexOf("Output") !== -1
}

function isAudioSource(node) {
  if (!node) return false
  if (node.audio) return true
  var mediaClass = String(node.type || "")
  return mediaClass.indexOf("Audio/Source") !== -1
    || mediaClass.indexOf("AudioSource") !== -1
    || mediaClass.indexOf("Source") !== -1
}

// ---------- monitors (omarchy.monitor) ----------

function clampBrightness(value) {
  var n = Number(value)
  if (!isFinite(n)) return 1
  return Math.max(1, Math.min(100, Math.round(n)))
}

function normalizeScale(scale) {
  var n = parseFloat(String(scale || ""))
  if (!isFinite(n)) return ""
  return String(Math.round(n * 100) / 100)
}

function gcd(a, b) {
  while (b) {
    var remainder = a % b
    a = b
    b = remainder
  }
  return a
}

// Hyprland only accepts scales whose logical size divides the mode evenly;
// snap a requested scale to the nearest one it will take (omarchy's trick:
// work in 1/120 units like wlroots).
function cleanScale(scale, width, height) {
  var requested = Number(scale)
  var modeWidth = Number(width)
  var modeHeight = Number(height)
  if (!isFinite(requested) || !isFinite(modeWidth) || !isFinite(modeHeight)
      || requested <= 0 || modeWidth <= 0 || modeHeight <= 0) return ""

  var divisor = gcd(Math.round(modeWidth * 120), Math.round(modeHeight * 120))
  var scaleUnits = Math.round(requested * 120)
  if (scaleUnits > divisor) scaleUnits = divisor
  while (divisor % scaleUnits !== 0) scaleUnits++
  return normalizeScale(scaleUnits / 120)
}

function matchingScaleIndex(scales, currentScale, width, height) {
  var current = Number(currentScale)
  if (!Array.isArray(scales) || !isFinite(current)) return -1

  var bestIndex = -1
  var bestDistance = Infinity
  var normalizedCurrent = normalizeScale(current)
  for (var i = 0; i < scales.length; i++) {
    if (cleanScale(scales[i], width, height) !== normalizedCurrent) continue
    var distance = Math.abs(Number(scales[i]) - current)
    if (distance < bestDistance) {
      bestIndex = i
      bestDistance = distance
    }
  }
  return bestIndex
}

// Dedup presets that collapse onto the same effective scale for this mode.
function availableScales(scales, width, height) {
  if (!Array.isArray(scales) || Number(width) <= 0 || Number(height) <= 0) return scales || []

  var byEffectiveScale = {}
  for (var i = 0; i < scales.length; i++) {
    var requested = Number(scales[i])
    var effective = Number(cleanScale(requested, width, height))
    if (!isFinite(requested) || !isFinite(effective)) continue

    var key = normalizeScale(effective)
    var existing = byEffectiveScale[key]
    if (!existing || Math.abs(requested - effective) < existing.distance) {
      byEffectiveScale[key] = {
        value: String(scales[i]),
        index: i,
        distance: Math.abs(requested - effective)
      }
    }
  }

  return Object.keys(byEffectiveScale)
    .map(function(key) { return byEffectiveScale[key] })
    .sort(function(a, b) { return a.index - b.index })
    .map(function(candidate) { return candidate.value })
}

// ---------- modes (resolution / refresh, hyprctl availableModes) ----------

function parseModeString(mode) {
  var m = String(mode || "").match(/^(\d+)x(\d+)@([\d.]+)/)
  if (!m) return null
  return { width: parseInt(m[1], 10), height: parseInt(m[2], 10), refresh: parseFloat(m[3]) }
}

// Unique resolutions in Hyprland's preference order, each with its refresh
// rates sorted high-to-low and `best` = the highest one.
function resolutionOptions(modes, limit) {
  var byRes = {}
  var order = []
  var list = modes || []
  for (var i = 0; i < list.length; i++) {
    var p = parseModeString(list[i])
    if (!p) continue
    var key = p.width + "x" + p.height
    if (!byRes[key]) {
      byRes[key] = { width: p.width, height: p.height, refreshes: [] }
      order.push(key)
    }
    if (byRes[key].refreshes.indexOf(p.refresh) === -1) byRes[key].refreshes.push(p.refresh)
  }
  var out = []
  var max = limit == null ? 6 : limit
  for (var j = 0; j < order.length && out.length < max; j++) {
    var r = byRes[order[j]]
    r.refreshes.sort(function(a, b) { return b - a })
    r.best = r.refreshes[0]
    r.label = r.width + "\u00d7" + r.height
    out.push(r)
  }
  return out
}

function refreshOptions(modes, width, height, limit) {
  var w = Number(width)
  var h = Number(height)
  var list = modes || []
  var out = []
  for (var i = 0; i < list.length; i++) {
    var p = parseModeString(list[i])
    if (!p || p.width !== w || p.height !== h) continue
    if (out.indexOf(p.refresh) === -1) out.push(p.refresh)
  }
  out.sort(function(a, b) { return b - a })
  var max = limit == null ? 6 : limit
  return out.slice(0, max)
}

function formatRefresh(hz) {
  var n = Number(hz)
  if (!isFinite(n)) return ""
  var rounded = Math.round(n * 100) / 100
  var s = rounded % 1 === 0 ? String(rounded) : String(rounded).replace(/0+$/, "").replace(/\.$/, "")
  return s + " Hz"
}

// hyprctl reports refreshRate with extra precision (59.951) vs the mode
// string's 2 decimals (59.95) — compare with tolerance.
function sameRefresh(a, b) {
  return isFinite(Number(a)) && isFinite(Number(b)) && Math.abs(Number(a) - Number(b)) < 0.05
}

function brightnessName(percent) {
  var p = Math.round(percent)
  if (p >= 95) return "Sun blast"
  if (p >= 80) return "Solar flare"
  if (p >= 65) return "Golden hour"
  if (p >= 45) return "Even day"
  if (p >= 30) return "Soft glow"
  if (p >= 20) return "Lamp light"
  if (p >= 10) return "Candlelit"
  return "Night owl"
}

// ---------- bluetooth (omarchy panels/bluetooth) ----------

function cloneMap(map) {
  var next = {}
  for (var key in map || {}) next[key] = map[key]
  return next
}

function pendingAction(actions, address) {
  return address && actions && actions[address] ? actions[address] : ""
}

function withPendingAction(actions, address, action) {
  var next = cloneMap(actions)
  if (!address) return next
  if (action) next[address] = action
  else delete next[address]
  return next
}

// Drop pending entries the live device list has caught up with. Returns null
// when nothing changed so callers can skip the property write.
function settledPendingActions(actions, devices) {
  var next = cloneMap(actions)
  var changed = false
  for (var address in next) {
    var action = next[address]
    var found = null
    for (var i = 0; i < (devices || []).length; i++) {
      var d = devices[i]
      if (d && d.address === address) { found = d; break }
    }
    var remembered = found && (found.paired || found.bonded || found.trusted)
    if ((action === "connecting" && found && found.connected)
        || (action === "disconnecting" && found && !found.connected)
        || (action === "forgetting" && (!found || !remembered))) {
      delete next[address]
      changed = true
    }
  }
  return changed ? next : null
}

// ---------- network (omarchy panels/network) ----------

function formatHeaderFreq(mhz) {
  var v = parseFloat(mhz)
  if (!v) return ""
  if (v >= 2400 && v < 2500) return "2.4 GHz"
  if (v >= 4900 && v < 5925) return "5 GHz"
  if (v >= 5925 && v < 7125) return "6 GHz"
  if (v >= 57000 && v < 71000) return "60 GHz"
  var ghz = v / 1000
  return ghz.toFixed(ghz % 1 === 0 ? 0 : 1) + " GHz"
}

if (typeof module !== "undefined") {
  module.exports = {
    nodeProps: nodeProps,
    friendlyDeviceLabel: friendlyDeviceLabel,
    nodeLabel: nodeLabel,
    isHeadphones: isHeadphones,
    sinkGlyph: sinkGlyph,
    sourceGlyph: sourceGlyph,
    rawStreamLabel: rawStreamLabel,
    isPlaybackStream: isPlaybackStream,
    isAudioSource: isAudioSource,
    clampBrightness: clampBrightness,
    normalizeScale: normalizeScale,
    cleanScale: cleanScale,
    matchingScaleIndex: matchingScaleIndex,
    availableScales: availableScales,
    parseModeString: parseModeString,
    resolutionOptions: resolutionOptions,
    refreshOptions: refreshOptions,
    formatRefresh: formatRefresh,
    sameRefresh: sameRefresh,
    brightnessName: brightnessName,
    cloneMap: cloneMap,
    pendingAction: pendingAction,
    withPendingAction: withPendingAction,
    settledPendingActions: settledPendingActions,
    formatHeaderFreq: formatHeaderFreq
  }
}
