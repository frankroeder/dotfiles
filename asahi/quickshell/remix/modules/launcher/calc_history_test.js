#!/usr/bin/env node
"use strict";

const fs = require("fs");
const path = require("path");
const H = require("./calc_history.js");

if (typeof H.push !== "function" || typeof H.step !== "function") {
  throw new Error("shipped calc_history.js did not export push/step");
}

let failed = 0;
function assert(cond, msg) {
  if (cond) console.log("ok  " + msg);
  else {
    failed += 1;
    console.log("FAIL  " + msg);
  }
}

const h1 = H.push([], "  2+2  ");
assert(h1[0] === "2+2" && h1.length === 1, "push trims and stores newest first");
const h2 = H.push(h1, "2+2");
assert(h2.length === 1 && h2 === h1, "duplicate of newest is a no-op (same array)");
const h3 = H.push(h2, "3*3");
assert(h3[0] === "3*3" && h3[1] === "2+2" && h3.length === 2, "newer expr is unshifted");
const h4 = H.push(h3, "2+2");
assert(h4[0] === "2+2" && h4[1] === "3*3" && h4.length === 2, "re-used expr moves to front");
assert(H.push(h4, "").length === 2, "empty expr is ignored");

const s0 = H.step(h4, "1+1", -1, 1);
assert(s0.index === 0 && s0.text === "2+2", "Up from draft loads newest history");
const s1 = H.step(h4, "1+1", 0, 1);
assert(s1.index === 1 && s1.text === "3*3", "second Up loads older history");
const s2 = H.step(h4, "1+1", 1, 1);
assert(s2.index === 1 && s2.text === "3*3", "Up at oldest stays");
const s3 = H.step(h4, "1+1", 1, -1);
assert(s3.index === 0 && s3.text === "2+2", "Down from older goes toward newer");
const s4 = H.step(h4, "1+1", 0, -1);
assert(s4.index === -1 && s4.text === "1+1", "Down from newest restores draft");
const s5 = H.step([], "9", -1, 1);
assert(s5.index === -1 && s5.text === "9", "empty history stays on draft");

const qml = fs.readFileSync(path.join(__dirname, "LauncherWindow.qml"), "utf8");
assert(qml.indexOf('import "calc_history.js" as CalcHist') !== -1, "LauncherWindow imports CalcHist");
assert(/function walkCalcHistory\(/.test(qml), "LauncherWindow walks calc history from keys");
assert(
  /Key_Up[\s\S]{0,220}walkCalcHistory\(1\)/.test(qml) && /Key_Down[\s\S]{0,220}walkCalcHistory\(-1\)/.test(qml),
  "calc mode Up/Down call walkCalcHistory before result-list nav"
);
assert(/special === "calc"[\s\S]{0,280}pushCalcHistory/.test(qml), "Enter on a calc result stores the expression");

if (failed > 0) {
  console.log("\n" + failed + " assertion(s) failed");
  process.exit(1);
}
console.log("\nall assertions passed");
