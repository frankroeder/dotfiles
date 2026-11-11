#!/usr/bin/env node
"use strict";

// Drives the iconGlyph block in the shipped Battery.qml. Pending-charge must use that
// file's charging ladder (battery + bolt). U+F1E6 is a plug that Noto Sans falls through
// to New Computer Modern, which draws it as a capital C.

const fs = require("fs");
const path = require("path");

const qmlPath = path.join(__dirname, "Battery.qml");
const qml = fs.readFileSync(qmlPath, "utf8");

let failed = 0;
function eq(got, expected, msg) {
  if (got === expected) console.log("ok  " + msg);
  else {
    failed += 1;
    console.log("FAIL  " + msg + " got=" + JSON.stringify(got) + " expected=" + JSON.stringify(expected));
  }
}
function ok(cond, msg) {
  eq(!!cond, true, msg);
}

function iconGlyphBlock(src) {
  const at = src.indexOf("property string iconGlyph:");
  if (at < 0) throw new Error("iconGlyph missing");
  const brace = src.indexOf("{", at);
  let depth = 0;
  for (let i = brace; i < src.length; i++) {
    if (src[i] === "{") depth++;
    else if (src[i] === "}") {
      depth--;
      if (depth === 0) return src.slice(brace, i + 1);
    }
  }
  throw new Error("iconGlyph block not closed");
}

function namedArrays(block) {
  const arrays = {};
  const re = /(?:const|let|var)\s+([A-Za-z_]\w*)\s*=\s*(\[(?:"(?:\\.|[^"\\])*"(?:\s*,\s*"(?:\\.|[^"\\])*")*)\])/g;
  for (const m of block.matchAll(re)) arrays[m[1]] = JSON.parse(m[2]);
  return arrays;
}

function ladderFromExpr(expr, arrays) {
  const inline = expr.match(/^(\[(?:"(?:\\.|[^"\\])*"(?:\s*,\s*"(?:\\.|[^"\\])*")*)\])\s*\[i\]$/);
  if (inline) return JSON.parse(inline[1]);
  const name = expr.match(/^([A-Za-z_]\w*)\s*\[i\]$/);
  if (!name || !arrays[name[1]]) throw new Error("not a ladder: " + expr);
  return arrays[name[1]];
}

function returnExpr(block, stateName) {
  const re = new RegExp("UPowerDeviceState\\." + stateName + "\\b[\\s\\S]*?return\\s+([^\\n]+)");
  const m = block.match(re);
  if (!m) throw new Error("no return for " + stateName);
  return m[1].trim().replace(/;?\s*$/, "");
}

const block = iconGlyphBlock(qml);
const arrays = namedArrays(block);
const chargingLadder = ladderFromExpr(returnExpr(block, "Charging"), arrays);
const pendingExpr = returnExpr(block, "PendingCharge");
const pendingLadder = /^(\[.*\]|[A-Za-z_]\w*)\s*\[i\]$/.test(pendingExpr) ? ladderFromExpr(pendingExpr, arrays) : null;

let fallbackExpr = null;
for (const m of block.matchAll(/return\s+(\[(?:"(?:\\.|[^"\\])*"(?:\s*,\s*"(?:\\.|[^"\\])*")*)\]|[A-Za-z_]\w*)\s*\[i\]/g)) {
  fallbackExpr = m[1] + "[i]";
}
if (!fallbackExpr) throw new Error("no discharging ladder");
const dischargingLadder = ladderFromExpr(fallbackExpr, arrays);

const UPowerDeviceState = {
  Charging: "Charging",
  FullyCharged: "FullyCharged",
  PendingCharge: "PendingCharge",
  Discharging: "Discharging",
};

function glyph(percentage, state) {
  const dev = { state: UPowerDeviceState[state] };
  return new Function("percentage", "dev", "UPowerDeviceState", block)(percentage, dev, UPowerDeviceState);
}

ok(chargingLadder.length === 10, "charging ladder has ten steps");
ok(dischargingLadder.length === 10, "discharging ladder has ten steps");
ok(new Set(chargingLadder).size === 10, "charging steps are distinct");
ok(chargingLadder.every((g) => !dischargingLadder.includes(g)), "charging ladder is not the discharging ladder");
ok(pendingLadder !== null && pendingLadder.every((g, i) => g === chargingLadder[i]), "pending-charge return is the charging ladder");

const levels = [[0, 0], [9, 0], [10, 1], [25, 2], [71, 7], [99, 9], [100, 9]];
for (const [pct, idx] of levels) {
  const pending = glyph(pct, "PendingCharge");
  eq(pending, chargingLadder[idx], "pending-charge " + pct + "% is charging[" + idx + "]");
  eq(pending === "\uf1e6", false, "pending-charge " + pct + "% is not U+F1E6");
  eq(glyph(pct, "Charging"), chargingLadder[idx], "charging " + pct + "% is charging[" + idx + "]");
  eq(glyph(pct, "Discharging"), dischargingLadder[idx], "discharging " + pct + "% unchanged");
  ok(qml.includes(pending), "pending glyph is a literal in Battery.qml");
}

const fullExpr = returnExpr(block, "FullyCharged");
const fullLit = fullExpr.match(/^"((?:\\.|[^"\\])*)"$/);
if (!fullLit) throw new Error("fully-charged return is not one glyph: " + fullExpr);
const fullGlyph = JSON.parse(fullExpr);
eq(glyph(0, "FullyCharged"), fullGlyph, "fully charged at 0% is its literal");
eq(glyph(71, "FullyCharged"), fullGlyph, "fully charged ignores the level");
eq(fullGlyph === "\uf1e6", false, "fully charged is not U+F1E6");

ok(!qml.includes("\\uf1e6"), "Battery.qml has no \\\\uf1e6 escape");
ok(!qml.includes("\uf1e6"), "Battery.qml has no U+F1E6 character");
ok(qml.includes('text: root.percentage + "%"'), "chip still shows the percent");
ok(qml.includes("root.percentage <= 10 ? Style.red : (root.percentage <= 20 ? Style.orange : Style.green)"), "color rules unchanged");
ok(qml.includes('quickRequested("battery")'), "click still opens the battery pane");

const at71 = glyph(71, "PendingCharge");
console.log("pending 71% U+" + at71.codePointAt(0).toString(16).toUpperCase());

if (failed) {
  console.log(failed + " failed");
  process.exit(1);
}
console.log("all passed");
