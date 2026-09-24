#!/usr/bin/env node
"use strict";

const fs = require("fs");
const path = require("path");

const shipped = require("./wallpaper_thumbs.js");
if (typeof shipped.carouselFrame !== "function") {
  throw new Error("shipped wallpaper_thumbs.js did not export carouselFrame");
}

let failed = 0;
function assert(cond, msg) {
  if (cond) console.log("ok  " + msg);
  else {
    failed += 1;
    console.log("FAIL  " + msg);
  }
}

console.log("== carouselFrame (Ryoku window fan, scaled to the host) ==");
if (typeof shipped.carouselWindow !== "function" || typeof shipped.carouselContains !== "function") {
  throw new Error("shipped wallpaper_thumbs.js did not export carouselWindow/carouselContains");
}

const zero = shipped.carouselFrame(0);
assert(zero.expandedW === 0 && zero.height === 0 && zero.step === 0, "viewW 0 → empty frame");
assert(shipped.carouselFrame(-10).expandedW === 0, "negative viewW → empty frame");

const ref = shipped.carouselFrame(1669);
console.log("ref " + JSON.stringify(ref));
assert(ref.expandedW === 768 && ref.expandedH === 432, "wide host keeps Ryoku's 768×432 centre window");
assert(ref.sliceW === 108 && ref.sliceH === 390, "slices keep Ryoku's 108×390");
assert(ref.gap === -30 && ref.skew === 28, "slices overlap by 30 and lean by 28");
assert(ref.step === 78 && ref.step > 0, "step stays positive so neighbours do not stack");

function checkFan(viewW, count, index) {
  const f = shipped.carouselFrame(viewW);
  assert(f.expandedW > 0 && f.expandedW <= viewW, "viewW " + viewW + ": centre fits the host");
  assert(f.expandedW > f.sliceW, "viewW " + viewW + ": centre window is wider than a slice");
  assert(f.sliceH <= f.expandedH && f.step > 0 && f.skew < f.sliceW, "viewW " + viewW + ": slice fits under the window");
  if (f.expandedW >= 64) {
    const ratio = f.expandedW / f.expandedH;
    assert(Math.abs(ratio - 16 / 9) < 0.03, "viewW " + viewW + ": centre is 16:9 (got " + ratio.toFixed(3) + ")");
  }
  const mid = shipped.carouselWindow(f, count, index, index);
  const left = shipped.carouselWindow(f, count, index, index - 1);
  const right = shipped.carouselWindow(f, count, index, index + 1);
  assert(mid.selected && mid.nearby, "viewW " + viewW + ": pick is the centre window");
  assert(mid.x === (f.viewW - f.expandedW) / 2, "viewW " + viewW + ": centre window is centred");
  assert(Math.abs((left.x + left.w) - (mid.x - f.gap)) < 0.01, "viewW " + viewW + ": left slice tucks under the centre");
  assert(Math.abs((mid.x + mid.w) - (right.x - f.gap)) < 0.01, "viewW " + viewW + ": right slice tucks under the centre");
  assert(mid.z > left.z && mid.z > right.z, "viewW " + viewW + ": centre paints above the slices");
  assert(left.h < mid.h && left.y > mid.y, "viewW " + viewW + ": slices are shorter and vertically centred");
}

for (const viewW of [420, 800, 1080, 1464, 1669]) checkFan(viewW, 7, 3);

const f1000 = shipped.carouselFrame(1000);
assert(shipped.carouselWindow(f1000, 4, 99, 3).selected, "index past the end clamps onto the last window");
assert(shipped.carouselWindow(f1000, 4, -5, 0).selected, "negative index clamps onto the first window");
assert(!shipped.carouselWindow(f1000, 0, 0, 0).nearby, "empty list has no windows");
assert(shipped.carouselWindow(f1000, 20, 10, 10 + shipped.CAROUSEL_NEARBY).nearby, "a window 8 away is still drawn");
assert(!shipped.carouselWindow(f1000, 20, 10, 10 + shipped.CAROUSEL_NEARBY + 1).nearby, "a window 9 away is not drawn");

assert(!shipped.carouselContains(28, 108, 390, 0, 0), "top-left corner is outside the lean");
assert(shipped.carouselContains(28, 108, 390, 40, 0), "top edge inside the lean is a hit");
assert(!shipped.carouselContains(28, 108, 390, 100, 380), "bottom-right corner is outside the lean");
assert(shipped.carouselContains(28, 108, 390, 50, 380), "bottom edge inside the lean is a hit");

