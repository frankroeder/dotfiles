// Models over the asahi-bluetooth-monitor snapshot (services/BtMonitor.qml) for the bar chip and the
// Bluetooth pane: glyphs, battery text, the connection map and BlueZ rows merged with monitor devices.
// Labels are bt_i18n keys (the pane translates); `t` arguments are its tr(key, args).
// Conservative ES2018 (Quickshell's JS engine), node-testable via module.exports (bt_monitor_test.js).
// Glyphs from codepoints so the file survives editors that mangle nerd-font chars.

function glyph(cp) { return String.fromCodePoint(cp) }

var KIND_GLYPHS = {
  mouse: 0xF037D, trackball: 0xF037D, keyboard: 0xF030C, numpad: 0xF03A0, touchpad: 0xF07F8, headset: 0xF02CB,
  speaker: 0xF04C3, presenter: 0xF042F, remote: 0xF0454, gamepad: 0xF0297, joystick: 0xF0297, tablet: 0xF04F6,
  pen: 0xF03EB, phone: 0xF011C, wearable: 0xF0589, camera: 0xF0100, computer: 0xF0379
}
var GLYPH_BT = glyph(0xF00AF)
var GLYPH_BT_CONNECTED = glyph(0xF00B1)
var GLYPH_LAPTOP = glyph(0xF0322)
var GLYPH_USB = glyph(0xF0553)
var GLYPH_DONGLE = glyph(0xF129E)
var GLYPH_WIFI = glyph(0xF05A9)
var GLYPH_EYE = glyph(0xF0208)
var GLYPH_EYE_OFF = glyph(0xF0209)
var GLYPH_COG = glyph(0xF0493)
var GLYPH_CHEVRON_DOWN = glyph(0xF0140)
var GLYPH_CHEVRON_RIGHT = glyph(0xF0142)
var GLYPH_BACK = glyph(0xF004D)
var GLYPH_REFRESH = glyph(0xF0450)

function kindGlyph(kind, connected) {
  var cp = KIND_GLYPHS[kind]
  if (cp) return glyph(cp)
  return connected ? GLYPH_BT_CONNECTED : GLYPH_BT
}

// BlueZ Device1.Icon (input-keyboard, audio-headphones, …) to the monitor's kinds.
function kindOfIcon(icon) {
  var i = String(icon || "")
  if (i.indexOf("headset") >= 0 || i.indexOf("headphone") >= 0) return "headset"
  if (i.indexOf("keyboard") >= 0) return "keyboard"
  if (i.indexOf("mouse") >= 0) return "mouse"
  if (i.indexOf("tablet") >= 0) return "tablet"
  if (i.indexOf("phone") >= 0) return "phone"
  if (i.indexOf("audio") >= 0 || i.indexOf("speaker") >= 0) return "speaker"
  if (i.indexOf("computer") >= 0) return "computer"
  if (i.indexOf("gaming") >= 0) return "gamepad"
  if (i.indexOf("watch") >= 0) return "wearable"
  if (i.indexOf("camera") >= 0) return "camera"
  return "device"
}

// battery-outline / battery-10 … battery-90 / battery, battery-charging, battery-unknown
function batteryGlyph(b) {
  if (!b) return ""
  if (b.charging) return glyph(0xF0084)
  var p = b.percent
  if (p === null || p === undefined) return glyph(0xF0091)
  if (p >= 95) return glyph(0xF0079)
  if (p < 5) return glyph(0xF008E)
  return glyph(0xF007A + Math.min(8, Math.max(0, Math.round(p / 10) - 1)))
}

function batteryText(b) {
  if (!b) return ""
  if (b.percent !== null && b.percent !== undefined) return b.percent + "%"
  var level = String(b.level || "")
  return level && level !== "unknown" ? level.charAt(0).toUpperCase() + level.slice(1) : ""
}

// Same rule as the helper's battery_state (thresholds inclusive, charging is ok): BlueZ-only rows.
function batteryState(b, lowAt, criticalAt) {
  if (!b || b.charging || b.percent === null || b.percent === undefined) return "ok"
  return b.percent <= criticalAt ? "critical" : (b.percent <= lowAt ? "low" : "ok")
}

