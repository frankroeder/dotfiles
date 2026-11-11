#!/usr/bin/env node
"use strict";
// touchid_model.js: the Touch ID prompt's state machine.

const fs = require("fs");
const path = require("path");
const vm = require("vm");

const ctx = {};
vm.createContext(ctx);
vm.runInContext(fs.readFileSync(path.join(__dirname, "touchid_model.js"), "utf8"), ctx);
const { reduce, initial } = ctx;

let failed = 0;
function eq(got, expected, msg) {
  const g = JSON.stringify(got), e = JSON.stringify(expected);
  if (g === e) console.log("ok  " + msg);
  else { failed += 1; console.log("FAIL  " + msg + " got=" + g + " expected=" + e); }
}
function run(events, s) {
  s = s || initial();
  for (const [ev, now] of events) s = reduce(s, ev, now);
  return s;
}
const sudo = { ev: "start", kind: "sudo", suppress: false, title: "sudo", detail: "dnf upgrade", app: "Ghostty", address: "0x1" };

// sudo: waiting → reading → match → hidden after the green beat.
let s = run([[sudo, 0], [{ ev: "needed", value: true }, 1], [{ ev: "present", value: true }, 2]]);
eq(s.phase, "reading", "finger on the sensor reads");
s = reduce(s, { ev: "status", result: "verify-match", done: true }, 3);
eq([s.phase, s.until], ["match", 903], "match shows green");
eq(reduce(s, { ev: "tick" }, 500).phase, "match", "match holds");
eq(reduce(s, { ev: "tick" }, 903).phase, "hidden", "then hides");

// Wrong finger: red, back to waiting while fprintd retries; the last miss fails with a note.
s = run([[sudo, 0], [{ ev: "status", result: "verify-no-match", done: false }, 10]]);
eq([s.phase, s.note], ["nomatch", "No match · try again"], "miss with retries left");
eq(reduce(s, { ev: "tick" }, 10 + 1400).phase, "waiting", "back to waiting");
s = reduce(s, { ev: "status", result: "verify-no-match", done: true }, 20);
eq([s.phase, s.note], ["failed", "No match · use your password"], "out of tries");
eq(run([[sudo, 0], [{ ev: "status", result: "verify-retry-scan", done: false }, 1]]).note, "Not read · touch again", "retry scan");
eq(run([[sudo, 0], [{ ev: "status", result: "verify-lockout", done: true }, 1]]).note, "Too many attempts · use your password", "lockout");
eq(run([[sudo, 0], [{ ev: "status", result: "verify-password-required-48h", done: true }, 1]]).note,
  "Enter your password to enable Touch ID", "SEP password clock");

// fprintd stops waiting without a status (Ctrl+C on sudo): a short ending, then hidden.
s = run([[sudo, 0], [{ ev: "needed", value: false }, 100]]);
eq(s.phase, "ending", "cancel ends");
eq(reduce(s, { ev: "tick" }, 100 + 450).phase, "hidden", "and hides");
// The status right after needed=false still wins (fprintd sends them in that order).
eq(reduce(s, { ev: "status", result: "verify-match", done: true }, 101).phase, "match", "late status after needed=false");

// Lock screen / polkit: nothing shown, and their statuses are ignored.
s = run([[{ ev: "start", kind: "lock", suppress: true }, 0], [{ ev: "status", result: "verify-no-match", done: false }, 1],
  [{ ev: "present", value: true }, 2]]);
eq([s.phase, s.suppressed], ["hidden", true], "suppressed prompt stays hidden");
eq(run([[sudo, 5]], s).phase, "waiting", "a later sudo shows again");

// aurora-fidod: its notification names the site, before or after the verify starts.
const fido = { ev: "start", kind: "fido", suppress: false, title: "Passkey", detail: "Security key request" };
s = run([[{ ev: "fidoNote", title: "Touch ID to sign in to github.com" }, 0], [fido, 100]]);
eq(s.info.title, "Touch ID to sign in to github.com", "note before verify names the site");
eq(run([[{ ev: "fidoNote", title: "old" }, 0], [fido, 9000]]).info.title, "Passkey", "stale note ignored");
s = run([[fido, 0], [{ ev: "fidoNote", title: "Touch ID to register with webauthn.io" }, 50]]);
eq(s.info.title, "Touch ID to register with webauthn.io", "note after verify updates the card");
eq(reduce(s, { ev: "fidoClosed" }, 60).phase, "ending", "note closed ends a waiting fido card");
// A retry of the same fido request keeps its card (no flicker).
s = run([[fido, 0], [{ ev: "status", result: "verify-no-match", done: false }, 10], [fido, 20]]);
eq(s.phase, "nomatch", "retry keeps the miss note");

eq(run([[sudo, 0], [{ ev: "gone" }, 1]]).phase, "hidden", "fprintd gone");
eq(reduce(initial(), { ev: "tick" }, 5).phase, "hidden", "tick when hidden");
eq(reduce(initial(), { ev: "bogus" }, 5).phase, "hidden", "unknown event");

if (failed) { console.log(failed + " failed"); process.exit(1); }
console.log("touchid_model: all ok");