console.log("\n== launcher opens the one picker, it does not clone it ==");
const qml = fs.readFileSync(path.join(__dirname, "../launcher/LauncherWindow.qml"), "utf8");
assert(
  /key:\s*"wallpaper".*ipc:\s*"wallpaper"/.test(qml),
  "the Wallpapers deck entry dispatches to the wallpaper IpcHandler"
);
assert(
  !/mode:\s*"wallpaper"/.test(qml),
  "it is not an in-launcher pane any more"
);
for (const gone of ["quickWallpaperComp", "quickWallpaperRoot", "wallCarousel", "quickWallKey", "WallThumbs"]) {
  assert(qml.indexOf(gone) === -1, "the duplicated pane's " + gone + " is gone");
}
assert(
  qml.indexOf("Wallpaper.DefaultTheme") !== -1,
  "the wallpaper import is still pulled in for the palette"
);
assert(
  qml.indexOf("WallpaperCarousel") === -1 && qml.indexOf("WallpaperPalette") === -1,
  "the launcher no longer builds its own carousel or palette strip"
);
// The picker is standalone: no Quick tile, still reachable by typing.
const hiddenBlock = qml.slice(qml.indexOf("quickDeckHidden"), qml.indexOf("quickDeckHidden") + 600);
assert(/\bwallpaper:\s*true/.test(hiddenBlock), "Wallpapers is not a Quick deck tile");
assert(
  /aliases:\s*\["wall", "paper"\]/.test(qml),
  "it is still in quickActions, so the launcher search finds it"
);

// The rule that made the tile show "select a quick tile" when it was left
// visible: quickPaneKey falls back to t.key, not just t.mode, so EVERY visible
// deck tile asks quickDetailFor for a pane. A tile with only ipc:/command: has
// none and drops to quickDefaultComp's empty state. Keep those out of the deck.
const actionsBlock = qml.slice(qml.indexOf("readonly property var quickActions"), qml.indexOf("readonly property var quickTiles"));
const paneless = [];
for (const line of actionsBlock.split("\n")) {
  const key = (line.match(/\{\s*key:\s*"([a-z-]+)"/) || [])[1];
  if (!key) continue;
  if (!/\bmode:\s*"/.test(line)) paneless.push(key);
}
assert(paneless.length > 0, "found the paneless quickActions entries (" + paneless.length + ")");
for (const key of paneless) {
  assert(
    new RegExp("\\b" + key.replace("-", "\\-") + "\\b\\s*:\\s*true|\"" + key + "\"\\s*:\\s*true").test(hiddenBlock),
    "paneless action '" + key + "' is hidden from the deck (it has no pane to show)"
  );
}

console.log("\n== WallpaperCarousel.qml ==");
const car = fs.readFileSync(path.join(__dirname, "WallpaperCarousel.qml"), "utf8");
assert(
  /WallThumbs\.carouselWindow\(\s*root\.frame/.test(car),
  "WallpaperCarousel places each window via shipped carouselWindow"
);
assert(
  /WallThumbs\.carouselFrame\(/.test(car) && /carouselContains\(/.test(car),
  "frame size and the parallelogram hit test come from the shared script"
);
assert(
  !/ListView\s*\{/.test(car),
  "WallpaperCarousel is not a ListView (that clipped neighbours in Quick)"
);
assert(
  /function pick\(\) \{ selected \? root\.activate\(\) : root\.go\(index\) \}/.test(car),
  "clicking the centre window applies; clicking a slice selects it"
);
assert(
  !/width:\s*frame\.width/.test(car) && !/width:\s*tileFrame/.test(car),
  "carousel tiles do not host a frame-width path caption"
);
assert(
  /viewW/.test(car),
  "carousel documents viewW as the host viewport"
);

console.log("\n== WallpaperManager.qml ==");
const mgr = fs.readFileSync(path.join(__dirname, "WallpaperManager.qml"), "utf8");
assert(
  /viewW:\s*parent\.width/.test(mgr),
  "compact picker viewW is the host column width"
);
assert(
  !/itemW:\s*Math\.floor\(\s*width\s*\/\s*3\s*\)/.test(mgr),
  "compact picker does not size tiles from ListView width"
);
assert(
  mgr.indexOf("WallpaperTermPreview") === -1,
  "compact picker has no fake Ghostty ls/src mock"
);
assert(
  !fs.existsSync(path.join(__dirname, "WallpaperTermPreview.qml")),
  "WallpaperTermPreview.qml is gone"
);
assert(
  fs.readFileSync(path.join(__dirname, "qmldir"), "utf8").indexOf("WallpaperTermPreview") === -1,
  "qmldir does not register WallpaperTermPreview"
);

const svc = fs.readFileSync(path.join(__dirname, "WallpaperService.qml"), "utf8");
assert(
  /waitForEnd:\s*true/.test(svc) && /DefaultTheme\.applyJson/.test(svc),
  "preview process waits for autotheme JSON then applyJson"
);
assert(
  /previewWaitMs:\s*70/.test(svc) && /interval:\s*root\.previewWaitMs/.test(svc),
  "armed preview is real-time — the debounce only swallows key-repeat"
);
assert(
  /id:\s*previewThemeDelay/.test(svc) && /previewThemeDelayMs:\s*100/.test(svc),
  "theme reload is delayed after the wallpaper fade starts"
);
assert(
  /asahi-wall-preview/.test(mgr) && /previewFadeMs/.test(mgr) && /Easing\.OutCubic/.test(mgr),
  "preview wallpaper fades in on a pass-through Bottom layer"
);

if (failed > 0) {
  console.log("\n" + failed + " assertion(s) failed");
  process.exit(1);
}
console.log("\nall assertions passed");
