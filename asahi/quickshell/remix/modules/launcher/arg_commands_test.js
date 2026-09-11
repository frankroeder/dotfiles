#!/usr/bin/env node
"use strict";

const assert = require("assert");
const A = require("./arg_commands.js");

const engines = [
  { name: "dict.cc", prefix: "dcc", url: "https://www.dict.cc/?s=%TERM%" },
  { name: "Jax Documentation", prefix: "jaxdoc", url: "https://docs.jax.dev/?q=%TERM%" },
  { name: "Kagi", prefix: "kagi", url: "https://kagi.com/search?q=%TERM%" }
];

assert.strictEqual(A.join("dict", ""), "dict");
assert.strictEqual(A.join("dict", "haus"), "dict haus");
assert.strictEqual(A.join("@dcc", "haus"), "@dcc haus");
assert.strictEqual(A.join(">", "src"), "> src");
assert.strictEqual(A.join("!", "hypr"), "! hypr");
assert.strictEqual(A.join("=", "2+2"), "= 2+2");
assert.strictEqual(A.join(";", "smile"), "; smile");
assert.deepStrictEqual(A.parse("; fire", engines), { command: ";", arg: "fire" });
assert.strictEqual(A.placeholder(";"), "Type to filter emoji");

assert.strictEqual(A.argFromQuery("dict", "dict"), "");
assert.strictEqual(A.argFromQuery("dict haus", "dict"), "haus");
assert.strictEqual(A.argFromQuery("@dcc haus tür", "@dcc"), "haus tür");
assert.strictEqual(A.argFromQuery("> src/foo", ">"), "src/foo");
assert.strictEqual(A.argFromQuery("apps", "dict"), "");

assert.deepStrictEqual(A.parse("dict", engines), { command: "dict", arg: "" });
assert.deepStrictEqual(A.parse("dict haus", engines), { command: "dict", arg: "haus" });
assert.deepStrictEqual(A.parse("@dcc", engines), { command: "@dcc", arg: "" });
assert.deepStrictEqual(A.parse("@dcc haus", engines), { command: "@dcc", arg: "haus" });
assert.deepStrictEqual(A.parse("@", engines), { command: "@", arg: "" });
assert.strictEqual(A.parse("@nope", engines), null);
assert.strictEqual(A.parse("firefox", engines), null);

assert.strictEqual(A.uniqueEngine("@jax", engines).prefix, "jaxdoc");
assert.strictEqual(A.uniqueEngine("@dcc", engines).prefix, "dcc");
assert.strictEqual(A.uniqueEngine("dcc", engines), null);
assert.strictEqual(A.uniqueEngine("@", engines), null);
assert.strictEqual(A.uniqueEngine("@j", engines).prefix, "jaxdoc");
assert.strictEqual(A.uniqueEngine("@x", engines), null);

const dictTab = A.tabArm("dict", null, engines);
assert.ok(dictTab && dictTab.command === "dict", "tab on dict arms dict");
assert.ok(dictTab.placeholder.toLowerCase().indexOf("word") >= 0, "dict placeholder asks for a word");
assert.strictEqual(A.tabArm("dict haus", null, engines), null, "dict with a word keeps Tab for results");

const dccTab = A.tabArm("@dcc", null, engines);
assert.ok(dccTab && dccTab.command === "@dcc", "tab on @dcc arms the engine");
assert.strictEqual(A.tabArm("@dcc haus", null, engines), null, "@dcc with a term keeps Tab for results");

const jaxTab = A.tabArm("@jax", null, engines);
assert.ok(jaxTab && jaxTab.command === "@jaxdoc", "partial @jax tabs to jaxdoc");

const fromRow = A.tabArm("", { special: "doc", prefix: "dcc", name: "dict.cc" }, engines);
assert.ok(fromRow && fromRow.command === "@dcc", "Tab on a web row arms @prefix");
assert.ok(fromRow.placeholder.indexOf("dict.cc") >= 0, "web placeholder names the engine");

const prompt = A.tabArm("dict", { id: "dict-prompt", special: "noop" }, engines);
assert.ok(prompt && prompt.command === "dict", "Tab on dict-prompt arms dict");

assert.strictEqual(A.tabArm("@", { title: "Kagi" }, engines), null, "bare @ still picks an engine");
assert.strictEqual(A.tabArm("firefox", null, engines), null, "plain app query does not arm");

assert.strictEqual(A.placeholder("dict"), "Type a word to translate");
assert.ok(A.placeholder("@dcc", { name: "dict.cc" }).indexOf("dict.cc") >= 0);

const fs = require("fs");
const path = require("path");
const qml = fs.readFileSync(path.join(__dirname, "LauncherWindow.qml"), "utf8");
assert.ok(qml.indexOf('import "arg_commands.js" as ArgCommands') >= 0, "LauncherWindow imports ArgCommands");
assert.ok(qml.indexOf("tryArmArgument") >= 0, "LauncherWindow Tab calls tryArmArgument");
assert.ok(qml.indexOf("argCommand") >= 0, "LauncherWindow keeps an armed prefix");

console.log("ok  arg_commands");