// "Bolt dongle · slot 2", "USB cable", "Bluetooth"
function connectionLabel(d, t) {
  if (!d) return ""
  return t("conn_" + (d.connection || "bluetooth")) + (d.slot ? " · " + t("slotN", [d.slot]) : "")
}

function hasSettings(d) {
  return !!(d && d.online && !d.denied && (d.dpi || d.smartshift || d.wheel || d.fnswap))
}

// Bar tooltip (upstream's): a title, then "● name  battery" per visible online device (⚡ = charging);
// the access / nothing-found tips instead when that is all there is.
function tooltipText(snap, t) {
  var s = snap || {}
  var lines = [t("bluetooth")]
  if (s.phase === "permission") return lines.concat(t("tipAccess")).join("\n")
  if (s.phase === "none") return lines.concat(t("tipNone")).join("\n")
  var devices = s.devices || []
  for (var i = 0; i < devices.length; i++) {
    var d = devices[i]
    if (d.hidden || !d.online) continue
    var b = d.battery
    var text = b ? batteryText(b) + (b.charging ? " ⚡" : "") : t("noBattery")
    lines.push("● " + (d.name || t("unnamed")) + "  " + text)
  }
  return lines.join("\n")
}

// Slider position (0..1) <-> DPI: an even range snaps to its step, a choice list to its entries.
function dpiFrac(dpi, value) {
  if (!dpi) return 0
  var c = dpi.choices || []
  if (c.length > 1) {
    var best = 0
    for (var i = 1; i < c.length; i++) if (Math.abs(c[i] - value) < Math.abs(c[best] - value)) best = i
    return best / (c.length - 1)
  }
  return dpi.max > dpi.min ? Math.max(0, Math.min(1, (value - dpi.min) / (dpi.max - dpi.min))) : 0
}

function dpiAt(dpi, f) {
  f = Math.max(0, Math.min(1, f))
  var c = dpi.choices || []
  if (c.length) return c[Math.round(f * (c.length - 1))]
  var step = dpi.step || 50
  return Math.min(dpi.max, dpi.min + Math.round(f * (dpi.max - dpi.min) / step) * step)
}

function visible(devices, showHidden) {
  var out = []
  for (var i = 0; i < (devices || []).length; i++) if (showHidden || !devices[i].hidden) out.push(devices[i])
  return out
}

// Connection map: one link per Bluetooth adapter, receiver, then the USB and other-wireless groups, each with
// its devices. Receivers always show (free slots); other links only with a (shown) device. A link carries
// `title` / `sub` keys (+ `subArgs`), `vendor`, and `n` when its title repeats (two Bolt dongles).
function mapLinks(snap, showHidden) {
  var s = snap || {}
  var devices = visible(s.devices, showHidden)
  var adapters = s.adapters || []
  var links = []
  var pick = function(test) { return devices.filter(test) }
  for (var a = 0; a < adapters.length; a++) {
    var ad = adapters[a]
    links.push({ id: ad.id, type: "bluetooth", builtin: ad.builtin, title: ad.builtin ? "btBuiltin" : "btDongle",
      sub: ad.builtin ? "btBuiltinSub" : "btDongleSub", vendor: ad.vendor || "",
      devices: pick(function(d) { return d.connection === "bluetooth" && (d.adapter === ad.id || adapters.length === 1) }) })
  }
  if (!adapters.length) links.push({ id: "bt", type: "bluetooth", builtin: true, title: "btAdapter", sub: "",
    devices: pick(function(d) { return d.connection === "bluetooth" }) })
  var receivers = s.receivers || []
  for (var r = 0; r < receivers.length; r++) {
    var rc = receivers[r]
    links.push({ id: rc.id, type: "receiver", title: "conn_" + rc.family, keep: true, denied: !!rc.denied,
      sub: rc.denied ? "accessNeeded" : "dongleSub", subArgs: [rc.devices.length, rc.max_devices],
      devices: pick(function(d) { return d.receiver === rc.id }) })
  }
  links.push({ id: "usb", type: "usb", title: "conn_usb", sub: "", devices: pick(function(d) { return d.connection === "usb" }) })
  links.push({ id: "wireless", type: "wireless", title: "conn_wireless", sub: "",
    devices: pick(function(d) { return d.connection === "wireless" }) })
  // Number repeated titles (two Bolt receivers, two USB sticks).
  var count = {}, seen = {}
  links.forEach(function(l) { count[l.title] = (count[l.title] || 0) + 1 })
  var out = []
  links.forEach(function(l) {
    if (!l.devices.length && !l.keep) return
    if (count[l.title] > 1) { seen[l.title] = (seen[l.title] || 0) + 1; l.n = seen[l.title] }
    l.online = l.devices.some(function(d) { return d.online })
    out.push(l)
  })
  return out
}

