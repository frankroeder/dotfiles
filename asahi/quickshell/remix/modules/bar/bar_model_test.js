#!/usr/bin/env node
"use strict";

const fs = require("fs");
const path = require("path");
const vm = require("vm");

const src = fs.readFileSync(path.join(__dirname, "BarModel.js"), "utf8");
const ctx = {};
vm.createContext(ctx);
vm.runInContext(src, ctx);

let failed = 0;
function eq(got, expected, msg) {
  if (got === expected) console.log("ok  " + msg);
  else {
    failed += 1;
    console.log("FAIL  " + msg + " got=" + JSON.stringify(got) + " expected=" + JSON.stringify(expected));
  }
}

const fmt = ctx.formatAge;
eq(typeof fmt, "function", "formatAge exported");
eq(fmt(0, 100), "", "missing since is empty");
eq(fmt(50, 40), "", "future since is empty");
eq(fmt(100, 100), "0m", "0s → 0m");
eq(fmt(100, 159), "0m", "59s → 0m");
eq(fmt(100, 160), "1m", "60s → 1m");
eq(fmt(100, 100 + 3600), "1h 0m", "1h");
eq(fmt(100, 100 + 3600 + 90), "1h 1m", "1h 1m");
eq(fmt(100, 100 + 86400), "1d 0h", "1d");
eq(fmt(100, 100 + 2 * 86400 + 5 * 3600), "2d 5h", "2d 5h");

const icon = ctx.trayIcon;
eq(icon("/usr/share/icons/x.png"), "/usr/share/icons/x.png", "plain icon path passes through");
eq(icon("foo/bar.png?path=/usr/share/icons"), "file:///usr/share/icons/bar.png", "?path= resolves to a file url");

const detail = ctx.trayDetail;
eq(detail("Nextcloud", "Nextcloud: Last sync was successful."), "Last sync was successful.", "own name trimmed off the tooltip");
eq(detail("Chromium", "Chromium"), "", "a tooltip that only repeats the title is dropped");
eq(detail("TelegramDesktop", "Telegram Desktop"), "", "whitespace-only difference counts as a repeat");
eq(detail("btop", ""), "", "no tooltip → no subtitle");

const spacer = ctx.notchSpacerWidth;
eq(spacer("DP-1", 1512), 0, "external screen → no cutout");
eq(spacer("eDP-1", 1512), 197, "@2x: 185 logical cutout + air");
eq(spacer("eDP-1", 3024), 382, "@1x: 370 px cutout + air");
const inset = ctx.notchRegionInset;
eq(typeof inset, "function", "notchRegionInset exported");
eq(inset(1492, 0), 0, "no notch → no reserved hole");
eq(inset(0, 227), 0, "no width → no reserved hole");
// eDP-1 3024x1964 @2x: 1512 logical wide, 1492 inside the edge margins, 227 cutout.
eq(inset(1492, 227), 860, "right cluster starts at the cutout's right edge");
eq(1492 - inset(1492, 227), 632, "left cluster ends at the cutout's left edge");
// @1.333: 2268 logical, 2248 inside the margins, 340 cutout.
eq(inset(2248, 340), 1294, "1.333 scale reserves the same 15% band");

const notch = ctx.notchHeight;
eq(typeof notch, "function", "notchHeight exported");
eq(notch("HDMI-A-1", 2048, 1152), 0, "external panels have no cutout");
eq(notch("eDP-1", 0, 0), 0, "no geometry → no cutout");
eq(notch("eDP-1", 1920, 1080), 0, "a 16:9 panel is not notched");
// eDP-1 3024x1964. The strip above the 16:10 area is 74 physical rows — the value the
// old lookup table put at 64, which left the bar 10px shy of the camera housing.
eq(notch("eDP-1", 3024, 1964), 74, "native: the full 74-row strip, not 64");
eq(notch("eDP-1", 1512, 982), 37, "@2x: 74 physical rows = 37 logical");
eq(notch("eDP-1", 2268, 1473), 56, "@1.333: covers the strip instead of stopping at 48");

const drop = ctx.popupDrop;
eq(drop(37, 36), 7, "@2x notch bar: 36px chip clears the 37px bar by 6px");
eq(drop(56, 36), 16, "@1.333 notch bar: drop covers the taller bar, not just the chip");
eq(drop(36, 36), 6, "external bar: plain gap");

