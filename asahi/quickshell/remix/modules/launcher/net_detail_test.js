#!/usr/bin/env node
"use strict";

// Network detail sheet helpers (net_detail.js) + the sheet's edit path. Run: node net_detail_test.js
const fs = require("fs");
const path = require("path");
const N = require("./net_detail.js");
const Q = require("./quick_models.js");

let failed = 0;
function check(cond, msg) {
  if (cond) console.log("ok  " + msg);
  else { failed += 1; console.log("FAIL  " + msg); }
}
const eq = (a, b) => JSON.stringify(a) === JSON.stringify(b);

console.log("== parseShow ==");
const show = N.parseShow([
  "connection.id:Cafe: 5G",
  "ipv4.method:auto",
  "ipv4.dns:1.1.1.1,9.9.9.9",
  "GENERAL.STATE:activated",
  "IP4.ADDRESS[1]:192.168.178.88/24",
  "IP4.DNS[1]:192.168.178.1",
  "IP4.DNS[2]:192.168.178.2",
  "IP6.ADDRESS[1]:fe80::1/64",
  "IP6.ADDRESS[2]:2a03:7846::5/64",
  ""
].join("\n"));
check(show["connection.id"] === "Cafe: 5G", "first ':' splits; a ':' in the value stays");
check(eq(show["IP4.DNS"], ["192.168.178.1", "192.168.178.2"]), "indexed runtime keys collect into a list");
check(eq(show["IP4.ADDRESS"], ["192.168.178.88/24"]), "single indexed key is a list too");
check(N.ipv6Text(show) === "Automatic · 2a03:7846::5/64", "IPv6: method + first non-link-local address");
check(N.ipv6Text({ "ipv6.method": "disabled" }) === "Off", "IPv6 off");
check(N.ipv6Text({ "ipv6.method": "manual", "ipv6.addresses": "fd00::2/64" }) === "Manual · fd00::2/64", "IPv6 manual, profile address");

console.log("\n== saved profiles + rows ==");
const conn = [
  "Home:u1:802-11-wireless:1795559791:yes",
  "lo:u0:loopback:1792209618:yes",
  "Cafe\\: 5G:u2:802-11-wireless:1794894853:no",
  "Old:u3:802-11-wireless:0:no",
  "TUHH-VPN:u4:vpn:1795191952:no"
].map(Q.nmcliFields);
const prof = N.savedProfiles(conn);
check(eq(prof.map(p => p.uuid), ["u1", "u2", "u3"]), "Wi-Fi profiles only, most recent first");
check(prof[1].name === "Cafe: 5G" && prof[0].active && !prof[1].active, "escaped name and ACTIVE flag");
const rows = N.savedRows(prof, ["Home", "Bu33"]);
check(eq(rows.map(r => r.ssid), ["Cafe: 5G", "Old"]), "rows: not active, not in the scan");
check(rows[0].section === "Other saved networks" && rows[1].section === "", "one section caption");
check(rows[0].saved && rows[0].known && rows[0].uuid === "u2", "saved rows carry uuid + flags");
check(N.savedRows(prof, ["Cafe: 5G"]).length === 1, "a profile the scan shows stays in the scan's row");
check(N.savedRows([{ name: "A", uuid: "1" }, { name: "A", uuid: "2" }], []).length === 1, "duplicate names: one row (model key)");

console.log("\n== access point ==");
const aps = [
  ":44\\:4E\\:6D\\:F9\\:6A\\:95:Home:1:2412 MHz:80:WPA2",
  "*:44\\:4E\\:6D\\:F9\\:6A\\:94:Home:36:5180 MHz:61:WPA2",
  ":AA\\:BB\\:CC\\:DD\\:EE\\:FF:Other:6:2437 MHz:90:"
].map(Q.nmcliFields);
const ap = N.pickAp(aps, "Home");
check(ap.inUse && ap.bssid === "44:4E:6D:F9:6A:94" && ap.chan === "36" && ap.freq === 5180 && ap.signal === 61, "in-use AP wins");
check(N.pickAp(aps.slice(0, 1).concat(aps.slice(2)), "Home").signal === 80, "else the one listed");
check(N.pickAp(aps, "Gone") === null, "not in the scan: null");
check(N.pickAp(aps, "Other").sec === "", "open AP: empty security");

