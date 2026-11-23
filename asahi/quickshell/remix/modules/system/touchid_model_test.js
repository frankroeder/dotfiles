#!/usr/bin/env node
"use strict";
// touchid_model.js: the Touch ID prompt's state machine.

const fs = require("fs");
const path = require("path");
const vm = require("vm");

const ctx = {};
vm.createContext(ctx);
vm.runInContext(fs.readFileSync(path.join(__dirname, "touchid_model.js"), "utf8"), ctx);
const { reduce, initial, visible, view } = ctx;

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

// What fprintd 1.94.5 really sends: VerifyStatus at once, the finger properties after it; a no-match is always done.
const P = (value) => ({ ev: "present", value }), N = (value) => ({ ev: "needed", value });
const S = (result) => ({ ev: "status", result, done: !result.startsWith("verify-retry") });
// Some drivers drop "needed" as the finger lands: the read goes on to its result (it used to end the card first).
s = run([[sudo, 0], [N(true), 1], [P(true), 1500], [N(false), 1500]]);
eq(s.phase, "reading", "needed=false while the finger is down does not end the read");
eq(reduce(s, S("verify-match"), 2400).phase, "match", "and its result shows");
s = run([[sudo, 0], [P(true), 100], [P(false), 400]]);
eq(s.phase, "reading", "a lift does not end the read either");
eq(reduce(s, { ev: "tick" }, 100 + 6000).phase, "ending", "a read with no result gives up after 6 s");

// Wrong finger: red, back to waiting when pam_fprintd tries again; after its last try the reason.
s = run([[sudo, 0], [P(true), 5], [S("verify-no-match"), 10], [P(false), 11], [N(false), 11]]);
eq([s.phase, view(s).strong, view(s).hint, view(s).tone], ["nomatch", "No match", "touch again", "fail"], "miss");
const again = reduce(s, sudo, 40);
eq([again.phase, reduce(again, { ev: "tick" }, 10 + 1400).phase], ["nomatch", "waiting"], "pam's next try: back to ready after the red");
s = reduce(s, { ev: "tick" }, 10 + 1400);
eq([s.phase, view(s).orb, view(s).strong, view(s).hint, view(s).tone], ["failed", "failed", "No match", "type your password", "fail"], "no next try: out of tries");
// The finger left lying is read again after the next try started: a miss again, not a cancel.
s = run([[sudo, 0], [P(true), 5], [S("verify-no-match"), 10], [sudo, 40], [P(true), 300]]);
s = reduce(reduce(s, { ev: "tick" }, 10 + 1400), S("verify-no-match"), 2000);
eq(s.phase, "nomatch", "a lying finger's second miss is a miss");
s = run([[sudo, 0], [{ ev: "status", result: "verify-retry-scan", done: false }, 1]]);
eq([s.phase, view(s).strong, view(s).tone], ["retry", "Not read", "warn"], "retry scan is amber, not a miss");
eq(reduce(s, { ev: "tick" }, 1 + 1400).phase, "waiting", "and goes back to waiting");
const why = (result) => { const v = view(run([[sudo, 0], [{ ev: "status", result, done: true }, 1]])); return [v.strong, v.tone]; };
eq(why("verify-lockout"), ["Touch ID locked", "fail"], "lockout");
eq(why("verify-password-required-48h"), ["Password needed to re-enable Touch ID", "warn"], "SEP password clock");
eq(why("verify-disconnected"), ["Touch ID disconnected", "warn"], "reader gone");
eq(why("verify-unknown-error"), ["Touch ID unavailable", "warn"], "anything else");
eq([view(run([[sudo, 0]])).orb, view(run([[sudo, 0]])).strong], ["ready", "Touch ID ready"], "waiting reads ready, like the lock screen");
eq(view(run([[sudo, 0], [{ ev: "present", value: true }, 1]])).orb, "reading", "finger down lights the ring");
eq(view(run([[sudo, 0], [{ ev: "status", result: "verify-match", done: true }, 1]])).strong, "Approved", "match");
eq(view(initial()).orb, "off", "no request: the orb is a lock");

// Ctrl+C on sudo: fprintd reports the cancelled verify as a no-match; with no finger down that is no miss.
s = run([[sudo, 0], [N(true), 1], [S("verify-no-match"), 2000], [N(false), 2001]]);
eq([s.phase, reduce(s, { ev: "tick" }, 2000 + 450).phase], ["ending", "hidden"], "cancel: the card just goes");
// fprintd stops waiting without a status: a short ending, then hidden; a result in that time still shows.
s = run([[sudo, 0], [N(false), 100]]);
eq([s.phase, reduce(s, { ev: "tick" }, 100 + 450).phase], ["ending", "hidden"], "needed=false while waiting ends");
eq(reduce(s, S("verify-match"), 101).phase, "match", "late status after needed=false");

// Lock screen / polkit draw their own: the notch card stays hidden, the state still runs (the polkit card's orb).
const polkit = { ev: "start", kind: "polkit", suppress: true, title: "Authentication" };
s = run([[polkit, 0]]);
eq([s.phase, s.suppressed, visible(s), s.info.kind], ["waiting", true, false, "polkit"], "suppressed request: tracked, not shown");
s = run([[{ ev: "present", value: true }, 2]], s);
eq([s.phase, visible(s)], ["reading", false], "its finger is read");
s = run([[S("verify-no-match"), 3], [polkit, 4]], s);
eq([s.phase, s.suppressed], ["nomatch", true], "pam_fprintd's next verify keeps the miss");
s = run([[P(true), 600], [S("verify-no-match"), 700], [{ ev: "tick" }, 700 + 1400]], s);
eq([s.phase, visible(s), view(s).hint], ["failed", false, "type your password"], "gave up: the card says why");
eq(reduce(s, { ev: "tick" }, 2100 + 2400).phase, "hidden", "then it is over");
eq(visible(run([[sudo, 5]], s)), true, "a later sudo shows the notch card again");
eq(visible(run([[{ ev: "start", kind: "lock", suppress: true }, 0], [{ ev: "present", value: true }, 1]])), false, "lock screen: never the notch card");

