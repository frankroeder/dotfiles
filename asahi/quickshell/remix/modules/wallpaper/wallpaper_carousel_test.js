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
