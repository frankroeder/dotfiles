#!/usr/bin/env node
"use strict";

const fs = require("fs");
const path = require("path");
const vm = require("vm");

const src = fs.readFileSync(path.join(__dirname, "BarModel.js"), "utf8");
const ctx = {};
vm.createContext(ctx);
vm.runInContext(src, ctx);

let failed = 0;
function eq(got, expected, msg) {
  if (got === expected) console.log("ok  " + msg);
  else {
    failed += 1;
    console.log("FAIL  " + msg + " got=" + JSON.stringify(got) + " expected=" + JSON.stringify(expected));
  }
}

const fmt = ctx.formatAge;
eq(typeof fmt, "function", "formatAge exported");
eq(fmt(0, 100), "", "missing since is empty");
eq(fmt(50, 40), "", "future since is empty");
eq(fmt(100, 100), "0m", "0s → 0m");
eq(fmt(100, 159), "0m", "59s → 0m");
eq(fmt(100, 160), "1m", "60s → 1m");
eq(fmt(100, 100 + 3600), "1h 0m", "1h");
eq(fmt(100, 100 + 3600 + 90), "1h 1m", "1h 1m");
eq(fmt(100, 100 + 86400), "1d 0h", "1d");
eq(fmt(100, 100 + 2 * 86400 + 5 * 3600), "2d 5h", "2d 5h");

if (failed) {
  console.log(failed + " failed");
  process.exit(1);
}
console.log("all passed");
