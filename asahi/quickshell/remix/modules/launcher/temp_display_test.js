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

assert(parsed.heatpipe && parsed.heatpipe.value === 4.22, "heatpipe watts from SMC power rail");
assert((parsed.power || []).length >= 2, "power rails parsed");
assert((parsed.fans || []).length === 2, "both fans parsed");
assert(parsed.fans[0].value === 0 && parsed.fans[0].min === 2317, "idle fan keeps 0 RPM and min");
assert(parsed.fans[1].value === 2400 && parsed.fans[1].max === 6800, "spinning fan keeps RPM window");
assert(parsed.hottest && parsed.hottest.value === 44.20, "hottest is still the exposed °C peak");
assert(parsed.sensors.every(function (s) { return s.name !== "macsmc_hwmon" || s.label.indexOf("/") !== 0 }),
  "trailing Hottest: summary line is not parsed as a sensor");
assert(parsed.sensors.length === 12, "12 sensors (no duplicate from the Hottest: summary)");

const withPath = rows.filter(function (r) { return r.path || (r.sensors || []).some(function (s) { return s.path; }); });
assert(withPath.length === rows.length, "every display row keeps a sensor path for live updates");
const again = shipped.tempDisplayRows(parsed.groups);
assert(shipped.structureKey(rows) === shipped.structureKey(again), "structure key is stable across identical polls");
const bumped = shipped.tempDisplayRows(parsed.groups);
bumped[0].value = (bumped[0].value || 0) + 1;
if ((bumped[0].sensors || []).length) bumped[0].sensors[0].value += 1;
assert(shipped.structureKey(rows) === shipped.structureKey(bumped), "value-only changes do not retarget rows");
const vals = shipped.valuesMap(rows);
assert(Object.keys(vals).length >= rows.length, "values map covers each current reading");

const qmlPath = path.join(__dirname, "panes/TempPane.qml");
const qml = fs.readFileSync(qmlPath, "utf8");
const src = fs.readFileSync(path.join(__dirname, "temp_display.js"), "utf8");
assert(src.indexOf("\\0") === -1, "structureKey must not join on NUL (QML drops the function)");
assert(qml.indexOf("No sensors parsed") === -1, "hero does not say 'No sensors parsed'");
assert(qml.indexOf("hottestSensor = parsed.hottest") < qml.indexOf("TempDisplay.structureKey"),
  "hero data is applied before structureKey so a QML helper miss still shows temps");
assert(qml.indexOf("TempDisplay.tempDisplayRows") !== -1, "TempPane.qml uses shipped tempDisplayRows");
assert(qml.indexOf("SMC Power") === -1, "TempPane does not host SMC power rails");
assert(qml.indexOf("tempValues") !== -1 && qml.indexOf("barFill.ready") !== -1, "heat bars keep delegates and animate from the last width");
assert(!/text:\s*"Fans"/.test(qml), "Fans card is not a separate group");
assert(qml.indexOf("tempFans") !== -1 && qml.indexOf("tempUpdated") !== -1, "fan rows sit on the hero pill row");
assert(!/avg\s*"\s*\+\s*modelData\.avg/.test(qml), "temp pane template has no avg + °C pair");
assert(!/"avg " \+/.test(qml), "temp pane template does not render avg headline");
const batQml = fs.readFileSync(path.join(__dirname, "panes/BatteryPane.qml"), "utf8");
assert(batQml.indexOf("SMC Power") !== -1, "BatteryPane hosts SMC power rails");
assert(batQml.indexOf("asahi-temperature") !== -1, "BatteryPane reads asahi-temperature --json");

if (failed > 0) {
  console.log("\n" + failed + " assertion(s) failed");
  process.exit(1);
}
console.log("\nall assertions passed");
