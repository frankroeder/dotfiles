#!/usr/bin/env node
"use strict";

const fs = require("fs");
const path = require("path");
const vm = require("vm");

const src = fs.readFileSync(path.join(__dirname, "Data.js"), "utf8").replace(/^\.pragma library\n/, "");
const out = {};
vm.runInNewContext(src + "\n__out.categoryNav = categoryNav;\n__out.itemTint = itemTint;\n__out.deckTint = deckTint;\n__out.categoryTints = categoryTints;\n__out.tildify = tildify;\n__out.categoryPrefix = categoryPrefix;\n__out.parseHyprBinds = parseHyprBinds;", { __out: out });

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
assert(out.tildify("/home/u/x", "/home/u") === "~/x" && out.tildify("/home/u", "/home/u") === "~", "tildify home paths");
assert(out.tildify("/home/u2/x", "/home/u") === "/home/u2/x", "tildify stops at a path boundary");
// `hyprctl binds` text: descless binds dropped, keycode / XF86 labels, mods in Super+Ctrl+Alt+Shift order.
const bindsText = [
  "bindd", "\tmodmask: 64", "\tsubmap: ", "\tkey: T", "\tkeycode: 0", "\tdescription: Terminal", "",
  "bindl", "\tmodmask: 0", "\tsubmap: ", "\tkey: switch:on:Apple SMC power/lid events", "\tkeycode: 0", "\tdescription: ", "",
  "bind", "\tmodmask: 0", "\tsubmap: writing", "\tkey: Return", "\tkeycode: 0", "\tdescription: ", "",
  "bindd", "\tmodmask: 65", "\tsubmap: ", "\tkey: ", "\tkeycode: 12", "\tdescription: Screenshot display", "",
  "bindd", "\tmodmask: 69", "\tsubmap: ", "\tkey: XF86AudioLowerVolume", "\tkeycode: 0", "\tdescription: Shot smart", "",
  "bindde", "\tmodmask: 69", "\tsubmap: ", "\tkey: XF86AudioLowerVolume", "\tkeycode: 0", "\tdescription: Shot smart", ""
].join("\n");
const binds = out.parseHyprBinds(bindsText);
assert(binds.length === 3, "descless binds dropped, repeat variant deduped (got " + binds.length + ")");
assert(binds[0].combo === "Super+T" && binds[0].desc === "Terminal", "plain bind label");
assert(binds[1].combo === "Super+Shift+3", "code:12 reads as the de digit (got " + binds[1].combo + ")");
assert(binds[2].combo === "Super+Ctrl+Shift+LowerVolume", "XF86 prefix dropped (got " + binds[2].combo + ")");
const prefixed = nav.filter(row => row.accessory && out.categoryPrefix[row.target] !== undefined);
assert(prefixed.every(row => out.categoryPrefix[row.target] === row.accessory), "overview prefix hints match categoryPrefix");

const qml = fs.readFileSync(path.join(__dirname, "LauncherWindow.qml"), "utf8");
assert(qml.indexOf("function tintColor") !== -1, "LauncherWindow maps tint tokens to Style colors");
assert(qml.indexOf("itemTintColor") !== -1, "LauncherWindow resolves item tints");
assert(qml.indexOf("delegateRoot.dTint") !== -1, "result rows use per-item tint");

if (failed) {
  console.log("\n" + failed + " assertion(s) failed");
  process.exit(1);
}
console.log("\nall assertions passed");
