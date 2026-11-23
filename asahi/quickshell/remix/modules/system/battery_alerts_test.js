#!/usr/bin/env node
"use strict";
// battery_alerts.js: low, critical (repeating each minute), then one Charging card on the charger.
const fs = require("fs");
const path = require("path");
const vm = require("vm");

const src = fs.readFileSync(path.join(__dirname, "battery_alerts.js"), "utf8").replace(".pragma library", "");
const A = {};
vm.runInNewContext(src + "\nA.next = next; A.initial = initial;", { A });

let failed = 0;
function check(ok, msg) { console.log((ok ? "ok  " : "FAIL  ") + msg); if (!ok) failed++; }

let s = A.initial();
let r = A.next(s, 50, false, 0);
check(r.card === null, "50 % on battery: nothing");
r = A.next(r.state, 20, false, 1000);
check(r.card && r.card[0] === "Low battery" && r.card[3] === "normal" && r.card[2] === 10000, "20 %: one Low battery card");
r = A.next(r.state, 18, false, 2000);
check(r.card === null, "still low: no second card");
r = A.next(r.state, 10, false, 3000);
check(r.card && r.card[0] === "Critical battery" && r.card[3] === "critical" && r.card[1] === "Battery at 10%. Connect charger.",
  "10 %: critical card");
r = A.next(r.state, 9, false, 30000);
check(r.card === null, "critical again within a minute: nothing");
r = A.next(r.state, 9, false, 63000);
check(r.card && r.card[0] === "Critical battery", "a minute later: the critical card again");
r = A.next(r.state, 9, true, 64000);
check(r.card && r.card[0] === "Charging · 9%" && r.card[3] === "low" && r.card[2] === 4000, "charger after an alert: one Charging card");
r = A.next(r.state, 10, true, 65000);
check(r.card === null, "charging on: no more cards");
r = A.next(A.initial(), 30, true, 0);
check(r.card === null, "charger without an alert before: no Charging card");
r = A.next(A.initial(), 5, false, 0);
check(r.card && r.card[0] === "Critical battery", "starting at 5 %: critical at once (no low card first)");

if (failed) { console.log("\n" + failed + " failed"); process.exit(1); }
console.log("\nall passed");
