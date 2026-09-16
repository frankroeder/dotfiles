#!/usr/bin/env node
"use strict";

const fs = require("fs");
const path = require("path");

const shipped = require("./wallpaper_thumbs.js");
if (typeof shipped.carouselItemWidth !== "function") {
  throw new Error("shipped wallpaper_thumbs.js did not export carouselItemWidth");
}

let failed = 0;
function assert(cond, msg) {
  if (cond) console.log("ok  " + msg);
  else {
    failed += 1;
    console.log("FAIL  " + msg);
  }
}

console.log("== carouselItemWidth (host viewport, three slots) ==");
const views = [420, 640, 800, 1080];
for (let i = 0; i < views.length; i++) {
  const viewW = views[i];
  const itemW = shipped.carouselItemWidth(viewW);
  console.log("viewW " + viewW + " itemW " + itemW);
  assert(itemW > 0, "viewW " + viewW + ": itemW " + itemW + " > 0");
  assert(
    3 * itemW <= viewW,
    "viewW " + viewW + ": 3 * itemW (" + (3 * itemW) + ") <= viewW"
  );
  assert(
    itemW * 2 <= viewW,
    "viewW " + viewW + ": itemW " + itemW + " is not ≈ viewW (neighbours stay in-view)"
  );
  assert(
    itemW === Math.floor(viewW / 3),
    "viewW " + viewW + ": itemW is floor(viewW/3)"
  );
}

assert(shipped.carouselItemWidth(0) === 0, "viewW 0 → itemW 0");
assert(shipped.carouselItemWidth(-10) === 0, "negative viewW → itemW 0");

console.log("\n== Quick wallpaper source (LauncherWindow.qml) ==");
const qml = fs.readFileSync(path.join(__dirname, "../launcher/LauncherWindow.qml"), "utf8");
const start = qml.indexOf("Component { id: quickWallpaperComp");
assert(start !== -1, "quickWallpaperComp exists");
const nextComp = qml.indexOf("\n  Component {", start + 10);
const wp = qml.slice(start, nextComp === -1 ? qml.length : nextComp);

assert(
  /WallThumbs\.carouselItemWidth\(\s*wallHost\.width\s*\)/.test(wp),
  "Quick carousel itemW comes from WallThumbs.carouselItemWidth(wallHost.width)"
);
assert(
  /viewW:\s*wallHost\.width/.test(wp),
  "Quick carousel viewW is the host viewport, not the ListView width"
);
assert(
  !/itemW:\s*Math\.floor\(\s*width\s*\/\s*3\s*\)/.test(wp),
  "Quick carousel does not size tiles from ListView width"
);
assert(
  /id:\s*wallPathCaption/.test(wp) && /Layout\.fillWidth:\s*true/.test(wp.slice(wp.indexOf("id: wallPathCaption"), wp.indexOf("id: wallPathCaption") + 220)),
  "current-path caption is pane-width (Layout.fillWidth)"
);
assert(
  !/width:\s*tileFrame/.test(wp) && !/width:\s*frame\.width/.test(wp),
  "Quick path caption is not width: tileFrame / frame.width"
);
assert(
  /Wallpaper\.WallpaperTermPreview/.test(wp) && /id:\s*wallTermPreview/.test(wp),
  "Quick wallpaper hosts WallpaperTermPreview so the palette change is visible in-pane"
);

console.log("\n== WallpaperCarousel.qml ==");
const car = fs.readFileSync(path.join(__dirname, "WallpaperCarousel.qml"), "utf8");
assert(
  /WallThumbs\.carouselItemWidth\(\s*viewW\s*\)/.test(car),
  "WallpaperCarousel default itemW uses shipped carouselItemWidth(viewW)"
);
assert(
  !/width:\s*frame\.width/.test(car) && !/width:\s*tileFrame/.test(car),
  "carousel tiles do not host a frame-width path caption"
);
assert(
  /Host viewport width/.test(car) || /viewW/.test(car),
  "carousel documents viewW as the host viewport"
);

console.log("\n== WallpaperManager.qml ==");
const mgr = fs.readFileSync(path.join(__dirname, "WallpaperManager.qml"), "utf8");
assert(
  /WallThumbs\.carouselItemWidth\(\s*parent\.width\s*\)/.test(mgr),
  "compact picker itemW uses carouselItemWidth(parent.width)"
);
assert(
  !/itemW:\s*Math\.floor\(\s*width\s*\/\s*3\s*\)/.test(mgr),
  "compact picker does not size tiles from ListView width"
);
assert(
  /WallpaperTermPreview/.test(mgr),
  "compact picker hosts WallpaperTermPreview"
);

const term = fs.readFileSync(path.join(__dirname, "WallpaperTermPreview.qml"), "utf8");
assert(
  /Style\.themeGeneration/.test(term) && /Style\.bg/.test(term) && /Style\.green/.test(term),
  "term preview binds Style palette (updates with DefaultTheme.applyJson)"
);
assert(
  fs.readFileSync(path.join(__dirname, "qmldir"), "utf8").indexOf("WallpaperTermPreview") !== -1,
  "qmldir registers WallpaperTermPreview"
);

const svc = fs.readFileSync(path.join(__dirname, "WallpaperService.qml"), "utf8");
assert(
  /waitForEnd:\s*true/.test(svc) && /DefaultTheme\.applyJson/.test(svc),
  "preview process waits for autotheme JSON then applyJson"
);

if (failed > 0) {
  console.log("\n" + failed + " assertion(s) failed");
  process.exit(1);
}
console.log("\nall assertions passed");
