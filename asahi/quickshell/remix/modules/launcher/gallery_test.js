#!/usr/bin/env node
"use strict";
const fs = require("fs");
const path = require("path");
const G = require("./gallery.js");

if (G.label("/home/x/screenshots/screenshot-2026-09-14_12-00-00.png") !== "2026-09-14_12-00-00") throw new Error("shot label");
if (G.label("/home/x/Videos/recording-2026-09-14_12-00-00.mp4") !== "2026-09-14_12-00-00") throw new Error("rec label");

const shotCmd = G.scanCommand("shots", "/home/x/");
if (shotCmd.indexOf("\"/home/x/screenshots\"") === -1 || shotCmd.indexOf("screenshot-*.png") === -1) throw new Error("shot cmd " + shotCmd);
const vidCmd = G.scanCommand("videos", "/home/x");
if (vidCmd.indexOf("\"/home/x/Videos\"") === -1 || vidCmd.indexOf("recording-*.mp4") === -1) throw new Error("vid cmd " + vidCmd);

const mapped = G.mapPaths("/home/x/Videos/recording-a.mp4\n/home/x/Videos/recording-b.mp4\n");
if (mapped.length !== 2 || mapped[0].label !== "a" || mapped[1].path !== "/home/x/Videos/recording-b.mp4") throw new Error("map");
if (G.mapPaths("").length !== 0) throw new Error("empty scan");

const qml = fs.readFileSync(path.join(__dirname, "LauncherWindow.qml"), "utf8");
if (qml.indexOf("gallery.js") === -1) throw new Error("LauncherWindow must import gallery.js");
if (qml.indexOf("scanVideos") === -1 || qml.indexOf("galleryKind") === -1) throw new Error("LauncherWindow must have the videos tab");

const pane = fs.readFileSync(path.join(__dirname, "panes/ScreenshotsPane.qml"), "utf8");
if (pane.indexOf("id: shotHoverActions") === -1) throw new Error("screenshot hover actions row missing");
if (!/opacity:\s*tileHover\.hovered \? 1 : 0/.test(pane)) {
  throw new Error("hover actions must follow tile HoverHandler so buttons stay visible when the cursor moves onto them");
}
if (/shotHoverActions[\s\S]{0,400}opacity:\s*hma\.containsMouse/.test(pane)) {
  throw new Error("hover actions must not use hma.containsMouse (IconBtn steals it and hides the row)");
}
// Image preview + image/png copy cannot handle mp4: preview/copy hide on the videos tab.
if (!/visible:\s*!shotsPane\.videoMode;\s*icon:\s*"󰋲"/.test(pane)) {
  throw new Error("preview button must hide on videos");
}
if (!/visible:\s*!shotsPane\.videoMode;\s*icon:\s*"󰆏"/.test(pane)) {
  throw new Error("copy button must hide on videos");
}

console.log("ok  gallery.js + LauncherWindow.qml + ScreenshotsPane.qml");
