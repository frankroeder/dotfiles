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
const infoBody = qml.match(/id:\s*ffInfoBody[\s\S]{0,250}/);
assert(!!infoBody, "hub declares ffInfoBody");
assert(
  /Layout\.fillHeight:\s*true/.test(infoBody[0]),
  "hub info body fills leftover pane height instead of packing at the top"
);
const ffMain = qml.match(/id:\s*ffMain[\s\S]{0,180}/);
assert(!!ffMain, "hub declares ffMain");
assert(
  /Layout\.fillHeight:\s*true/.test(ffMain[0]),
  "hub main logo+info row takes leftover pane height"
);

const valueBlock = qml.match(/text:\s*rowValue[\s\S]{0,800}/);
assert(!!valueBlock, "hub value Text binds rowValue");
assert(
  /wrapMode:\s*width\s*>\s*80\s*\?\s*Text\.WordWrap\s*:\s*Text\.NoWrap/.test(valueBlock[0]),
  "hub info values wrap into leftover well height once the column has width"
);
assert(
  /maximumLineCount:\s*width\s*>\s*80\s*\?\s*2\s*:\s*1/.test(valueBlock[0]),
  "hub info values may wrap two lines in a shared grid row"
);
const minLead = Math.min.apply(null, lines.map(function (l) {
  const m = l.match(/^(\s*)/);
  return m ? m[1].length : 0;
}));
assert(minLead === 0, "logo shared leading indent is stripped (got " + minLead + ")");
assert(
  /id:\s*ffInfoBody[\s\S]{0,80}GridLayout/.test(qml) || /GridLayout\s*\{\s*id:\s*ffInfoBody/.test(qml),
  "hub facts sit in a shared GridLayout so wrapped rows stay aligned"
);
assert(
  /horizontalAlignment:\s*Text\.AlignLeft/.test(qml),
  "hub fact labels are left-aligned (Display must not become Displ...)"
);
assert(
  /ffLabelWidth:\s*Math\.max\(68/.test(qml),
  "hub fact label column is wide enough for Display / Kernel"
);
assert(
  /Layout\.preferredHeight:\s*root\.launcherGeom\.rowHTall/.test(qml),
  "hub meters height follows adaptive rowHTall"
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
