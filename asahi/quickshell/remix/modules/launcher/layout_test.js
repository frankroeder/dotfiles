#!/usr/bin/env node
"use strict";

const fs = require("fs");
const path = require("path");

const shipped = require("./launcher_layout.js");
const launcherLayout = shipped.launcherLayout;
const tileMetrics = shipped.tileMetrics;
const monitorsVizHeight = shipped.monitorsVizHeight;

if (typeof launcherLayout !== "function") {
  throw new Error("shipped launcher_layout.js did not export launcherLayout");
}

let failed = 0;
function assert(cond, msg) {
  if (cond) {
    console.log("ok  " + msg);
  } else {
    failed += 1;
    console.log("FAIL  " + msg);
  }
}

function runCase(label, opts) {
  console.log("\n== " + label + " ==");
  console.log("input " + JSON.stringify(opts));
  const r = launcherLayout(opts);
  console.log("result " + JSON.stringify(r, null, 2));

  assert(r.cardBottom < r.screenH, label + ": cardBottom " + r.cardBottom + " < screenH " + r.screenH);
  assert(r.bodyHeight > 0, label + ": leftover bodyHeight " + r.bodyHeight + " > 0");
  assert(
    r.chrome + r.bodyHeight <= r.cardHeight,
    label + ": chrome " + r.chrome + " + body " + r.bodyHeight + " <= cardHeight " + r.cardHeight
  );

  const tiles = tileMetrics(r.bodyHeight, opts.tileCount, r.colMode);
  const fitOrScroll = tiles.tileColumnHeight <= r.bodyHeight || tiles.tileScrollBudget <= r.bodyHeight;
  assert(
    fitOrScroll,
    label + ": 10-col tiles fit (" + tiles.tileColumnHeight + ") or scroll budget (" +
      tiles.tileScrollBudget + ") <= body " + r.bodyHeight
  );

  const viz = monitorsVizHeight(r.paneHeight);
  assert(viz === r.vizHeight, label + ": launcherLayout.vizHeight uses shipped monitorsVizHeight");
  assert(viz <= shipped.VIZ_MAX, label + ": vizHeight " + viz + " <= vizMax " + shipped.VIZ_MAX);
  if (r.vizWouldOverflow) {
    assert(
      viz < shipped.VIZ_MAX,
      label + ": viz " + viz + " < rigid 420 because 420 would overflow pane " + r.paneHeight
    );
  } else {
    console.log("ok  " + label + ": 420 fits in pane " + r.paneHeight + " (viz=" + viz + ")");
  }
  return r;
}

const cases = [
  { screenH: 1260, tileCount: 10, sideActive: true, quickMode: true },
  { screenH: 1080, tileCount: 10, sideActive: true, quickMode: true },
  { screenH: 800, tileCount: 10, sideActive: true, quickMode: true }
];

for (const opts of cases) {
  runCase("screenH=" + opts.screenH, opts);
}

console.log("\n== QML wiring (shipped LauncherWindow.qml) ==");
const qmlPath = path.join(__dirname, "LauncherWindow.qml");
const qml = fs.readFileSync(qmlPath, "utf8");
assert(
  qml.indexOf("LauncherGeom.launcherLayout") !== -1,
  "LauncherWindow.qml calls shipped LauncherGeom.launcherLayout"
);
assert(
  !/height:\s*visible \? Math\.max\(300,\s*launcherPanel\.height\s*\*/.test(qml),
  "listArea is not sized from launcherPanel.height overlay fraction"
);
assert(
  !/Layout\.preferredHeight:\s*420\b/.test(qml),
  "monitors viz does not use rigid Layout.preferredHeight: 420"
);
assert(
  /LauncherGeom\.monitorsVizHeight/.test(qml),
  "monitors viz height comes from shipped monitorsVizHeight"
);
assert(
  /id:\s*quickSide/.test(qml),
  "quick sidebar is a Flickable (quickSide) so leftover tiles can scroll"
);
assert(
  /Layout\.preferredHeight:\s*implicitHeight/.test(qml),
  "launcher ColumnLayout prefers implicitHeight for chrome (header/hint)"
);

console.log("\n== menu chrome implicitHeight (ColumnLayout) ==");
const headerQml = fs.readFileSync(path.join(__dirname, "../menu/MenuHeader.qml"), "utf8");
const dividerQml = fs.readFileSync(path.join(__dirname, "../menu/MenuDivider.qml"), "utf8");
const hintQml = fs.readFileSync(path.join(__dirname, "../menu/MenuHintRow.qml"), "utf8");
assert(
  /^\s*implicitHeight:/m.test(headerQml),
  "MenuHeader.qml assigns implicitHeight so ColumnLayout does not treat chrome as 0"
);
assert(
  /^\s*implicitHeight:\s*1\b/m.test(dividerQml),
  "MenuDivider.qml assigns implicitHeight: 1 so ColumnLayout allocates the hairline"
);
assert(
  /^\s*implicitHeight:/m.test(hintQml),
  "MenuHintRow.qml assigns implicitHeight so the footer stays in the card layout"
);
assert(
  headerQml.indexOf("height: implicitHeight") !== -1,
  "MenuHeader height stays in sync with implicitHeight (Column + ColumnLayout)"
);

if (failed > 0) {
  console.log("\n" + failed + " assertion(s) failed");
  process.exit(1);
}
console.log("\nall assertions passed");
