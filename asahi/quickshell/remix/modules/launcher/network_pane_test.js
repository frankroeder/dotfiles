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

// Which scanned networks ask for a password (nmcli SECURITY strings).
check(!M.wifiNeedsPassword("") && !M.wifiNeedsPassword("--"), "open networks connect without a password");
check(!M.wifiNeedsPassword("OWE"), "OWE (Enhanced Open) connects without a password");
check(M.wifiNeedsPassword("WPA2") && M.wifiNeedsPassword("WPA2 WPA3") && M.wifiNeedsPassword("WPA3")
  && M.wifiNeedsPassword("WEP") && M.wifiNeedsPassword("WPA2 802.1X"), "WEP / WPA / enterprise ask for credentials");

console.log("\n== wifi security words ==");
check(M.wifiSecurityLabel("") === "Open" && M.wifiSecurityLabel("--") === "Open", "empty security is Open");
check(M.wifiSecurityLabel("OWE") === "Enhanced Open", "OWE is Enhanced Open");
check(M.wifiPlaceKind("OWE-TM") === "public" && !M.wifiNeedsPassword("OWE-TM"), "OWE transition is Enhanced Open, no password");
check(M.wifiSecurityLabel("WPA2") === "WPA2" && M.wifiSecurityLabel("WPA1 WPA2") === "WPA2", "WPA2");
check(M.wifiSecurityLabel("WPA2 WPA3") === "WPA3" && M.wifiSecurityLabel("WPA3") === "WPA3", "WPA3 wins when both are offered");
check(M.wifiSecurityLabel("WPA2 802.1X") === "WPA2 · 802.1X", "campus WPA2 keeps 802.1X");
check(M.wifiSecurityLabel("WPA3 802.1X") === "WPA3 · 802.1X", "campus WPA3 keeps 802.1X");
check(M.wifiSecurityLabel("WEP") === "WEP", "WEP stays WEP");
check(M.wifiPlaceKind("WPA3") === "private" && M.wifiPlaceWord("WPA2") === "Private", "a password lock is private");
check(M.wifiPlaceKind("WPA2 802.1X") === "signin" && M.wifiPlaceWord("WPA3 802.1X") === "Sign-in", "802.1X is sign-in");
check(M.wifiPlaceKind("") === "public" && M.wifiPlaceKind("WEP") === "public", "open and WEP are public");
check(M.wifiPlaceKind("OWE") === "public", "Enhanced Open is public");
check(M.wifiPlaceNote("WPA3") === "" && M.wifiPlaceNote("WPA2") === "", "a password network gets no lecture");
check(M.wifiPlaceNote("").indexOf("Open network") === 0 && M.wifiPlaceNote("WEP").indexOf("WEP") === 0, "open and WEP notes");
check(M.wifiPlaceNote("OWE").indexOf("Enhanced Open") === 0, "Enhanced Open note");
check(M.wifiPlaceNote("WPA2 802.1X").indexOf("Sign-in") === 0, "campus note");
check(M.wifiRowDetail({ active: true, sec: "WPA3", band: "5 GHz" }, false) === "Connected · Private · WPA3 · 5 GHz", "connected row");
check(M.wifiRowDetail({ known: true, sec: "WPA2 802.1X", band: "" }, false) === "Saved · Sign-in · WPA2 · 802.1X", "saved campus row");
check(M.wifiRowDetail({ sec: "", band: "2.4 GHz" }, false) === "Public · Open · 2.4 GHz", "open row");
check(M.wifiRowDetail({ sec: "OWE", band: "5 GHz" }, false) === "Public · Enhanced Open · 5 GHz", "enhanced open row");
check(M.wifiRowDetail({ sec: "WPA2" }, true) === "Connecting…", "connecting replaces the detail");
check(qml.indexOf("QuickModels.wifiPlaceWord") !== -1, "the card names Private / Sign-in / Public");
check(qml.indexOf("QuickModels.wifiPlaceNote") !== -1, "the card shows the place note");
check(qml.indexOf("Layout.preferredWidth: 112") !== -1, "the join code reserves its width in the layout");
check(qml.indexOf("width: 112") === -1, "the join code does not paint a raw width over the next card");
check(
  /pct >= 70 \? "Excellent" : pct >= 50 \? "Good" : pct >= 30 \? "Fair" : "Weak"/.test(qml),
  "card quality: Excellent ≥ 70, Good ≥ 50, Fair ≥ 30, Weak below"
);
const tooltip = fs.readFileSync(path.join(__dirname, "../../../../bin/asahi-network"), "utf8");
check(tooltip.indexOf("dBm:") !== -1 && tooltip.indexOf("^-?[0-9]{1,3}$") !== -1, "tooltip dBm is a short signed integer");
check(tooltip.indexOf("Channel:") !== -1 && tooltip.indexOf('"$channel" != 0') !== -1, "tooltip channel, 0 omitted");

if (failed > 0) {
  console.log("\n" + failed + " assertion(s) failed");
  process.exit(1);
}
console.log("\nall assertions passed");
assert.strictEqual(failed, 0);
