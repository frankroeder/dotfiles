// Pure helpers for the Network pane's detail sheet (panes/NetDetailSheet.qml): nmcli -t output, the IPv4 form and its
// `nmcli connection modify` arguments. Conservative ES2018 (Quickshell's JS engine), node-tested (net_detail_test.js).

// `nmcli -e no -t -f … connection show uuid <u>` → { "ipv4.method": "auto", "IP4.DNS": ["192.168.1.1"], … }.
// Keys hold no ':', so the first one splits; indexed runtime keys (IP4.ADDRESS[2]) collect into a list.
function parseShow(text) {
  var out = {}
  var lines = String(text || "").split("\n")
  for (var i = 0; i < lines.length; i++) {
    var cut = lines[i].indexOf(":")
    if (cut < 0) continue
    var key = lines[i].slice(0, cut)
    var value = lines[i].slice(cut + 1)
    var m = key.match(/^(.+)\[\d+\]$/)
    if (m) (out[m[1]] = out[m[1]] || []).push(value)
    else out[key] = value
  }
  return out
}

// `nmcli -t -f NAME,UUID,TYPE,TIMESTAMP,ACTIVE connection show`, rows already split (QuickModels.nmcliFields):
// the Wi-Fi profiles, most recently used first.
function savedProfiles(rows) {
  var out = []
  for (var i = 0; i < rows.length; i++) {
    var r = rows[i]
    if (r[2] !== "802-11-wireless") continue
    out.push({ name: r[0], uuid: r[1], ts: Number(r[3]) || 0, active: r[4] === "yes" })
  }
  return out.sort(function(a, b) { return b.ts - a.ts })
}

// Saved profiles the scan list does not show (out of range, or the scan was refused): list rows after the scan's.
// Keyed by name like the scan rows (the list's ScriptModel diffs by `ssid`).
function savedRows(profiles, shown) {
  var out = []
  var seen = {}
  for (var i = 0; i < shown.length; i++) seen[shown[i]] = true
  for (var j = 0; j < profiles.length; j++) {
    var p = profiles[j]
    if (p.active || seen[p.name]) continue
    seen[p.name] = true
    out.push({ ssid: p.name, uuid: p.uuid, ts: p.ts, saved: true, known: true, signal: 0, sec: "",
      section: out.length === 0 ? "Other saved networks" : "" })
  }
  return out
}

// The access point for an SSID from `nmcli -t -f IN-USE,BSSID,SSID,CHAN,FREQ,SIGNAL,SECURITY dev wifi list`
// (rows split): the one in use, else the strongest. null when it is not in the list.
function pickAp(rows, ssid) {
  var best = null
  for (var i = 0; i < rows.length; i++) {
    var r = rows[i]
    if (r.length < 7 || r[2] !== ssid) continue
    var ap = { inUse: r[0] === "*", bssid: r[1], chan: r[3], freq: parseInt(r[4], 10) || 0,
      signal: parseInt(r[5], 10) || 0, sec: r[6] }
    if (!best || (ap.inUse && !best.inUse) || (ap.inUse === best.inUse && ap.signal > best.signal)) best = ap
  }
  return best
}

// Profile key-mgmt in words (no security section = open).
function keyMgmtLabel(km) {
  var k = String(km || "")
  if (k === "sae") return "WPA3"
  if (k === "wpa-psk") return "WPA2"
  if (k === "owe") return "Enhanced Open"
  if (k === "none") return "WEP"
  if (k.indexOf("eap") !== -1 || k === "ieee8021x") return "Enterprise"
  return "Open"
}

// wifi.cloned-mac-address in words. Empty = NetworkManager's default (Fedora's 22-wifi-mac-addr.conf: stable-ssid).
function macPolicy(value) {
  var v = String(value || "")
  var words = { "": "default", permanent: "hardware address", preserve: "keeps the current one", random: "new each time",
    stable: "stable", "stable-ssid": "one per network" }
  if (words.hasOwnProperty(v)) return words[v]
  return /^([0-9A-Fa-f]{2}:){5}[0-9A-Fa-f]{2}$/.test(v) ? "fixed" : v
}

// connection.metered → the sheet's chip key; NM's "unknown" is its own guess (Auto).
function meteredKey(value) {
  return value === "yes" || value === "no" ? value : "unknown"
}

var MONTHS = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]
function pad2(n) { return (n < 10 ? "0" : "") + n }

// "14:02" today, "Nov 23, 14:02" this year, "Nov 23 2025, 14:02" before. ts / now in seconds, local time.
function whenText(ts, now) {
  if (!(ts > 0)) return ""
  var d = new Date(ts * 1000)
  var n = new Date(now * 1000)
  var hm = pad2(d.getHours()) + ":" + pad2(d.getMinutes())
  if (d.toDateString() === n.toDateString()) return hm
  return MONTHS[d.getMonth()] + " " + d.getDate() + (d.getFullYear() !== n.getFullYear() ? " " + d.getFullYear() : "") + ", " + hm
}

