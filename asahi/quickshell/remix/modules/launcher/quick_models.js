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

function monitorModeString(m) {
  if (!m) return "preferred"
  var w = Number(m.width) || 0
  var h = Number(m.height) || 0
  if (w <= 0 || h <= 0) return "preferred"
  var rr = m.refreshRate ? "@" + Number(m.refreshRate).toFixed(3) : ""
  return w + "x" + h + rr
}

function monitorPositionString(m) {
  if (!m) return "auto"
  return (Number(m.x) || 0) + "x" + (Number(m.y) || 0)
}

// Snapshot geometry of an enabled output so Enable can restore it after
// Disable. Hyprland's disabled JSON often zeros width/height.
function rememberEnabledMonitor(saved, m) {
  var next = saved || {}
  if (!m || !m.name || m.disabled) return next
  var mode = monitorModeString(m)
  if (mode === "preferred") return next
  next = Object.assign({}, next)
  next[m.name] = {
    mode: mode,
    position: monitorPositionString(m),
    scale: m.scale || 1
  }
  return next
}

// Fields for hl.monitor(..., disabled = false). Last-known beats a zeroed
// disabled probe; never omit disabled = false (the off rule would stick).
function enableMonitorFields(m, saved) {
  var rec = (saved && m && saved[m.name]) || {}
  var liveMode = monitorModeString(m)
  var livePos = monitorPositionString(m)
  return {
    mode: rec.mode || (liveMode !== "preferred" ? liveMode : "preferred"),
    position: rec.position || livePos,
    scale: rec.scale || (m && m.scale) || 1
  }
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

// ---------- vpn (jkoestinger/omarchy-vpn NetworkManager model) ----------
// Glyphs from codepoints so the file survives editors that mangle nerd-font chars.
var GLYPH_VPN = String.fromCodePoint(0xF0582)
var GLYPH_LOCK = String.fromCodePoint(0xF033E)
var GLYPH_SHIELD = String.fromCodePoint(0xF0498)
var GLYPH_SHIELD_LOCK = String.fromCodePoint(0xF099D)

function parsePublicIp(raw) {
  var text = String(raw || "").trim()
  if (text === "" || text.length > 45) return ""
  if (/^\d{1,3}(\.\d{1,3}){3}$/.test(text)) {
    var octets = text.split(".")
    for (var i = 0; i < octets.length; i++) {
      if (parseInt(octets[i], 10) > 255) return ""
    }
    return text
  }
  if (/^[0-9a-fA-F:]+$/.test(text) && text.indexOf("::") === text.lastIndexOf("::")) {
    if (text.indexOf(":") !== -1 && !/:::/.test(text)) return text.toLowerCase()
  }
  return ""
}

function splitNmcliLine(line) {
  var text = String(line || "")
  for (var i = 0; i < text.length; i++) {
    if (text[i] === "\\") { i++; continue }
    if (text[i] === ":") return [unescapeNmcli(text.substring(0, i)), unescapeNmcli(text.substring(i + 1))]
  }
  return [unescapeNmcli(text), ""]
}

function unescapeNmcli(value) {
  return String(value || "").replace(/\\(.)/g, "$1")
}

function isVolatileConnection(filename) {
  return String(filename || "").indexOf("/run/") === 0
}

function parseNmcliConnections(raw) {
  var connections = []
  var lines = String(raw || "").split("\n")
  for (var i = 0; i < lines.length; i++) {
    var line = lines[i]
    if (line.trim() === "") continue
    var fields = []
    var rest = line
    for (var f = 0; f < 4; f++) {
      var pair = splitNmcliLine(rest)
      fields.push(pair[0])
      rest = pair[1]
    }
    fields.push(unescapeNmcli(rest))
    if (fields[2] !== "vpn" && fields[2] !== "wireguard") continue
    if (isVolatileConnection(fields[4])) continue
    connections.push({
      name: fields[0],
      uuid: fields[1],
      kind: fields[2] === "wireguard" ? "wireguard" : "vpn",
      active: fields[3] === "yes"
    })
  }
  return connections
}

function parseNmcliVpnDetails(raw) {
  var details = {}
  var current = null
  var lines = String(raw || "").split("\n")

  function flush() {
    if (current && current.uuid !== "") details[current.uuid] = current
    current = null
  }

  for (var i = 0; i < lines.length; i++) {
    var line = lines[i].trim()
    if (line === "") {
      flush()
      continue
    }
    var pair = splitNmcliLine(line)
    if (!current) current = { uuid: "", serviceType: "", hasUsername: false, gateway: "" }
    if (pair[0] === "connection.uuid") current.uuid = pair[1]
    else if (pair[0] === "vpn.service-type") current.serviceType = pair[1]
    else if (pair[0] === "vpn.data") {
      current.hasUsername = hasVpnUsername(pair[1])
      current.gateway = vpnDataValue(pair[1], "gateway") || vpnDataValue(pair[1], "IPSec gateway")
    }
  }
  flush()
  return details
}

function vpnDataValue(data, wanted) {
  var entries = String(data || "").split(",")
  for (var i = 0; i < entries.length; i++) {
    var entry = entries[i]
    var eq = entry.indexOf("=")
    if (eq === -1) continue
    if (entry.substring(0, eq).trim() !== wanted) continue
    return entry.substring(eq + 1).trim()
  }
  return ""
}

function hasVpnUsername(data) {
  var entries = String(data || "").split(",")
  for (var i = 0; i < entries.length; i++) {
    var entry = entries[i].trim()
    var eq = entry.indexOf("=")
    if (eq === -1) continue
    var key = entry.substring(0, eq).trim().toLowerCase()
    if (key !== "username" && key !== "xauth username") continue
    if (entry.substring(eq + 1).trim() !== "") return true
  }
  return false
}

function isOpenVpnService(serviceType) {
  return String(serviceType || "").toLowerCase().indexOf("openvpn") !== -1
}

function isOpenConnectService(serviceType) {
  return String(serviceType || "").toLowerCase().indexOf("openconnect") !== -1
}

function isVpncService(serviceType) {
  return String(serviceType || "").toLowerCase().indexOf("networkmanager.vpnc") !== -1
}

function isWireGuard(profile) {
  return profile && profile.kind === "wireguard"
}

function isOpenConnect(profile) {
  return profile && profile.kind === "openconnect"
}

function isVpnc(profile) {
  return profile && profile.kind === "vpnc"
}

function needsUsername(profile) {
  return !isWireGuard(profile) && !isOpenConnect(profile)
}

function usernameSetting(profile) {
  return isVpnc(profile) ? "Xauth username" : "username"
}

function nmKindLabel(profile) {
  if (isWireGuard(profile)) return "WireGuard"
  if (isOpenConnect(profile)) return "OpenConnect"
  if (isVpnc(profile)) return "VPNC"
  return "OpenVPN"
}

function mergeVpnDetails(connections, details) {
  var usable = []
  for (var i = 0; i < (connections || []).length; i++) {
    var candidate = connections[i]
    if (candidate.kind === "wireguard") {
      usable.push(candidate)
      continue
    }
    var detail = details && details[candidate.uuid]
    if (!detail) continue
    if (isOpenConnectService(detail.serviceType)) candidate.kind = "openconnect"
    else if (isVpncService(detail.serviceType)) candidate.kind = "vpnc"
    else if (!isOpenVpnService(detail.serviceType)) continue
    candidate.hasUsername = detail.hasUsername
    candidate.gateway = detail.gateway
    usable.push(candidate)
  }
  return usable
}

function nmTargets(profiles, authScript) {
  var targets = []
  for (var i = 0; i < (profiles || []).length; i++) {
    var profile = profiles[i]
    var glyph = GLYPH_LOCK
    if (isWireGuard(profile)) glyph = GLYPH_SHIELD
    else if (isOpenConnect(profile) || isVpnc(profile)) glyph = GLYPH_SHIELD_LOCK
    var target = {
      key: "profile:" + profile.uuid,
      label: profile.name,
      detail: profile.active
        ? "Connected"
        : (!needsUsername(profile) || profile.hasUsername
          ? nmKindLabel(profile) + " profile"
          : "No username set"),
      glyph: glyph,
      args: ["connection", "up", "uuid", profile.uuid],
      uuid: profile.uuid,
      kind: profile.kind,
      hasUsername: profile.hasUsername,
      gateway: profile.gateway || "",
      active: !!profile.active
    }
    if (isOpenConnect(profile) && String(authScript || "") !== "") {
      target.command = [String(authScript), profile.uuid]
    }
    targets.push(target)
  }
  return targets
}

function nmSummary(profiles) {
  for (var i = 0; i < (profiles || []).length; i++) {
    if (profiles[i].active) return profiles[i].name
  }
  return (profiles || []).length === 0 ? "No profiles" : "Not connected"
}

function nmDetails(profiles) {
  var rows = []
  for (var i = 0; i < (profiles || []).length; i++) {
    if (!profiles[i].active) continue
    rows.push({ label: "Profile", value: profiles[i].name })
    rows.push({ label: "Type", value: nmKindLabel(profiles[i]) })
    if ((isOpenConnect(profiles[i]) || isVpnc(profiles[i])) && profiles[i].gateway) {
      rows.push({ label: "Gateway", value: profiles[i].gateway })
    }
  }
  if (rows.length > 0) rows.push({ label: "Managed by", value: "NetworkManager" })
  return rows
}

function activeNmProfile(profiles) {
  for (var i = 0; i < (profiles || []).length; i++) {
    if (profiles[i].active) return profiles[i]
  }
  return null
}

function vpnRunnable(profile, tools) {
  var t = tools || {}
  if (profile.kind === "wireguard") return !!t.wireguard
  // OpenConnect rows are driven by the CLI (`sudo openconnect`), not the NM GTK dialog.
  if (profile.kind === "openconnect") return !!t.openconnect
  if (profile.kind === "vpnc") return !!t.vpnc
  return !!t.openvpn
}

function filterRunnableProfiles(profiles, tools) {
  var out = []
  for (var i = 0; i < (profiles || []).length; i++) {
    if (vpnRunnable(profiles[i], tools)) out.push(profiles[i])
  }
  return out
}

function parseExternalTunnels(raw, profileNames) {
  var names = profileNames || {}
  var tunnels = []
  var lines = String(raw || "").split("\n")
  for (var i = 0; i < lines.length; i++) {
    if (!lines[i]) continue
    var p = lines[i].split(":")
    var type = p[1] || ""
    var state = p[2] || ""
    var conn = p.slice(3).join(":")
    if (type !== "tun" && type !== "vpn" && type !== "wireguard") continue
    if (state.indexOf("connected") !== 0) continue
    if (names[conn]) continue
    tunnels.push({ device: p[0] || "", type: type, connection: conn })
  }
  return tunnels
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
    monitorModeString: monitorModeString,
    monitorPositionString: monitorPositionString,
    rememberEnabledMonitor: rememberEnabledMonitor,
    enableMonitorFields: enableMonitorFields,
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
    formatHeaderFreq: formatHeaderFreq,
    parsePublicIp: parsePublicIp,
    splitNmcliLine: splitNmcliLine,
    unescapeNmcli: unescapeNmcli,
    isVolatileConnection: isVolatileConnection,
    parseNmcliConnections: parseNmcliConnections,
    parseNmcliVpnDetails: parseNmcliVpnDetails,
    vpnDataValue: vpnDataValue,
    hasVpnUsername: hasVpnUsername,
    isOpenVpnService: isOpenVpnService,
    isOpenConnectService: isOpenConnectService,
    isVpncService: isVpncService,
    needsUsername: needsUsername,
    usernameSetting: usernameSetting,
    nmKindLabel: nmKindLabel,
    mergeVpnDetails: mergeVpnDetails,
    nmTargets: nmTargets,
    nmSummary: nmSummary,
    nmDetails: nmDetails,
    activeNmProfile: activeNmProfile,
    filterRunnableProfiles: filterRunnableProfiles,
    parseExternalTunnels: parseExternalTunnels,
    GLYPH_VPN: GLYPH_VPN,
    GLYPH_LOCK: GLYPH_LOCK,
    GLYPH_SHIELD: GLYPH_SHIELD,
    GLYPH_SHIELD_LOCK: GLYPH_SHIELD_LOCK
  }
}
