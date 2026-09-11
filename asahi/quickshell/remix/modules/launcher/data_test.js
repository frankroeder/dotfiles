#!/usr/bin/env node
"use strict";

const fs = require("fs");
const path = require("path");
const vm = require("vm");

const src = fs.readFileSync(path.join(__dirname, "Data.js"), "utf8").replace(/^\.pragma library\n/, "");
const out = {};
vm.runInNewContext(src + "\n__out.categoryNav = categoryNav;\n__out.itemTint = itemTint;\n__out.deckTint = deckTint;\n__out.categoryTints = categoryTints;", { __out: out });

let failed = 0;
function assert(cond, msg) {
  if (cond) console.log("ok  " + msg);
  else {
    failed += 1;
    console.log("FAIL  " + msg);
  }
}

const nav = out.categoryNav;
assert(nav.length === 8, "overview has 8 menu items (got " + nav.length + ")");
const tints = nav.map(row => row.tint);
assert(tints.every(Boolean), "every overview item has a tint");
assert(new Set(tints).size === tints.length, "overview tints are unique (got " + tints.join(", ") + ")");
assert(out.itemTint(nav[0]) === "sky", "Quick tints sky");
assert(out.itemTint({ category: "System", special: "action" }) === "maroon", "System rows inherit maroon");
assert(out.itemTint({ special: "app", category: "App" }) === "", "desktop apps stay untinted");
assert(out.deckTint("battery") === "green", "deck battery is green");
assert(out.deckTint("dashboard") === "sky", "deck dashboard matches Quick");

const qml = fs.readFileSync(path.join(__dirname, "LauncherWindow.qml"), "utf8");
assert(qml.indexOf("function tintColor") !== -1, "LauncherWindow maps tint tokens to Style colors");
assert(qml.indexOf("itemTintColor") !== -1, "LauncherWindow resolves item tints");
assert(qml.indexOf("delegateRoot.dTint") !== -1, "result rows use per-item tint");

if (failed) {
  console.log("\n" + failed + " assertion(s) failed");
  process.exit(1);
}
console.log("\nall assertions passed");
