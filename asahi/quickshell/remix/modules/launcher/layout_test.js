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
  assert(r.cardWidth < r.screenW, label + ": cardWidth " + r.cardWidth + " < screenW " + r.screenW);
  assert(
    r.cardY + r.cardHeight + r.bottomGap <= r.screenH + 1,
    label + ": card + gaps fit in screenH"
  );
  assert(r.bodyHeight > 0, label + ": leftover bodyHeight " + r.bodyHeight + " > 0");
  assert(
    r.chrome + r.bodyHeight <= r.cardHeight,
    label + ": chrome " + r.chrome + " + body " + r.bodyHeight + " <= cardHeight " + r.cardHeight
  );
  assert(r.fontScale >= 1.05 && r.fontScale <= 1.80, label + ": fontScale " + r.fontScale + " in [1.05, 1.80]");
  assert(r.cardMargin >= 10 && r.cardMargin <= 28, label + ": cardMargin " + r.cardMargin + " in [10, 28]");
  assert(r.colSpacing >= 6 && r.colSpacing <= 18, label + ": colSpacing " + r.colSpacing + " in [6, 18]");

  const tiles = tileMetrics(r.bodyHeight, opts.tileCount, r.colMode, r.uiScale);
  const fitOrScroll = tiles.tileColumnHeight <= r.bodyHeight || tiles.tileScrollBudget <= r.bodyHeight;
  assert(
    fitOrScroll,
    label + ": 10-col tiles fit (" + tiles.tileColumnHeight + ") or scroll budget (" +
      tiles.tileScrollBudget + ") <= body " + r.bodyHeight
  );

  const viz = monitorsVizHeight(r.paneHeight, r);
  assert(viz === r.vizHeight, label + ": launcherLayout.vizHeight uses shipped monitorsVizHeight");
  assert(viz <= r.vizMax, label + ": vizHeight " + viz + " <= vizMax " + r.vizMax);
  if (r.vizWouldOverflow) {
    assert(
      viz < r.vizMax,
      label + ": viz " + viz + " < vizMax " + r.vizMax + " because max would overflow pane " + r.paneHeight
    );
  } else {
    console.log("ok  " + label + ": vizMax " + r.vizMax + " fits in pane " + r.paneHeight + " (viz=" + viz + ")");
  }
  const chromeMon = r.monToolbarH + r.monCaptionH + 3 * r.monSpacing;
  const listRoom = r.paneHeight - chromeMon - viz;
  assert(
    listRoom >= r.minList || viz <= r.vizMin,
    label + ": list room " + listRoom + " >= minList " + r.minList + " (or viz at floor)"
  );
  return r;
}

const cases = [
  { screenW: 1280, screenH: 800, tileCount: 10, sideActive: true, quickMode: true },
  { screenW: 1920, screenH: 1080, tileCount: 10, sideActive: true, quickMode: true },
  { screenW: 2560, screenH: 1440, tileCount: 10, sideActive: true, quickMode: true },
  { screenW: 3840, screenH: 2160, tileCount: 10, sideActive: true, quickMode: true }
];

const results = {};
for (const opts of cases) {
  results[opts.screenH] = runCase("screen=" + opts.screenW + "x" + opts.screenH, opts);
}

console.log("\n== adaptive size order ==");
const compact = results[800];
const mid = results[1080];
const large = results[1440];
const huge = results[2160];
assert(compact.cardWidth < mid.cardWidth, "1280×800 card narrower than 1080p (" + compact.cardWidth + " < " + mid.cardWidth + ")");
assert(mid.cardWidth < large.cardWidth, "1080p card narrower than 1440p (" + mid.cardWidth + " < " + large.cardWidth + ")");
assert(large.cardWidth < huge.cardWidth, "1440p card narrower than 4K (" + large.cardWidth + " < " + huge.cardWidth + ")");
assert(compact.fontScale <= mid.fontScale, "type on 800p <= 1080p (" + compact.fontScale + " <= " + mid.fontScale + ")");
assert(mid.fontScale <= large.fontScale, "type on 1080p <= 1440p (" + mid.fontScale + " <= " + large.fontScale + ")");
assert(Math.abs(mid.cardWidth - 1080) <= 8, "1080p side-active width stays near 1080 (got " + mid.cardWidth + ")");
const midOverview = launcherLayout({ screenW: 1920, screenH: 1080, sideActive: false, quickMode: false, tileCount: 10 });
assert(Math.abs(midOverview.cardWidth - 820) <= 8, "1080p overview width stays near 820 (got " + midOverview.cardWidth + ")");
assert(compact.cardWidth <= 1280 - 48, "800p card keeps side gaps (width " + compact.cardWidth + ")");
assert(huge.cardWidth >= 1500, "4K side-active card is not stuck at 1080 (got " + huge.cardWidth + ")");
assert(compact.cardMargin <= mid.cardMargin, "margins shrink on small displays");
assert(large.cardMargin >= mid.cardMargin, "margins grow on large displays");
assert(typeof shipped.uiScale === "function" && typeof shipped.cardWidthFor === "function",
  "layout module exports uiScale + cardWidthFor");