console.log("\n== words ==");
check(N.keyMgmtLabel("wpa-psk") === "WPA2" && N.keyMgmtLabel("sae") === "WPA3", "PSK / SAE");
check(N.keyMgmtLabel("wpa-eap") === "Enterprise" && N.keyMgmtLabel("wpa-eap-suite-b-192") === "Enterprise", "802.1X");
check(N.keyMgmtLabel("owe") === "Enhanced Open" && N.keyMgmtLabel(undefined) === "Open" && N.keyMgmtLabel("none") === "WEP", "OWE / open / WEP");
check(N.macPolicy("") === "default" && N.macPolicy("stable-ssid") === "one per network", "MAC policy words");
check(N.macPolicy("aa:bb:cc:dd:ee:ff") === "fixed" && N.macPolicy("toString") === "toString", "fixed MAC; no prototype keys");
check(N.meteredKey("unknown") === "unknown" && N.meteredKey("yes") === "yes" && N.meteredKey("") === "unknown", "metered chips");

console.log("\n== times ==");
const now = new Date(2026, 10, 25, 9, 30).getTime() / 1000;
check(N.whenText(new Date(2026, 10, 25, 8, 5).getTime() / 1000, now) === "08:05", "today: time only");
check(N.whenText(new Date(2026, 10, 23, 14, 2).getTime() / 1000, now) === "Nov 23, 14:02", "this year: month day");
check(N.whenText(new Date(2025, 0, 3, 7, 0).getTime() / 1000, now) === "Jan 3 2025, 07:00", "older: with the year");
check(N.sinceText(0, now, false) === "Never connected" && N.sinceText(0, now, true) === "Connected", "no timestamp");
check(N.sinceText(new Date(2026, 10, 25, 8, 5).getTime() / 1000, now, true) === "Connected since 08:05", "active");
check(N.savedRowDetail(0, now) === "Saved · never connected", "saved row, never used");

console.log("\n== IPv4 validation ==");
check(N.isIpv4("192.168.1.1") && N.isIpv4("0.0.0.0") && N.isIpv4("255.255.255.255"), "valid quads");
check(!N.isIpv4("256.1.1.1") && !N.isIpv4("1.2.3") && !N.isIpv4("01.2.3.4") && !N.isIpv4("1.2.3.4 ") && !N.isIpv4("a.b.c.d"),
  "bad quads (range, length, leading zero, space, letters)");
check(N.cidr("192.168.1.50/24") === "192.168.1.50/24" && N.cidr(" 10.0.0.2 ") === "10.0.0.2/24", "cidr; bare address → /24");
check(N.cidr("10.0.0.2/33") === "" && N.cidr("10.0.0.2/0") === "" && N.cidr("10.0.0.2/") === "", "bad prefixes");
const dhcp = N.ipv4Form({ "ipv4.method": "auto", "ipv4.dns": "", "ipv4.addresses": "", "ipv4.gateway": "" });
check(dhcp.mode === "dhcp", "auto, no DNS → DHCP");
check(N.ipv4Form({ "ipv4.method": "auto", "ipv4.dns": "1.1.1.1,9.9.9.9" }).dns === "1.1.1.1, 9.9.9.9", "auto + DNS → dns");
check(N.ipv4Form({ "ipv4.method": "manual", "ipv4.addresses": "10.0.0.2/8" }).address === "10.0.0.2/8", "manual");
check(N.ipv4Form({ "ipv4.method": "shared" }).mode === "shared" && N.ipv4Error({ mode: "shared" }) !== "", "other methods: no chip");
check(N.sameForm(dhcp, Object.assign({}, dhcp)) && !N.sameForm(dhcp, Object.assign({}, dhcp, { mode: "dns" })), "dirty check");
check(N.sameForm(dhcp, Object.assign({}, dhcp, { dns: "1.1.1.1" })), "dirty check: DHCP ignores a typed DNS");
check(N.sameForm({ mode: "dns", address: "", gateway: "", dns: "1.1.1.1, 9.9.9.9" },
  { mode: "dns", address: "", gateway: "", dns: "1.1.1.1,9.9.9.9 " }), "DNS spacing is not a change");
