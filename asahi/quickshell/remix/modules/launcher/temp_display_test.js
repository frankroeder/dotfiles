#!/usr/bin/env node
"use strict";

const fs = require("fs");
const path = require("path");

const shipped = require("./temp_display.js");
if (typeof shipped.parseTemperatures !== "function" || typeof shipped.tempDisplayRows !== "function") {
  throw new Error("shipped temp_display.js did not export parseTemperatures/tempDisplayRows");
}

let failed = 0;
function assert(cond, msg) {
  if (cond) console.log("ok  " + msg);
  else {
    failed += 1;
    console.log("FAIL  " + msg);
  }
}

function rowTemps(row) {
  const nums = [];
  if (row.value !== null && row.value !== undefined) nums.push(row.value);
  const kids = row.sensors || [];
  for (let i = 0; i < kids.length; i++) {
    if (kids[i].value !== null && kids[i].value !== undefined) nums.push(kids[i].value);
  }
  return nums;
}

const fixturePath = path.join(__dirname, "fixtures", "asahi_temperature.stdout");
const stdout = fs.readFileSync(fixturePath, "utf8");
console.log("fixture " + fixturePath + " bytes " + stdout.length);

const parsed = shipped.parseTemperatures(stdout);
const multi = (parsed.groups || []).filter(function (g) { return (g.sensors || []).length >= 2; });
console.log("groups " + parsed.groups.length + " multi " + multi.length);
assert(multi.length >= 1, "fixture has a group with ≥2 sensors");

const rows = shipped.tempDisplayRows(parsed.groups);
console.log("display rows " + rows.length);
assert(rows.length > 0, "display model is non-empty");

let sawMultiGroup = false;
for (let i = 0; i < rows.length; i++) {
  const row = rows[i];
  assert(row.avg === undefined, "row[" + i + "] has no avg field");
  if (row.kind === "group") {
    sawMultiGroup = true;
    assert(row.value === null, "group row has no headline temperature (not avg)");
    const kids = row.sensors || [];
    assert(kids.length >= 2, "group row has nested sensors");
    for (let k = 0; k < kids.length; k++) {
      assert(kids[k].avg === undefined, "sensor child[" + k + "] has no avg");
      assert(typeof kids[k].value === "number", "sensor child[" + k + "] has one current value");
    }
  } else {
    assert(typeof row.value === "number", "item row[" + i + "] has exactly one temperature");
    assert((row.sensors || []).length === 0, "item row[" + i + "] has no nested sensors");
  }
}
assert(sawMultiGroup, "multi-sensor group is represented without an avg headline");

const qmlPath = path.join(__dirname, "LauncherWindow.qml");
const qml = fs.readFileSync(qmlPath, "utf8");
assert(qml.indexOf("TempDisplay.tempDisplayRows") !== -1, "LauncherWindow.qml uses shipped tempDisplayRows");
assert(!/avg\s*"\s*\+\s*modelData\.avg/.test(qml), "temp pane template has no avg + °C pair");
assert(!/"avg " \+/.test(qml), "temp pane template does not render avg headline");

if (failed > 0) {
  console.log("\n" + failed + " assertion(s) failed");
  process.exit(1);
}
console.log("\nall assertions passed");
