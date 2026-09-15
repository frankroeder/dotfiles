#!/usr/bin/env node
"use strict";
const fs = require("fs");
const path = require("path");
const C = require("./cava_bars.js");

const vs = C.parseFrame("0;10;20;30;40;50;60;70;80;90;100;5;5;5;5;5;5;5;5;5;5;5;5;5;\n");
if (vs.length !== 24) throw new Error("len " + vs.length);
if (vs[0] !== 0 || vs[10] !== 100 || vs[23] !== 5) throw new Error("vals " + vs);
if (C.parseFrame("").length !== 24) throw new Error("empty");
if (C.barHeight(0, 16) !== 2) throw new Error("min height");
if (C.barHeight(100, 16) !== 16) throw new Error("max height");

const media = fs.readFileSync(path.join(__dirname, "components/MediaPlayer.qml"), "utf8");
if (media.indexOf("cava_bars.js") === -1) throw new Error("MediaPlayer must import cava_bars.js");
if (media.indexOf("pkill") === -1) throw new Error("MediaPlayer must stop cava when FULL mode ends");

console.log("ok  cava_bars.js + MediaPlayer.qml");
