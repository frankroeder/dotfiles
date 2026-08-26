#!/usr/bin/env node
"use strict";

const fs = require("fs");
const path = require("path");

const shipped = require("./hub_logo.js");
if (typeof shipped.parseLogo !== "function") {
  throw new Error("shipped hub_logo.js did not export parseLogo");
}

let failed = 0;
function assert(cond, msg) {
  if (cond) console.log("ok  " + msg);
  else {
    failed += 1;
    console.log("FAIL  " + msg);
  }
}

const fixturePath = path.join(__dirname, "fixtures", "fastfetch_title.stdout");
const stdout = fs.readFileSync(fixturePath, "utf8");
console.log("fixture " + fixturePath + " bytes " + stdout.length);

const lines = shipped.parseLogo(stdout);
const joined = shipped.logoText(stdout);
console.log("parsed " + lines.length + " logo lines");
console.log("first " + JSON.stringify(lines[0] || ""));
console.log("joined-head " + JSON.stringify(joined.slice(0, 80)));

assert(lines.length >= 4, "at least 4 non-empty logo-art lines (got " + lines.length + ")");
assert(
  lines.every(function (l) { return l.indexOf("\u001b") === -1 && !/\x1b\[[0-9;]*[A-Za-z]/.test(l); }),
  "no CSI / ESC in parsed logo lines"
);
assert(
  lines.every(function (l) { return !/[A-Za-z0-9._-]+@[A-Za-z0-9._-]+/.test(l); }),
  "no user@host title in parsed logo lines"
);
assert(joined === lines.join("\n"), "logoText is join of parseLogo lines (hub logo field)");
assert(
  lines.some(function (l) { return l.indexOf("@") >= 0; }),
  "Fedora small-logo art still contains @ glyphs (not dropped as title)"
);

const qmlPath = path.join(__dirname, "LauncherWindow.qml");
const qml = fs.readFileSync(qmlPath, "utf8");
assert(qml.indexOf("HubLogo.parseLogo") !== -1, "LauncherWindow.qml calls shipped HubLogo.parseLogo");
assert(qml.indexOf("ffLogoText") !== -1, "hub binds ffLogoText from parsed logo lines");
assert(
  qml.indexOf('indexOf("@")') === -1,
  "hub no longer drops every line containing @"
);
assert(
  !/Layout\.maximumWidth:\s*84\b/.test(qml),
  "hub logo is not capped at 84px (that painted past the layout slot over the labels)"
);
assert(
  /Layout\.preferredWidth:\s*contentWidth/.test(qml),
  "hub logo preferredWidth follows contentWidth so art and labels do not overlap"
);
assert(
  !/Layout\.preferredWidth:\s*1\s*\n\s*Layout\.fillHeight:\s*false\s*\n\s*Layout\.preferredHeight:\s*ffInfoBody/.test(qml),
  "hub no longer draws a vertical separator bar between logo and info"
);
assert(
  /elide:\s*Text\.ElideRight/.test(qml) && /wrapMode:\s*Text\.NoWrap/.test(qml),
  "hub info values elide on one line instead of wrapping mid-word"
);

const maxLen = Math.max.apply(null, lines.map(function (l) { return l.length; }));
assert(
  lines.every(function (l) { return !/\.+$/.test(l); }),
  "parsed logo lines have trailing shade dots stripped"
);
assert(maxLen <= 36, "shade-trimmed logo max width <= 36 cols (got " + maxLen + ")");

if (failed > 0) {
  console.log("\n" + failed + " assertion(s) failed");
  process.exit(1);
}
console.log("\nall assertions passed");
