#!/usr/bin/env node
"use strict";

const assert = require("assert");
const E = require("./emoji.js");

assert.ok(E.EMOJI.length > 200, "emoji table is browseable");
assert.strictEqual(E.term(";"), "");
assert.strictEqual(E.term("; smile"), "smile");
assert.strictEqual(E.term("smile"), null);
assert.strictEqual(E.term("dict haus"), null);

const smiles = E.search("smile", 20);
assert.ok(smiles.length > 0, "smile matches");
assert.ok(smiles.some(e => e.g === "😀" || e.g === "😊"), "smile hits a smiling face");

const fire = E.search("fire", 10);
assert.ok(fire.some(e => e.g === "🔥"), "fire finds 🔥");

const thumbs = E.search("thumbs up", 10);
assert.ok(thumbs.some(e => e.g === "👍"), "thumbs up finds 👍");

const empty = E.search("", 8);
assert.strictEqual(empty.length, 8, "empty query returns a browse window");

const miss = E.search("xyzzy-no-such-emoji", 10);
assert.strictEqual(miss.length, 0, "unknown query is empty");

assert.ok(E.placeholder().toLowerCase().indexOf("emoji") >= 0);

const fs = require("fs");
const path = require("path");
const qml = fs.readFileSync(path.join(__dirname, "LauncherWindow.qml"), "utf8");
assert.ok(qml.indexOf('import "emoji.js" as Emoji') >= 0, "LauncherWindow imports Emoji");
assert.ok(qml.indexOf("getEmojiResults") >= 0, "LauncherWindow searches emoji");
assert.ok(qml.indexOf("title: e.n") >= 0, "emoji title is the name only");
assert.ok(qml.indexOf("title: e.g") < 0, "emoji title does not repeat the glyph");

const data = fs.readFileSync(path.join(__dirname, "Data.js"), "utf8");
assert.ok(data.indexOf('target: "Emoji"') >= 0, "Browse has an Emoji category");

console.log("ok  emoji");