const f = (mode, address, gateway, dns) => ({ mode: mode, address: address || "", gateway: gateway || "", dns: dns || "" });
check(N.ipv4Error(f("dhcp")) === "", "DHCP needs nothing");
check(N.ipv4Error(f("dns")) !== "" && N.ipv4Error(f("dns", "", "", "1.1.1.1 9.9.9.9")) === "", "DHCP + DNS needs a server");
check(N.ipv4Error(f("dns", "", "", "1.1.1.1, ::1")).indexOf("::1") !== -1, "IPv6 resolver refused in ipv4.dns");
check(N.ipv4Error(f("manual", "192.168.1.300/24")).indexOf("Address") === 0, "bad address");
check(N.ipv4Error(f("manual", "192.168.1.50/24", "192.168.1")).indexOf("Gateway") === 0, "bad gateway");
check(N.ipv4Error(f("manual", "192.168.1.50/24")) === "", "manual without gateway / DNS is fine");

console.log("\n== nmcli modify arguments ==");
check(eq(N.ipv4Args(f("dhcp", "1.2.3.4/24", "1.2.3.1", "8.8.8.8")),
  ["ipv4.method", "auto", "ipv4.addresses", "", "ipv4.gateway", "", "ipv4.dns", "", "ipv4.ignore-auto-dns", "no"]), "DHCP clears the rest");
check(eq(N.ipv4Args(f("dns", "", "", "1.1.1.1, 9.9.9.9")),
  ["ipv4.method", "auto", "ipv4.addresses", "", "ipv4.gateway", "", "ipv4.dns", "1.1.1.1,9.9.9.9", "ipv4.ignore-auto-dns", "yes"]),
  "DHCP + DNS ignores the lease's resolvers");
check(eq(N.ipv4Args(f("manual", "192.168.1.50", " 192.168.1.1 ", "192.168.1.1")),
  ["ipv4.method", "manual", "ipv4.addresses", "192.168.1.50/24", "ipv4.gateway", "192.168.1.1", "ipv4.dns", "192.168.1.1",
    "ipv4.ignore-auto-dns", "no"]), "manual: normalised address, trimmed gateway");

console.log("\n== sheet / pane structure ==");
const sheet = fs.readFileSync(path.join(__dirname, "panes/NetDetailSheet.qml"), "utf8");
const pane = fs.readFileSync(path.join(__dirname, "panes/NetworkPane.qml"), "utf8");
const units = sheet.match(/"systemd-run", "--user", "--wait", "--quiet", "--collect",\s*"nmcli", "connection", "(modify|up)", "uuid"/g) || [];
check(units.length === 2, "modify and up run as must-finish transient units, by uuid (got " + units.length + ")");
check(!/"(ba)?sh", "-c"/.test(sheet), "the sheet never goes through a shell (names / SSIDs are untrusted)");
check(/modifyProc\.reconnect = ipv4 && sheet\.active/.test(sheet), "only an IPv4 apply on an active connection reconnects");
check(/"--rescan", "no"/.test(sheet), "the sheet reads the cached scan, never a new one");
check(/if \(quickNetworkRoot\.detailOpen\) \{ quickNetworkRoot\.closeDetail\(\); return true \}/.test(pane), "Esc closes the sheet first");
check(/"connection", "delete"\]\.concat\(uuid \? \["uuid", uuid\]/.test(pane), "forget by uuid where known");
check(/Panes\.NetDetailSheet \{/.test(pane), "sheet imported qualified (Loader-loaded pane)");

if (failed > 0) {
  console.log("\n" + failed + " assertion(s) failed");
  process.exit(1);
}
console.log("\nall assertions passed");
