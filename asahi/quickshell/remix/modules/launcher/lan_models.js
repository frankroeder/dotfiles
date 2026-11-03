// Network pane Devices tab over the asahi-lan snapshot: list rows (type / platform groups, search), row texts, ping / ssh.
// Glyphs and group order follow uBruckhaus/omarchy-wlan-monitor.

var KIND_GLYPHS = {
  router: 0xF0469, computer: 0xF0379, laptop: 0xF0322, phone: 0xF011C, tablet: 0xF04F6, watch: 0xF0897, tv: 0xF07F4,
  speaker: 0xF04C3, printer: 0xF042A, console: 0xF0297, camera: 0xF07AE, light: 0xF0335, nas: 0xF048B, appliance: 0xF0176,
  smarthome: 0xF07D0, unknown: 0xF0625
}
function glyph(kind) { return String.fromCodePoint(KIND_GLYPHS[kind] || KIND_GLYPHS.unknown) }

var GROUP_LABELS = {
  pinned: "Pinned", mobile: "Phones & tablets", computers: "Computers", office: "Printers & storage", media: "Media",
  smarthome: "Smart home", network: "Network", other: "Other"
}
var GROUP_ORDER = ["pinned", "office", "computers", "mobile", "media", "smarthome", "network", "other"]
// Platform view: Apple / Android first, then the same kinds. Pinned still wins over the platform.
var PLATFORM_LABELS = Object.assign({}, GROUP_LABELS, { apple: "Apple", android: "Android", mobile: "Other phones & tablets" })
var PLATFORM_ORDER = ["pinned", "apple", "android", "mobile", "computers", "media", "smarthome", "office", "network", "other"]

function modeLabel(mode) {
  return mode === "platform" ? "By platform" : mode === "type" ? "By type" : "No groups"
}

function matches(d, query) {
  const hay = [d.name, d.auto, d.ip, d.vendor, d.model, d.host, d.label, d.mac].join(" ").toLowerCase()
  return query.toLowerCase().split(/\s+/).every(function(w) { return hay.indexOf(w) !== -1 })
}

// Flat rows for one ListView: group headers ({header: true}) and devices (the device fields + key = mac).
// "type" groups by kind (printers first). "platform" groups by d.platform (no platform: the type group).
// A search is one flat hit list.
function listRows(snap, mode, collapsed, query) {
  const devs = ((snap && snap.devices) || []).filter(function(d) { return !query || matches(d, query) })
  const dev = function(d) { return Object.assign({ key: d.mac, header: false }, d) }
  if (query || (mode !== "type" && mode !== "platform")) return devs.map(dev)
  const platform = mode === "platform"
  const labels = platform ? PLATFORM_LABELS : GROUP_LABELS
  const rows = []
  ;(platform ? PLATFORM_ORDER : GROUP_ORDER).forEach(function(g) {
    const items = devs.filter(function(d) {
      const id = d.pinned ? "pinned" : (platform && d.platform) || d.group || "other"
      return id === g
    })
    if (!items.length) return
    const shut = (collapsed || []).indexOf(g) !== -1
    rows.push({ key: "g:" + g, header: true, id: g, title: labels[g], collapsed: shut, count: items.length,
      online: items.filter(function(d) { return d.state === "online" }).length, fresh: items.some(function(d) { return d.new }) })
    if (!shut) items.forEach(function(d) { rows.push(dev(d)) })
  })
  return rows
}

function ago(minutes) {
  if (minutes < 1) return "just now"
  if (minutes < 60) return minutes + " min ago"
  if (minutes < 48 * 60) return Math.floor(minutes / 60) + " h ago"
  return Math.floor(minutes / 1440) + " d ago"
}

// Right-hand status: online rows show only the address.
function status(d) {
  if (d.state === "online") return d.ip
  if (d.state === "idle") return "idle · " + d.ip
  return "asleep" + (d.seen > 0 ? " · " + ago(d.seen) : "")
}

function stateText(d, trusted) {
  if (d.self) return "This computer."
  if (d.gw) return "The router: the way out to the internet."
  if (d.state === "online") return "Online: answered within the last minute."
  if (d.state === "idle") return "Idle: still known to this computer, quiet lately" + (trusted ? "." : " (never pinged here: may be asleep).")
  return "Asleep: gone from the network" + (d.seen > 0 ? " (last seen " + ago(d.seen) + ")" : "") + "."
}

// Second line: type · model (a printer's "Brother HL-L2350DW") · maker (not for randomised MACs).
function secondary(d) {
  return [d.label, d.model, d.private ? "private address" : d.vendor]
    .filter(function(x, i, a) { return x && a.indexOf(x) === i }).join(" · ")
}

// Detail lines of an open row: [label, value], only the ones with a value.
function details(d) {
  const services = (d.services || []).join(" · ")
  return [["Name", d.custom ? d.auto : ""], ["Maker", d.vendor], ["Model", d.model],
    ["Services", services], ["Host", d.host], ["IP", d.ip], ["MAC", d.mac]].filter(function(p) { return p[1] })
}

// SSH: devices advertising it over mDNS, plus computers / storage (a Raspberry Pi rarely publishes _ssh._tcp).
function canSsh(d) {
  return !!d.ip && !d.self && !d.gw && (d.ssh > 0 || ["computer", "laptop", "nas"].indexOf(d.kind) !== -1)
}
function sshArgs(d) {
  return d.ssh > 0 && d.ssh !== 22 ? ["ssh", "-p", String(d.ssh), d.ip] : ["ssh", d.ip]
}

// `ping -n -q -c N …` summary → {sent, got, min, avg, max} (ms); null when the output has no summary.
function parsePing(text) {
  const n = /(\d+) packets transmitted, (\d+) received/.exec(text || "")
  if (!n) return null
  const r = /= ([\d.]+)\/([\d.]+)\/([\d.]+)\//.exec(text)
  return { sent: +n[1], got: +n[2], min: r ? +r[1] : -1, avg: r ? +r[2] : -1, max: r ? +r[3] : -1 }
}
function pingText(p) {
  if (!p) return "Ping failed"
  if (p.busy) return "Pinging…"
  if (!p.got) return "No answer (" + p.sent + " sent)"
  const ms = function(v) { return v.toFixed(v < 10 ? 1 : 0) }
  return p.got + "/" + p.sent + " answered · " + ms(p.avg) + " ms (" + ms(p.min) + "–" + ms(p.max) + ")"
}

if (typeof module !== "undefined") {
  module.exports = { glyph: glyph, modeLabel: modeLabel, listRows: listRows, ago: ago, status: status, stateText: stateText,
    secondary: secondary, details: details, canSsh: canSsh, sshArgs: sshArgs, parsePing: parsePing, pingText: pingText }
}