// Right cluster: what shows beyond the fixed chips, most important first, whole or not at all.
const grants = ctx.rightGrants;
const asks = (o) => Object.assign({ rec: 0, timer: 0, awake: 0, night: 0, cup: 23, updates: 0, ccu: 0, vpnName: 0, vpnAge: 0, netName: 0 }, o);
const shown = (g) => Object.keys(g).filter((k) => g[k] === true).sort().join(" ");
let g = grants(600, asks({ rec: 63, timer: 51, night: 24, updates: 24, ccu: 40, vpnName: 100, vpnAge: 40, netName: 120 }), 3, 24, false);
eq(shown(g), "awake ccu cup netName night rec timer tray updates vpnAge vpnName", "external screen: room for all");
eq(g.trayInline, 3, "three tray icons inline, no pill");
g = grants(600, asks({ ccu: 40, vpnName: 100, vpnAge: 40, netName: 120 }), 0, 24, true);
eq(shown(g), "awake ccu cup night rec timer tray updates", "notch: the VPN's name never shows, nor anything after it");
g = grants(100, asks({ ccu: 40, netName: 120 }), 0, 24, false);
eq(g.ccu === true && !g.netName, true, "words stop at the first that does not fit");
g = grants(100, asks({ ccu: 40, vpnName: 100, vpnAge: 20 }), 0, 24, false);
eq(!g.vpnName && !g.vpnAge, true, "no VPN uptime without its name, even if it would fit");
// Tight (the notch side with REC, a timer and night light on): chips drop from the least important end.
g = grants(150, asks({ rec: 63, timer: 51, night: 24, updates: 24, ccu: 40 }), 1, 24, true);
eq(shown(g), "awake night rec timer", "REC, timer and night light before tray, idle cup, updates and words");
eq(g.trayInline, 0, "a tray that got no room shows no icon");
g = grants(170, asks({ rec: 63, timer: 51, night: 24, updates: 24 }), 5, 24, true);
eq(g.tray && !g.cup && !g.updates, true, "the tray's pill before the idle cup and the updates box");
eq(g.trayInline, 0, "pill only: no room for an icon beside it");
g = grants(60, asks({ rec: 63, timer: 51 }), 0, 24, true);
eq(!g.rec && g.timer === true, true, "a chip that does not fit is skipped, a smaller one after it still shows");
g = grants(40, asks({ awake: 23, cup: 0, night: 24 }), 0, 24, true);
eq(g.awake === true && !g.night, true, "stay awake on outranks the night light");
g = grants(-5, asks({ rec: 63 }), 2, 24, true);
eq(shown(g), "", "the fixed chips already overflow: nothing more");
// Tray: all inline while they fit (at most 3), else as many as fit beside the 30 px pill.
eq(grants(24, asks({ cup: 0 }), 1, 24, true).trayInline, 1, "one item: its icon, no pill");
eq(grants(23, asks({ cup: 0 }), 1, 24, true).tray, false, "one item without room: nothing");
eq(grants(48, asks({ cup: 0 }), 2, 24, true).trayInline, 2, "two items, 48 px: both");
eq(grants(47, asks({ cup: 0 }), 2, 24, true).trayInline, 0, "two items, 47 px: the pill alone");
eq(grants(60, asks({ cup: 0 }), 3, 24, true).trayInline, 1, "three items, 60 px: one beside the pill");
eq(grants(500, asks({ cup: 0 }), 7, 24, true).trayInline, 3, "seven items: three inline, the rest behind the pill");
g = grants(48 + 40, asks({ cup: 0, ccu: 40 }), 2, 24, true);
eq(g.trayInline === 2 && g.ccu === true, true, "icons shown inline are paid for before the words");
g = grants(48 + 39, asks({ cup: 0, ccu: 40 }), 2, 24, true);
eq(g.trayInline === 2 && !g.ccu, true, "…and a word one pixel short stays out");

// BarHost wiring the screenshots depend on.
const host = fs.readFileSync(path.join(__dirname, "BarHost.qml"), "utf8");
const move = host.match(/id: chipMove[\s\S]*?\n  \}/);
eq(!!move && /property: "opacity"; to: 1/.test(move[0]), true, "chipMove finishes an interrupted fade-in (a chip stuck at opacity 0)");
const base = host.match(/readonly property real rightBase:[\s\S]*?\n  readonly property real rightRoom/);
eq(!!base && !/notifBlock|statusBlock/.test(base[0]), true, "rightBase measures neither the hidden bell nor the granted status chips");
eq(/bellWidth: notchInset > 0 \? notifNotch\.implicitWidth \+ 4/.test(host), true, "notch: the budget counts the bell that is shown");

if (failed) {
  console.log(failed + " failed");
  process.exit(1);
}
console.log("all passed");
