#!/usr/bin/env node
"use strict";

const fs = require("fs");
const path = require("path");
const vm = require("vm");

const src = fs.readFileSync(path.join(__dirname, "writing_diff.js"), "utf8").replace(/^\.pragma library\s*$/m, "")
const ctx = {};
vm.createContext(ctx);
vm.runInContext(src, ctx);

// Plain text of one side: "old" = original, "new" = suggestion.
const sideText = (ops, side) => ops.filter(o => o.op !== (side === "old" ? "ins" : "del")).map(o => o.text).join("");

let failed = 0;
function eq(got, expected, msg) {
  const g = JSON.stringify(got), e = JSON.stringify(expected);
  if (g === e) console.log("ok  " + msg);
  else {
    failed += 1;
    console.log("FAIL  " + msg + " got=" + g + " expected=" + e);
  }
}

eq(ctx.tokenize("It's a test, ok?"), ["It's", " ", "a", " ", "test", ",", " ", "ok", "?"], "tokenize keeps apostrophes, splits punctuation");
eq(ctx.tokenize(""), [], "tokenize empty");

let ops = ctx.diff("Their going too the park.", "They're going to the park.");
eq(ops.map(o => ({ op: o.op, text: o.text })), [
  { op: "del", text: "Their" }, { op: "ins", text: "They're" },
  { op: "eq", text: " going " },
  { op: "del", text: "too" }, { op: "ins", text: "to" },
  { op: "eq", text: " the park." },
], "word substitutions");
eq(ctx.changes(ops), 2, "two change blocks");
eq(sideText(ops, "old"), "Their going too the park.", "old side is the original");
eq(sideText(ops, "new"), "They're going to the park.", "new side is the suggestion");

ops = ctx.diff("same text", "same text");
eq(ops, [{ op: "eq", text: "same text" }], "identical is one eq run");
eq(ctx.changes(ops), 0, "identical has no changes");

ops = ctx.diff("a b c", "x y c");
eq(ops, [{ op: "del", text: "a b" }, { op: "ins", text: "x y" }, { op: "eq", text: " c" }], "space between changes joins one block");

ops = ctx.diff("Hello world", "Hello brave new world");
eq(sideText(ops, "new"), "Hello brave new world", "insertion round-trips");
eq(ctx.changes(ops), 1, "pure insertion is one block");

const big = Array.from({ length: 1500 }, (_, i) => "w" + i).join(" ");
const big2 = Array.from({ length: 1500 }, (_, i) => "v" + i).join(" ");
ops = ctx.diff(big, big2);
eq(sideText(ops, "old"), big, "huge diff falls back, old side intact");
eq(sideText(ops, "new"), big2, "huge diff falls back, new side intact");

eq(ctx.fitOutput("  hello wrld\n", "Hello world."), "  Hello world.\n", "fitOutput keeps selection whitespace");
eq(ctx.fitOutput("x", "```\nfixed\n```"), "fixed", "fitOutput drops fences");
eq(ctx.fitOutput("x", "<text>\nfixed\n</text>"), "fixed", "fitOutput drops text tags");

const colors = { del: "#f00", delBg: "#300", delMark: "#900", ins: "#0f0", insBg: "#030", insMark: "#090" };
const h = ctx.html(ctx.diff("a <b>", "a <c>"), "new", colors);
eq(h.includes("&lt;") && h.includes("&gt;") && !h.includes("<c>") && !h.includes(">c<b"), true, "html escapes");
eq(h.includes("line-through"), false, "new side has no deletions");
eq(ctx.html(ctx.diff("a b", "a c"), "old", colors).includes("line-through"), true, "old side strikes deletions");

ops = ctx.diff("see you tomorow", "see you tomorrow");
eq(ops[1].chars, [{ op: "eq", text: "tomor" }, { op: "ins", text: "r" }, { op: "eq", text: "ow" }], "typo gets character marks");
eq(ops[2].chars === ops[1].chars, true, "del and ins share the char script");
let hn = ctx.html(ops, "new", colors);
eq(hn.includes('#090">r</span>') && hn.includes('#030">tomor</span>'), true, "inserted char strong, rest of word light");
let ho = ctx.html(ops, "old", colors);
eq(ho.includes(">r<"), false, "old side never shows the inserted char");
eq(sideText(ops, "new"), "see you tomorrow", "char marks keep side text");

ops = ctx.diff("a cat", "a dog");
eq(ops[1].chars, undefined, "unrelated words: no char marks");
eq(ctx.html(ops, "new", colors).includes('#090">dog</span>'), true, "unrelated word is one strong mark");

ops = ctx.diff("its fine", "it's fine");
eq(ctx.html(ops, "new", colors).includes('#090">\'</span>'), true, "apostrophe alone is the strong mark");

ops = ctx.diff("its gonna be", "it's going to be");
eq(ops[0].chars, undefined, "multi-word block: no char marks");

eq(ctx.fitOutput("Run this:\n```\nls\n```", "Run this:\n```\nls -l\n```"), "Run this:\n```\nls -l\n```", "fitOutput keeps the selection's own fences");
ops = ctx.diff("😀a", "😃a");
eq(ops[0].chars, [{ op: "del", text: "😀" }, { op: "ins", text: "😃" }, { op: "eq", text: "a" }], "char marks never split an emoji");

if (failed) { console.log(failed + " failed"); process.exit(1); }
console.log("all ok");
