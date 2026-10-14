#!/usr/bin/env node
"use strict";

// Hub (Quick > Dashboard) layout guards on LauncherWindow.qml.
const fs = require("fs");
const path = require("path");

let failed = 0;
function assert(cond, msg) {
  if (cond) console.log("ok  " + msg);
  else {
    failed += 1;
    console.log("FAIL  " + msg);
  }
}

const qmlPath = path.join(__dirname, "LauncherWindow.qml");
const qml = fs.readFileSync(qmlPath, "utf8");
// The hub shows the OS as a logo tile (caelestia User card), not fastfetch's ASCII art.
assert(qml.indexOf("ffLogoText") === -1, "hub no longer binds the fastfetch ASCII logo");
assert(
  qml.indexOf('indexOf("@")') === -1,
  "hub no longer drops every line containing @"
);
const infoBody = qml.match(/id:\s*ffInfoBody[\s\S]{0,250}/);
assert(!!infoBody, "hub declares ffInfoBody");
const factsCard = qml.match(/\/\/ Facts card[\s\S]{0,700}id:\s*ffInfoBody/);
assert(
  !!factsCard && /Layout\.fillHeight:\s*true/.test(factsCard[0]),
  "hub facts card takes the spare pane height (nothing piles up under it)"
);
assert(
  /id:\s*ffInfoBody[\s\S]{0,200}anchors\.verticalCenter:\s*parent\.verticalCenter/.test(qml),
  "hub fact rows stay centred in the card"
);
assert(
  /rowSpacing:[\s\S]{0,40}Math\.min\(2 \* baseGap,\s*Math\.max\(baseGap,/.test(qml),
  "hub fact row gap flexes between baseGap and 2x baseGap (never the old unbounded stretch)"
);
const valueBlock = qml.match(/text:\s*rowValue[\s\S]{0,800}/);
assert(!!valueBlock, "hub value Text binds rowValue");
assert(
  /wrapMode:\s*width\s*>\s*80\s*\?\s*Text\.WordWrap\s*:\s*Text\.NoWrap/.test(valueBlock[0]),
  "hub info values wrap into leftover well height once the column has width"
);
assert(
  /maximumLineCount:\s*width\s*>\s*80\s*\?\s*2\s*:\s*1/.test(valueBlock[0]),
  "hub info values may wrap two lines in a shared grid row"
);
assert(
  /id:\s*ffInfoBody[\s\S]{0,80}GridLayout/.test(qml) || /GridLayout\s*\{\s*id:\s*ffInfoBody/.test(qml),
  "hub facts sit in a shared GridLayout so wrapped rows stay aligned"
);
assert(
  /horizontalAlignment:\s*Text\.AlignLeft/.test(qml),
  "hub fact labels are left-aligned (Display must not become Displ...)"
);
assert(
  /ffLabelWidth:\s*Math\.max\(68,\s*Math\.round\(root\.fontPx\(10\)/.test(qml),
  "hub fact label column tracks the fact text size"
);
assert(
  /ffIconWidth:\s*Math\.max\(32,\s*root\.fontPx\(18\)/.test(qml) && /color:\s*Qt\.alpha\(modelData\.accent/.test(qml),
  "hub fact icons sit in tinted tiles that scale with the type"
);
assert(
  /Layout\.minimumHeight:\s*Math\.round\(root\.launcherGeom\.rowHTall \* 2\.7\)/.test(qml)
    && /Layout\.maximumHeight:\s*Math\.round\(root\.launcherGeom\.rowHTall \* 3\.6\)/.test(qml),
  "hub meters height follows adaptive rowHTall (2.7–3.6 rows)"
);

if (failed > 0) {
  console.log("\n" + failed + " assertion(s) failed");
  process.exit(1);
}
console.log("\nall assertions passed");
