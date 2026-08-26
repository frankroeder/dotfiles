#!/usr/bin/env node
"use strict";

const fs = require("fs");
const path = require("path");
const { spawnSync } = require("child_process");

const shipped = require("./wallpaper_thumbs.js");
if (typeof shipped.previewSource !== "function" || typeof shipped.convertCommand !== "function") {
  throw new Error("shipped wallpaper_thumbs.js did not export previewSource/convertCommand");
}

let failed = 0;
function assert(cond, msg) {
  if (cond) console.log("ok  " + msg);
  else {
    failed += 1;
    console.log("FAIL  " + msg);
  }
}

const os = require("os");
const scratch = process.env.WALL_THUMB_SCRATCH || fs.mkdtempSync(path.join(os.tmpdir(), "wall-thumbs-"));
fs.mkdirSync(scratch, { recursive: true });
const original = path.join(scratch, "original.png");
const cache = path.join(scratch, "thumbs");
fs.mkdirSync(cache, { recursive: true });

const convertBin = spawnSync("convert", ["-version"], { encoding: "utf8" });
const haveConvert = convertBin.status === 0;
console.log("convert " + (haveConvert ? "present" : "MISSING"));

if (haveConvert) {
  const makeOrig = spawnSync(
    "convert",
    ["-size", "640x360", "xc:#334455", "-fill", "white", "-draw", "circle 320,180 320,40", original],
    { encoding: "utf8" }
  );
  assert(makeOrig.status === 0 && fs.existsSync(original), "created oversized original for thumb test");
} else {
  console.log("note  convert missing — path mapping still must not bind the original");
  fs.writeFileSync(original, Buffer.alloc(8000, 1));
}

const dest = shipped.thumbPath(original, cache);
const srcWhenMissing = shipped.previewSource(original, cache, false);
const srcWhenReady = shipped.previewSource(original, cache, true);
console.log("original " + original);
console.log("thumbPath " + dest);
console.log("preview missing " + JSON.stringify(srcWhenMissing));
console.log("preview ready " + JSON.stringify(srcWhenReady));

assert(srcWhenMissing === "", "grid source is empty until a cache thumb exists (not the original)");
assert(srcWhenReady !== "", "ready preview source is non-empty");
assert(srcWhenReady.indexOf("file://" + original) === -1, "ready source is not file:// + original");
assert(srcWhenReady === "file://" + dest, "ready source is file:// + cache thumb path");
assert(dest !== original, "thumb path is not the original wallpaper path");

if (haveConvert) {
  const cmd = shipped.convertCommand(original, dest);
  console.log("convertCommand " + JSON.stringify(cmd));
  const gen = spawnSync(cmd[0], cmd.slice(1), { encoding: "utf8" });
  assert(gen.status === 0 && fs.existsSync(dest), "shipped convertCommand generated a thumb file");
  const origBytes = fs.statSync(original).size;
  const thumbBytes = fs.statSync(dest).size;
  console.log("bytes original " + origBytes + " thumb " + thumbBytes);
  const ident = spawnSync("identify", ["-format", "%wx%h", dest], { encoding: "utf8" });
  console.log("thumb pixels " + (ident.stdout || "").trim());
  assert(thumbBytes < origBytes, "generated thumb file is smaller than the original");
} else {
  console.log("skip  size compare (no convert)");
}

assert(typeof shipped.wheelStep === "function", "shipped wallpaper_thumbs.js exports wheelStep");
assert(typeof shipped.clampedContentY === "function", "shipped wallpaper_thumbs.js exports clampedContentY");
assert(shipped.wheelStep(10, 0, 100) === 20, "touchpad pixel delta is boosted 2x (got " + shipped.wheelStep(10, 0, 100) + ")");
assert(shipped.wheelStep(0, 120, 100) === 250, "mouse notch jumps 2.5 rows (got " + shipped.wheelStep(0, 120, 100) + ")");
assert(shipped.wheelStep(0, -240, 80) === -400, "two reverse notches jump 5 rows of 80px");
assert(shipped.clampedContentY(0, -1000, 500, 200) === 300, "contentY clamps to max scroll");
assert(shipped.clampedContentY(50, 80, 500, 200) === 0, "contentY clamps to 0");
assert(shipped.clampedContentY(40, 10, 500, 200) === 30, "contentY subtracts the wheel step");

const qmlGrid = fs.readFileSync(path.join(__dirname, "../launcher/LauncherWindow.qml"), "utf8");
const mgr = fs.readFileSync(path.join(__dirname, "WallpaperManager.qml"), "utf8");
const svc = fs.readFileSync(path.join(__dirname, "WallpaperService.qml"), "utf8");
assert(svc.indexOf("WallThumbs.previewSource") !== -1, "WallpaperService.previewSource uses shipped helper");
assert(
  !/source:\s*modelData \? \("file:\/\/" \+ modelData\)/.test(qmlGrid),
  "Quick wallpaper GridView does not bind Image source to file:// + raw path"
);
assert(
  mgr.indexOf("WallpaperService.previewSource(modelData)") !== -1,
  "WallpaperManager grid uses previewSource"
);
assert(
  !/source:\s*"file:\/\/" \+ modelData/.test(mgr.replace(/source: root\.previewPath[\s\S]*?fillMode/m, "")),
  "WallpaperManager grid Image source is not file:// + raw wallpaper path"
);

const wpBlock = qmlGrid.match(/id:\s*wpGrid[\s\S]*?delegate:/);
assert(!!wpBlock, "LauncherWindow.qml declares wpGrid");
assert(
  /ScrollBar\.vertical:\s*ScrollBar/.test(wpBlock[0]),
  "Quick wallpaper GridView has a right scrollbar"
);
assert(
  /WallThumbs\.wheelStep/.test(wpBlock[0]) && /WallThumbs\.clampedContentY/.test(wpBlock[0]),
  "Quick wallpaper wheel uses shipped wheelStep + clampedContentY"
);
assert(
  /rightMargin:\s*12/.test(wpBlock[0]),
  "Quick wallpaper grid reserves a right gutter for the scrollbar"
);

const mgrBlock = mgr.match(/id:\s*wallpaperGrid[\s\S]*?delegate:/);
assert(!!mgrBlock, "WallpaperManager.qml declares wallpaperGrid");
assert(
  /ScrollBar\.vertical:\s*ScrollBar/.test(mgrBlock[0]),
  "WallpaperManager GridView has a right scrollbar"
);
assert(
  /WallThumbs\.wheelStep/.test(mgrBlock[0]) && /WallThumbs\.clampedContentY/.test(mgrBlock[0]),
  "WallpaperManager wheel uses shipped wheelStep + clampedContentY"
);

if (failed > 0) {
  console.log("\n" + failed + " assertion(s) failed");
  process.exit(1);
}
console.log("\nall assertions passed");
