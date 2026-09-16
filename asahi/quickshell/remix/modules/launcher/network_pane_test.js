#!/usr/bin/env node
"use strict";

const fs = require("fs");
const path = require("path");
const assert = require("assert");

const M = require("./quick_models.js");
if (typeof M.formatRate !== "function" || typeof M.rateChipWidth !== "function") {
  throw new Error("shipped quick_models.js did not export formatRate/rateChipWidth");
}
if (typeof M.wifiRadioStatus !== "function") {
  throw new Error("shipped quick_models.js did not export wifiRadioStatus");
}

let failed = 0;
function check(cond, msg) {
  if (cond) console.log("ok  " + msg);
  else {
    failed += 1;
    console.log("FAIL  " + msg);
  }
}

console.log("== wifiRadioStatus (single off copy) ==");
check(M.wifiRadioStatus(false, "") === "Off", "wifi off → Off");
check(M.wifiRadioStatus(false, "Home") === "Off", "wifi off ignores leftover ssid");
check(M.wifiRadioStatus(true, "Home") === "Connected", "wifi on + ssid → Connected");
check(M.wifiRadioStatus(true, "") === "Not connected", "wifi on, no ssid → Not connected");

console.log("\n== formatRate + rateChipWidth (fixed chip, no reflow) ==");
const rates = [0, 12.3 * 1024, 1.2 * 1048576];
const labels = rates.map(function(b) { return M.formatRate(b); });
const widths = rates.map(function() { return M.rateChipWidth(10); });
console.log("labels " + JSON.stringify(labels));
console.log("chip widths " + JSON.stringify(widths));
check(labels[0].indexOf("B/s") !== -1, "0 bps formats as B/s (got " + labels[0] + ")");
check(labels[1].indexOf("KB/s") !== -1, "12.3 KiB/s-class formats as KB/s (got " + labels[1] + ")");
check(labels[2].indexOf("MB/s") !== -1, "1.2 MiB/s-class formats as MB/s (got " + labels[2] + ")");
check(
  widths[0] === widths[1] && widths[1] === widths[2],
  "Tx/Rx chip width is constant across 0 / KiB / MiB rates (got " + widths.join(", ") + ")"
);
check(widths[0] > 40, "chip width is wide enough for a rate label (got " + widths[0] + ")");
const w12 = M.rateChipWidth(12);
const w10 = M.rateChipWidth(10);
check(w12 === M.rateChipWidth(12), "rateChipWidth(12) is stable");
check(w10 === widths[0], "rateChipWidth depends on font size, not throughput");
rates.forEach(function(b, i) {
  check(
    labels[i].length <= M.RATE_CHIP_CHARS,
    "label[" + i + "] \"" + labels[i] + "\" fits the " + M.RATE_CHIP_CHARS + "-char chip"
  );
});

console.log("\n== NetworkPane.qml structure ==");
const qml = fs.readFileSync(path.join(__dirname, "panes/NetworkPane.qml"), "utf8");
check(
  qml.indexOf("QuickModels.wifiRadioStatus") !== -1,
  "Network pane uses shipped wifiRadioStatus (one status string)"
);
check(
  qml.indexOf("Wi-Fi is off") === -1,
  "Network pane does not repeat \"Wi-Fi is off\""
);
const offLiterals = qml.match(/"Off"/g) || [];
check(
  offLiterals.length === 0,
  "Network pane has no extra \"Off\" literals (got " + offLiterals.length + ")"
);
check(
  qml.indexOf("QuickModels.formatRate") !== -1,
  "Tx/Rx chips use shipped formatRate"
);
check(
  qml.indexOf("QuickModels.rateChipWidth") !== -1,
  "Tx/Rx chips use shipped rateChipWidth"
);
check(
  /fixedWidth:\s*QuickModels\.rateChipWidth/.test(qml),
  "Tx/Rx Chip.fixedWidth is the shipped helper"
);
check(
  !/function fmtRate/.test(qml),
  "Network pane does not keep a local fmtRate"
);

if (failed > 0) {
  console.log("\n" + failed + " assertion(s) failed");
  process.exit(1);
}
console.log("\nall assertions passed");
assert.strictEqual(failed, 0);
