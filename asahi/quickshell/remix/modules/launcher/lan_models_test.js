#!/usr/bin/env node
"use strict";

const fs = require("fs");
const path = require("path");
const L = require("./lan_models.js");

let failed = 0;
function check(cond, msg) {
  if (cond) console.log("ok  " + msg);
  else {
    failed += 1;
    console.log("FAIL  " + msg);
  }
}
const eq = (a, b, msg) => check(JSON.stringify(a) === JSON.stringify(b), msg + " (got " + JSON.stringify(a) + ")");

function dev(mac, name, extra) {
  return Object.assign({ mac: mac, ip: "192.168.178." + parseInt(mac.slice(-2), 16), name: name, auto: name, custom: false, host: "",
    vendor: "", model: "", private: false, kind: "unknown", label: "Device", group: "other", state: "online", self: false, gw: false,
    pinned: false, new: false, web: "", seen: 0, ssh: 0 }, extra || {})
}
const gw = dev("74:42:7f:00:00:01", "Router", { kind: "router", label: "Router", group: "network", gw: true, vendor: "AVM" })
const me = dev("ee:01:d3:00:00:7c", "laptop", { kind: "laptop", label: "Laptop", group: "computers", self: true, private: true })
const pi = dev("d8:3a:dd:00:00:32", "raspberrypi", { kind: "computer", label: "Computer", group: "computers", vendor: "Raspberry Pi",
  pinned: true, state: "idle" })
const phone = dev("26:62:ae:00:00:29", "iPhone", { kind: "phone", label: "Phone", group: "mobile", private: true, new: true })
const printer = dev("30:05:5c:00:00:3d", "Brother HL-L2350DW", { kind: "printer", label: "Printer", group: "office", vendor: "Brother",
  model: "Brother HL-L2350DW series", web: "http://192.168.178.61/" })
const snap = { devices: [gw, me, pi, phone, printer] }

console.log("== glyphs ==")
check(L.glyph("phone") === String.fromCodePoint(0xF011C), "phone glyph")
check(L.glyph("nope") === L.glyph("unknown"), "unknown kind falls back")

console.log("\n== listRows ==")
eq(L.listRows(snap, "list", [], "").map((r) => r.name), ["Router", "laptop", "raspberrypi", "iPhone", "Brother HL-L2350DW"], "flat list")
check(L.listRows(snap, "list", [], "").every((r) => r.key === r.mac && !r.header), "device rows keyed by mac")
eq(L.listRows(snap, "type", [], "printer").map((r) => r.name), ["Brother HL-L2350DW"], "\"printer\" finds the printer, flat")
eq(L.listRows(snap, "type", [], "rasp pi").map((r) => r.name), ["raspberrypi"], "search: every word")
eq(L.listRows(snap, "type", [], "192.168.178.41").map((r) => r.name), ["iPhone"], "search by IP")
const typed = L.listRows(snap, "type", [], "")
eq(typed.map((r) => r.header ? "#" + r.id : r.name), ["#pinned", "raspberrypi", "#office", "Brother HL-L2350DW", "#computers", "laptop",
  "#mobile", "iPhone", "#network", "Router"], "type groups: pinned, then printers first")
const mobile = typed.find((r) => r.key === "g:mobile")
eq([mobile.title, mobile.count, mobile.online, mobile.fresh], ["Phones & tablets", 1, 1, true], "header counts + NEW marker")
eq(L.listRows(snap, "type", ["mobile"], "").filter((r) => !r.header).map((r) => r.name).indexOf("iPhone"), -1,
  "collapsed group keeps its header, drops its rows")

console.log("\n== text ==")
eq(L.status(pi), "idle · 192.168.178.50", "idle status")
eq(L.status(dev("aa:00:00:00:00:01", "x", { state: "asleep", seen: 90 })), "asleep · 1 h ago", "asleep status")
eq(L.secondary(printer), "Printer · Brother HL-L2350DW series · Brother", "printer: type · model · maker")
eq(L.secondary(phone), "Phone · private address", "randomised MAC: no maker")
eq(L.secondary(dev("aa:00:00:00:00:02", "x", { label: "Printer", model: "Printer" })), "Printer", "no repeated words")
eq(L.details(Object.assign({}, pi, { custom: true, auto: "raspberrypi", name: "Pi", host: "raspberrypi" })).map((p) => p[0]),
  ["Name", "Host", "IP", "MAC"], "details")
check(L.stateText(pi, false).indexOf("never pinged") !== -1, "idle on an untrusted network says why")

console.log("\n== ssh / ping ==")
check(L.canSsh(pi) && !L.canSsh(me) && !L.canSsh(gw) && !L.canSsh(phone), "SSH: computers, not this laptop / router / phone")
check(L.canSsh(Object.assign({}, phone, { ssh: 22 })), "SSH: anything advertising _ssh._tcp")
eq(L.sshArgs(pi), ["ssh", "192.168.178.50"], "ssh args")
eq(L.sshArgs(Object.assign({}, pi, { ssh: 2222 })), ["ssh", "-p", "2222", "192.168.178.50"], "ssh on an advertised port")
const ok = "--- 192.168.178.50 ping statistics ---\n4 packets transmitted, 4 received, 0% packet loss, time 603ms\n" +
  "rtt min/avg/max/mdev = 2.415/2.574/12.734/0.159 ms\n"
eq(L.parsePing(ok), { sent: 4, got: 4, min: 2.415, avg: 2.574, max: 12.734 }, "ping summary")
eq(L.pingText(L.parsePing(ok)), "4/4 answered · 2.6 ms (2.4–13)", "ping text")
eq(L.pingText(L.parsePing("4 packets transmitted, 0 received, 100% packet loss, time 608ms")), "No answer (4 sent)", "no answer")
eq(L.pingText(L.parsePing("ping: connect: Network is unreachable")), "Ping failed", "no summary")
eq(L.pingText({ busy: true }), "Pinging…", "busy")

console.log("\n== NetworkPane / LanDevices wiring ==")
const pane = fs.readFileSync(path.join(__dirname, "panes/NetworkPane.qml"), "utf8")
const view = fs.readFileSync(path.join(__dirname, "panes/LanDevices.qml"), "utf8")
check(/asahi-lan", "watch"/.test(pane) && pane.indexOf("--pdeathsig") !== -1, "collector runs as watch with pdeathsig")
check(/running: quickNetworkRoot\.live && quickNetworkRoot\.netTab === "devices"/.test(pane), "collector only while Devices is shown")
check(pane.indexOf('import "." as Panes') !== -1 && /Panes\.LanDevices \{/.test(pane),
  "LanDevices is used qualified (a bare sibling type is not a type in the live shell)")
check(pane.indexOf('/.local/state/asahi/network-tab"') !== -1 && /onNetTabChanged:.*setText/.test(pane), "last tab saved to a state file")
check(/\/\/ VPN card\.\n\s+Card \{\n\s+Layout\.fillWidth: true/.test(pane), "VPN card stays on both tabs (no layout jump)")
check(/pingProc\.command = \["ping", "-n", "-q", "-c", "4"/.test(view) && view.indexOf("running: true") === -1, "ping only on click")
check((view.match(/Text\.PlainText/g) || []).length >= 3, "device names / hosts render as plain text")

if (failed) {
  console.log("\n" + failed + " failed")
  process.exit(1)
}
console.log("\nall passed")
