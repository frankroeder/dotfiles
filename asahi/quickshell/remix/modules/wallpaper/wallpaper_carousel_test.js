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

console.log("\n== carouselSlots (prev/current/next) ==");
if (typeof shipped.carouselSlots !== "function") {
  throw new Error("shipped wallpaper_thumbs.js did not export carouselSlots");
}
const paths = ["/a.png", "/b.png", "/c.png", "/d.png"];
const mid = shipped.carouselSlots(paths, 1);
assert(mid.length === 3, "always three slots");
assert(mid[0].path === "/a.png" && !mid[0].current, "index 1 has previous neighbour");
assert(mid[1].path === "/b.png" && mid[1].current, "index 1 current is centre");
assert(mid[2].path === "/c.png" && !mid[2].current, "index 1 has next neighbour");
const first = shipped.carouselSlots(paths, 0);
assert(first[0].path === "" && first[1].path === "/a.png" && first[2].path === "/b.png",
  "index 0 keeps an empty left slot so current stays centred");
const last = shipped.carouselSlots(paths, 3);
assert(last[0].path === "/c.png" && last[1].path === "/d.png" && last[2].path === "",
  "last item keeps an empty right slot");
const empty = shipped.carouselSlots([], 0);
assert(empty[0].path === "" && empty[1].path === "" && empty[2].path === "", "empty list is three empty slots");

console.log("\n== Quick wallpaper source (LauncherWindow.qml) ==");
const qml = fs.readFileSync(path.join(__dirname, "../launcher/LauncherWindow.qml"), "utf8");
const start = qml.indexOf("Component { id: quickWallpaperComp");
assert(start !== -1, "quickWallpaperComp exists");
const nextComp = qml.indexOf("\n  Component {", start + 10);
const wp = qml.slice(start, nextComp === -1 ? qml.length : nextComp);

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
  wp.indexOf("WallpaperTermPreview") === -1,
  "Quick wallpaper has no fake Ghostty ls/src mock"
);

console.log("\n== WallpaperCarousel.qml ==");
const car = fs.readFileSync(path.join(__dirname, "WallpaperCarousel.qml"), "utf8");
assert(
  /WallThumbs\.carouselSlots\(\s*paths,\s*currentIndex\s*\)/.test(car),
  "WallpaperCarousel lays out prev/current/next via shipped carouselSlots"
);
assert(
  !/ListView\s*\{/.test(car),
  "WallpaperCarousel is not a ListView (that clipped neighbours in Quick)"
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

if (failed > 0) {
  console.log("\n" + failed + " assertion(s) failed");
  process.exit(1);
}
console.log("\nall assertions passed");
