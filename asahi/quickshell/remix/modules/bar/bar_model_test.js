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

if (failed) {
  console.log(failed + " failed");
  process.exit(1);
}
console.log("all passed");