assert(shipped.cardWidthFor(1920, false) === 820, "cardWidthFor(1920, overview) is 820");
assert(shipped.cardWidthFor(1920, true) === 1080, "cardWidthFor(1920, side) is 1080");
assert(shipped.cardWidthFor(1280, true) < 1080, "cardWidthFor(1280, side) < 1080");
assert(shipped.cardWidthFor(2560, true) > 1080, "cardWidthFor(2560, side) > 1080");

runCase("tiny 800×600", { screenW: 800, screenH: 600, tileCount: 10, sideActive: true, quickMode: true });

console.log("\n== QML wiring (shipped LauncherWindow.qml) ==");
const qmlPath = path.join(__dirname, "LauncherWindow.qml");
const qml = fs.readFileSync(qmlPath, "utf8");
assert(
  qml.indexOf("LauncherGeom.launcherLayout") !== -1,
  "LauncherWindow.qml calls shipped LauncherGeom.launcherLayout"
);
assert(
  /screenW:\s*root\.launcherScreenW/.test(qml),
  "launcherLayout receives screenW so width can track the display"
);
assert(
  !/width:\s*root\.sideActive \? 1080 : 820/.test(qml),
  "card width is not the fixed 1080/820 pair"
);
assert(
  /width:\s*root\.launcherGeom\.cardWidth/.test(qml),
  "MenuCard width uses launcherGeom.cardWidth"
);
assert(
  /cardMargin:\s*root\.launcherGeom\.cardMargin/.test(qml),
  "MenuCard margin uses launcherGeom.cardMargin"
);
assert(
  /spacing:\s*root\.launcherGeom\.colSpacing/.test(qml),
  "launcher ColumnLayout spacing uses launcherGeom.colSpacing"
);
assert(
  /uiFontScale:\s*root\.launcherGeom\.fontScale/.test(qml),
  "uiFontScale comes from launcherGeom.fontScale (not a literal 1.4)"
);
assert(
  !/readonly property real uiFontScale:\s*1\.4/.test(qml),
  "uiFontScale is no longer hardcoded to 1.4"
);
assert(
  /tileMetrics\([\s\S]*root\.launcherGeom\.uiScale/.test(qml),
  "tileMetrics receives uiScale so Quick tiles grow/shrink with the display"
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
  /Layout\.maximumHeight:\s*root\.launcherGeom\.vizMax/.test(qml),
  "monitors viz max height uses adaptive launcherGeom.vizMax"
);
assert(
  /Layout\.fillHeight:\s*false/.test(qml) && /launcherGeom\.monListMax/.test(qml),
  "monitor list sizes to content (capped) so leftover height goes to the preview"
);
assert(
  /const s = Math\.min\(/.test(qml),
  "monitors viz paints with uniform scale (keeps logical aspect)"
);
assert(
  /h >= 72/.test(qml),
  "monitors viz scales label density to box height"
);
assert(
  /id:\s*quickSide/.test(qml),
  "quick sidebar is a Flickable (quickSide) so leftover tiles can scroll"
);
assert(
  /Layout\.preferredHeight:\s*implicitHeight/.test(qml),
  "launcher ColumnLayout prefers implicitHeight for chrome (header/hint)"
);
assert(
  /rowHTall/.test(qml) && /iconSlot/.test(qml) && /rowPad/.test(qml),
  "list rows, icon slot, and row padding come from adaptive geom"
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