// aurora-fidod: its notification names the site, before or after the verify starts.
const fido = { ev: "start", kind: "fido", suppress: false, title: "Passkey", detail: "Security key request" };
s = run([[{ ev: "fidoNote", title: "Touch ID to sign in to github.com" }, 0], [fido, 100]]);
eq(s.info.title, "Touch ID to sign in to github.com", "note before verify names the site");
eq(run([[{ ev: "fidoNote", title: "old" }, 0], [fido, 9000]]).info.title, "Passkey", "stale note ignored");
s = run([[fido, 0], [{ ev: "fidoNote", title: "Touch ID to register with webauthn.io" }, 50]]);
eq(s.info.title, "Touch ID to register with webauthn.io", "note after verify updates the card");
eq(reduce(s, { ev: "fidoClosed" }, 60).phase, "ending", "note closed ends a waiting fido card");
// aurora-fido 0.2 (no fprintd verify): the note alone opens the card, its close ends it.
s = reduce(initial(), { ev: "fidoNote", title: "Touch ID to sign in to ssh:" }, 0);
eq(s.phase, "waiting", "note alone opens a fido card");
eq(s.info.title, "Touch ID to sign in to ssh:", "note names the card");
eq(reduce(s, { ev: "fidoClosed" }, 10).phase, "ending", "note close ends it");
// A retry of the same fido request keeps its card (no flicker).
s = run([[fido, 0], [P(true), 5], [S("verify-no-match"), 10], [fido, 20]]);
eq(s.phase, "nomatch", "retry keeps the miss note");

eq(run([[sudo, 0], [{ ev: "gone" }, 1]]).phase, "hidden", "fprintd gone");
eq(reduce(initial(), { ev: "tick" }, 5).phase, "hidden", "tick when hidden");
eq(reduce(initial(), { ev: "bogus" }, 5).phase, "hidden", "unknown event");

// Wiring: one orb everywhere (the lock screen's look), the polkit card reads the suppressed state.
const read = (f) => fs.readFileSync(path.join(__dirname, f), "utf8");
const card = read("TouchIdPrompt.qml"), polkitQml = read("PolkitAgent.qml"), orb = read("TouchIdOrb.qml"), shellQml = read("../../shell.qml");
eq([/TouchIdOrb \{/.test(card), /TouchIdLine \{/.test(card), /Model\.view\(root\.st\)/.test(card)], [true, true, true], "notch card: orb + line from view()");
eq([/TouchIdOrb \{/.test(polkitQml), /TouchIdLine \{/.test(polkitQml), /root\.touchId\.st\.info\.kind === "polkit"/.test(polkitQml),
  /System\.PolkitAgent \{ touchId: touchIdCard \}/.test(shellQml)], [true, true, true, true], "polkit card: the same orb, fed by the notch card's state");
eq(/opacity: field\.enabled \? 1 : 0\.5/.test(polkitQml), true, "polkit: the password pill is dim until PAM asks for it");
eq(/now !== was && \(now === "nomatch" \|\| \(now === "failed" && was !== "nomatch"\)\)/.test(card), true, "the card shakes once per miss");
eq(["ready", "reading", "match", "nomatch", "retry", "failed", "off"].every((ph) => orb.includes('"' + ph + '"')), true, "the orb knows every phase view() names");
eq([/Style\.vivid\b/.test(orb), /Style\.vivid2/.test(orb)], [true, true], "orb: the lock's accent pair");
// Animated: scanning arc while reading, a pop as each result lands, the line rises in, the card
// drops out from under the bar (his pick 2026-11-20: not over it); the polkit card grows out of the notch (IslandCard).
// Nothing runs while hidden: loops are tied to `live`.
const lineQml = read("TouchIdLine.qml");
eq([/RotationAnimator on rotation/.test(orb), /onPhaseChanged: if \(orb\.live && orb\.lit\) land\.restart\(\)/.test(orb),
  /onMessageChanged: if \(line\.live\) rise\.restart\(\)/.test(lineQml), /y: root\.shown \? 0 : -12/.test(card),
  /IslandCard \{[\s\S]*?shown: root\.shown/.test(polkitQml)],
  [true, true, true, true, true], "animations: scan, land, rise, drop (Touch ID), island (polkit)");
eq((orb + lineQml).match(/running: [^\n]*/g).every((r) => /\.live && /.test(r)), true, "looping animations run only while shown");
// A QML Timer can fire a frame early: the tick is aimed past `until` and set per state (a binding kept the old
// interval, so a state outlived its time by a whole period).
eq([/tick\.interval = Math\.max\(16, root\.st\.until - Date\.now\(\) \+ 20\)/.test(card), /interval: Math\.max\(16, root\.st\.until/.test(card)],
  [true, false], "tick aims past until");

if (failed) { console.log(failed + " failed"); process.exit(1); }
console.log("touchid_model: all ok");