// connection.timestamp = the last successful activation (NM keeps it while the link stays up).
function sinceText(ts, now, active) {
  if (!(ts > 0)) return active ? "Connected" : "Never connected"
  return (active ? "Connected since " : "Last used ") + whenText(ts, now)
}

// Second line of a saved row the scan does not show.
function savedRowDetail(ts, now) {
  return "Saved · " + (ts > 0 ? "last used " + whenText(ts, now) : "never connected")
}

// "Automatic · 2a03:…/64": the method, then the first global address (runtime, else the profile's own).
function ipv6Text(p) {
  var words = { auto: "Automatic", dhcp: "DHCPv6", manual: "Manual", "link-local": "Link-local only", ignore: "Ignored",
    disabled: "Off", shared: "Shared" }
  var method = p["ipv6.method"] || "auto"
  var addrs = (p["IP6.ADDRESS"] || []).filter(function(a) { return a.toLowerCase().indexOf("fe80:") !== 0 })
  var addr = addrs[0] || splitList(p["ipv6.addresses"])[0] || ""
  return (words.hasOwnProperty(method) ? words[method] : method) + (addr ? " · " + addr : "")
}

function splitList(s) {
  return String(s || "").split(/[\s,]+/).filter(function(x) { return x !== "" })
}

// Dotted quad, no leading zeros (inet_aton reads "010" as octal).
function isIpv4(s) {
  var parts = String(s || "").split(".")
  if (parts.length !== 4) return false
  for (var i = 0; i < 4; i++) {
    if (!/^(0|[1-9][0-9]{0,2})$/.test(parts[i]) || Number(parts[i]) > 255) return false
  }
  return true
}

// "192.168.1.50/24"; a bare address gets /24 (the usual home LAN). "" when invalid.
function cidr(s) {
  var t = String(s || "").trim()
  var m = t.match(/^([0-9.]+)(?:\/([0-9]{1,2}))?$/)
  if (!m || !isIpv4(m[1])) return ""
  var prefix = m[2] === undefined ? 24 : Number(m[2])
  return prefix >= 1 && prefix <= 32 ? m[1] + "/" + prefix : ""
}

// The sheet's three choices: dhcp, dns (DHCP address + own resolvers), manual. Other methods (shared, disabled,
// link-local) keep their name and select no chip.
function ipv4Form(p) {
  var method = p["ipv4.method"] || "auto"
  var dns = splitList(p["ipv4.dns"]).join(", ")
  return {
    mode: method === "manual" ? "manual" : method !== "auto" ? method : dns ? "dns" : "dhcp",
    address: splitList(p["ipv4.addresses"])[0] || "",
    gateway: p["ipv4.gateway"] || "",
    dns: dns
  }
}

function sameForm(a, b) {
  return a.mode === b.mode && a.address.trim() === b.address.trim() && a.gateway.trim() === b.gateway.trim()
    && splitList(a.dns).join(",") === splitList(b.dns).join(",")
}

// "" when the form can be applied, else what to fix.
function ipv4Error(f) {
  if (f.mode !== "dhcp" && f.mode !== "dns" && f.mode !== "manual") return "Pick DHCP, DHCP + DNS or Manual"
  if (f.mode === "manual" && !cidr(f.address)) return "Address: like 192.168.1.50/24"
  if (f.mode === "manual" && f.gateway.trim() && !isIpv4(f.gateway.trim())) return "Gateway: an IPv4 address"
  if (f.mode === "dhcp") return ""
  var dns = splitList(f.dns)
  if (f.mode === "dns" && dns.length === 0) return "DNS: at least one server"
  for (var i = 0; i < dns.length; i++) {
    if (!isIpv4(dns[i])) return "DNS: " + dns[i] + " is not an IPv4 address"
  }
  return ""
}

// `nmcli connection modify uuid <u>` property pairs. Unused fields are cleared: NM refuses a gateway without an
// address, and "auto" would keep a static address as an extra one.
function ipv4Args(f) {
  var dns = splitList(f.dns).join(",")
  if (f.mode === "manual") {
    return ["ipv4.method", "manual", "ipv4.addresses", cidr(f.address), "ipv4.gateway", f.gateway.trim(),
      "ipv4.dns", dns, "ipv4.ignore-auto-dns", "no"]
  }
  var own = f.mode === "dns"
  return ["ipv4.method", "auto", "ipv4.addresses", "", "ipv4.gateway", "",
    "ipv4.dns", own ? dns : "", "ipv4.ignore-auto-dns", own ? "yes" : "no"]
}

if (typeof module !== "undefined") {
  module.exports = {
    parseShow: parseShow,
    savedProfiles: savedProfiles,
    savedRows: savedRows,
    pickAp: pickAp,
    keyMgmtLabel: keyMgmtLabel,
    macPolicy: macPolicy,
    meteredKey: meteredKey,
    whenText: whenText,
    sinceText: sinceText,
    savedRowDetail: savedRowDetail,
    ipv6Text: ipv6Text,
    splitList: splitList,
    isIpv4: isIpv4,
    cidr: cidr,
    ipv4Form: ipv4Form,
    sameForm: sameForm,
    ipv4Error: ipv4Error,
    ipv4Args: ipv4Args
  }
}