// Pane rows: BlueZ rows (primitives built from Quickshell.Bluetooth) enriched by address with the monitor's
// device (battery, kind, HID++ settings, hidden), then monitor devices BlueZ does not list (USB, receivers).
// Hidden BlueZ rows stay (upstream's Bluetooth page lists them all, tagged); hidden USB / receiver ones drop out.
// Sections (keys): Connected / USB & receivers / Paired / Available (only while `showDiscovered`), 40 rows each.
function paneRows(bluez, snap, showHidden, showDiscovered) {
  var s = snap || {}
  var mon = s.devices || []
  var lowAt = s.low_at || 25, criticalAt = s.critical_at || 10
  var hidden = {}
  ;(s.hidden || []).forEach(function(k) { hidden[k] = true })
  var byAddr = {}, used = {}
  mon.forEach(function(d) { if (d.address) byAddr[String(d.address).toUpperCase()] = d })
  var connected = [], wired = [], paired = [], discovered = []
  ;(bluez || []).forEach(function(b) {
    var addr = String(b.address || "").toUpperCase()
    var m = byAddr[addr] || null
    if (m) used[m.id] = true
    var battery = m && m.battery ? m.battery
      : (b.connected && b.batteryAvailable ? { percent: b.battery, charging: false } : null)
    var row = {
      uid: addr, address: b.address || "", key: "bt:" + addr, id: m ? m.id : "", label: b.label,
      kind: m ? m.kind : kindOfIcon(b.icon), connected: !!b.connected, paired: !!b.paired, wired: false,
      mon: m, battery: battery, state: m ? m.state : batteryState(battery, lowAt, criticalAt),
      hidden: !!hidden["bt:" + addr], pending: b.pending || "", section: ""
    }
    if (row.connected) connected.push(row)
    else if (row.paired) paired.push(row)
    else if (showDiscovered) discovered.push(row)
  })
  mon.forEach(function(m) {
    if (used[m.id] || (m.hidden && !showHidden)) return
    if (m.connection === "bluetooth" && m.source === "bluez") return  // BlueZ rows cover these (or filtered them)
    wired.push({
      uid: m.id, address: "", key: m.key, id: m.id, label: m.name, kind: m.kind, connected: !!m.online, paired: false,
      wired: true, mon: m, battery: m.battery || null, state: m.state || "ok", hidden: !!m.hidden, pending: "", section: ""
    })
  })
  var byLabel = function(a, b) { return a.label.localeCompare(b.label) }
  var rows = []
  var push = function(list, title) {
    list.sort(byLabel)
    for (var i = 0; i < Math.min(list.length, 40); i++) { list[i].section = i === 0 ? title : ""; rows.push(list[i]) }
  }
  push(connected, "btSecConnected")
  push(wired, "btSecWired")
  push(paired, "btSecPaired")
  push(discovered, "btSecAvailable")
  return rows
}

if (typeof module !== "undefined" && module.exports) {
  module.exports = {
    kindGlyph: kindGlyph, kindOfIcon: kindOfIcon, batteryGlyph: batteryGlyph, batteryText: batteryText, batteryState: batteryState,
    connectionLabel: connectionLabel, hasSettings: hasSettings, tooltipText: tooltipText, dpiFrac: dpiFrac, dpiAt: dpiAt, mapLinks: mapLinks, paneRows: paneRows,
    GLYPH_BT: GLYPH_BT, GLYPH_BT_CONNECTED: GLYPH_BT_CONNECTED, GLYPH_LAPTOP: GLYPH_LAPTOP, GLYPH_USB: GLYPH_USB
  }
}
