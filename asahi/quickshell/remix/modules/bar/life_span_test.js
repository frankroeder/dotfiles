#!/usr/bin/env node
"use strict";

const fs = require("fs");
const path = require("path");
const vm = require("vm");

const srcPath = path.join(__dirname, "life_span.js");
const src = fs.readFileSync(srcPath, "utf8");
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

eq(typeof ctx.lifeSpan, "function", "lifeSpan exported");
eq(typeof ctx.decodeBirthYear, "function", "decodeBirthYear exported");
eq(typeof ctx.encodeBirthYear, "function", "encodeBirthYear exported");
eq(/Date\.now/.test(src), false, "life span does not call Date.now");
eq(/new Date\(/.test(src), false, "life span does not construct a Date");

eq(ctx.decodeBirthYear(""), null, "missing store is unset");
eq(ctx.decodeBirthYear(undefined), null, "undefined store is unset");
eq(ctx.decodeBirthYear("nope"), null, "garbage store is unset");
eq(ctx.encodeBirthYear(null), "", "unset encodes empty");
eq(ctx.decodeBirthYear(ctx.encodeBirthYear(1996)), 1996, "birth year round-trips");
eq(ctx.decodeBirthYear(ctx.encodeBirthYear(null)), null, "cleared store round-trips");

eq(ctx.birthStorePath("", "/home/frank"), "/home/frank/.local/state/asahi/calendar-birth-year", "default store is $HOME/.local/state");
eq(ctx.birthStorePath("/var/state/", "/home/frank"), "/var/state/asahi/calendar-birth-year", "XDG_STATE_HOME replaces the default dir");
eq(ctx.resolveBirthYear("1996\n", "1980", true), 1996, "saved file wins over BIRTH_YEAR");
eq(ctx.resolveBirthYear("", "1996", true), null, "empty file stays unset");
eq(ctx.resolveBirthYear("", "1996", false), 1996, "missing file uses BIRTH_YEAR");
eq(ctx.resolveBirthYear("", "", false), null, "missing file and env stays unset");
eq(ctx.resolveBirthYear("", "nope", false), null, "bad BIRTH_YEAR does not invent a year");

function tally(span) {
  let lived = 0, now = 0, left = 0, other = 0;
  for (let i = 0; i < span.cells.length; i++) {
    const c = span.cells[i];
    if (c === "lived") lived++;
    else if (c === "now") now++;
    else if (c === "left") left++;
    else other++;
  }
  return { lived: lived, now: now, left: left, other: other };
}

function assertUnset(value, msg) {
  const span = ctx.lifeSpan(value, new Date(2026, 8, 24));
  eq(span.set, false, msg + " does not invent a span");
  eq(span.cells, null, msg + " has no cells");
  eq(span.yearsLeft, null, msg + " has no years left");
  eq(span.percentLeft, null, msg + " has no percent");
}

assertUnset(null, "null birth year");
assertUnset(undefined, "unset birth year");
assertUnset("", "empty birth year");
assertUnset("nope", "garbage birth year");
assertUnset(ctx.decodeBirthYear(""), "missing store");

eq(/LIFE_WEEKS|weekOfYear|86400000/.test(src), false, "span is years, not weeks");

function check(span, name, exp) {
  eq(span.set, true, name + " set");
  eq(span.cells.length, 90, name + " 90 year dots");
  eq(span.yearsLeft, exp.yearsLeft, name + " years left");
  eq(span.percentLeft, exp.percentLeft, name + " percent left");
  eq(span.percentLeft, Math.round(span.yearsLeft / 90 * 100), name + " percent is rounded years-left / 90");
  const t = tally(span);
  eq(t.other, 0, name + " dots are only lived / now / left");
  eq(t.now, exp.now, name + " now count");
  eq(t.lived, exp.lived, name + " lived count");
  eq(t.left, exp.left, name + " left count");
  eq(t.lived + t.now + t.left, 90, name + " counts cover the years");
  for (let i = 0; i < exp.spots.length; i++) {
    const s = exp.spots[i];
    eq(span.cells[s.i], s.cls, name + " year " + s.i);
  }
}

const mid = ctx.lifeSpan(1996, new Date(2026, 8, 24));
check(mid, "mid-life 1996 / 2026-09-24", {
  yearsLeft: 60,
  percentLeft: 67,
  now: 1,
  lived: 30,
  left: 59,
  spots: [
    { i: 29, cls: "lived" },
    { i: 30, cls: "now" },
    { i: 31, cls: "left" },
    { i: 89, cls: "left" }
  ]
});

const reloaded = ctx.lifeSpan(ctx.decodeBirthYear(ctx.encodeBirthYear(1996)), new Date(2026, 8, 24));
eq(reloaded.yearsLeft, mid.yearsLeft, "reloaded birth year keeps years left");
eq(reloaded.percentLeft, mid.percentLeft, "reloaded birth year keeps percent");
eq(reloaded.cells[30], "now", "reloaded birth year keeps the current year");

const thisYear = ctx.lifeSpan(2026, new Date(2026, 8, 24));
check(thisYear, "this calendar year", {
  yearsLeft: 90,
  percentLeft: 100,
  now: 1,
  lived: 0,
  left: 89,
  spots: [
    { i: 0, cls: "now" },
    { i: 1, cls: "left" },
    { i: 89, cls: "left" }
  ]
});

const jan1 = ctx.lifeSpan(1996, new Date(1996, 0, 1));
check(jan1, "1 January of the birth year", {
  yearsLeft: 90,
  percentLeft: 100,
  now: 1,
  lived: 0,
  left: 89,
  spots: [
    { i: 0, cls: "now" },
    { i: 1, cls: "left" },
    { i: 89, cls: "left" }
  ]
});

const yearEnd = ctx.lifeSpan(1996, new Date(2024, 11, 31));
check(yearEnd, "last day of a leap year", {
  yearsLeft: 62,
  percentLeft: 69,
  now: 1,
  lived: 28,
  left: 61,
  spots: [
    { i: 27, cls: "lived" },
    { i: 28, cls: "now" },
    { i: 29, cls: "left" }
  ]
});

const yearEndCommon = ctx.lifeSpan(1996, new Date(2026, 11, 31));
check(yearEndCommon, "last day of a common year", {
  yearsLeft: 60,
  percentLeft: 67,
  now: 1,
  lived: 30,
  left: 59,
  spots: [
    { i: 30, cls: "now" },
    { i: 31, cls: "left" }
  ]
});

const future = ctx.lifeSpan(2027, new Date(2026, 8, 24));
check(future, "birth year next year", {
  yearsLeft: 90,
  percentLeft: 100,
  now: 0,
  lived: 0,
  left: 90,
  spots: [
    { i: 0, cls: "left" },
    { i: 89, cls: "left" }
  ]
});

const exact = ctx.lifeSpan(1936, new Date(2026, 8, 24));
check(exact, "born exactly 90 years ago", {
  yearsLeft: 0,
  percentLeft: 0,
  now: 0,
  lived: 90,
  left: 0,
  spots: [
    { i: 0, cls: "lived" },
    { i: 89, cls: "lived" }
  ]
});

const older = ctx.lifeSpan(1930, new Date(2026, 8, 24));
check(older, "older than 90", {
  yearsLeft: 0,
  percentLeft: 0,
  now: 0,
  lived: 90,
  left: 0,
  spots: [
    { i: 0, cls: "lived" },
    { i: 89, cls: "lived" }
  ]
});

const qml = fs.readFileSync(path.join(__dirname, "components/Clock.qml"), "utf8");
function has(snippet, msg) {
  eq(qml.indexOf(snippet) !== -1, true, msg);
}
has('import "../life_span.js" as Life', "calendar imports the life-span module");
has("Life.lifeSpan(", "popup span is lifeSpan, not a second formula");
has("Life.resolveBirthYear(", "load uses resolveBirthYear");
has('Quickshell.env("BIRTH_YEAR")', "BIRTH_YEAR env is read");
has("Life.encodeBirthYear(", "save encodes the birth year");
has("birthFile.setText(", "birth year is written to the store file");
has("Life.birthStorePath(", "store path is birthStorePath");
eq(src.indexOf("/.local/state") !== -1, true, "default dir is $HOME/.local/state");
eq(src.indexOf("calendar-birth-year") !== -1, true, "store file name is calendar-birth-year");
has("birthFile.reload()", "opening the calendar reloads the birth year");
has("monthLabel()", "month label stays");
has("shiftMonth(-1)", "previous month stays");
has("shiftMonth(1)", "next month stays");
has("goToday()", "today control stays");
has('"Mo"', "weekday headers stay");
has("root.weeks", "month day grid stays");
has("yearsLeft", "years-left readout");
has("percentLeft", "percent-left readout");
has("life.cells", "year dots come from life.cells");
has("radius: 3", "years are drawn as dots");
eq(qml.indexOf("lifeCanvas") === -1, true, "week canvas is gone");
eq(qml.indexOf("grabFocus:") === -1, true, "popup is not a Qt grab popup");
has("HyprlandFocusGrab", "Hyprland keyboard grab is installed");
has("windows: [calPopup]", "grab includes the calendar popup");
has("calendarKeys.active = activeFocus && root.showCalendar", "grab starts when the year field is focused");
eq(qml.indexOf("onCleared") === -1, true, "a focus clear does not close the calendar");
eq(qml.split("Life.lifeSpan(").length, 2, "calendar calls lifeSpan once");

if (failed) {
  console.log(failed + " failed");
  process.exit(1);
}
console.log("all passed");
