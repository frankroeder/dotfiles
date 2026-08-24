#!/usr/bin/env node
"use strict";

const fs = require("fs");
const path = require("path");

const logic = require("./shortcuts_logic.js");
if (typeof logic.parse !== "function" || typeof logic.layoutColumns !== "function") {
  throw new Error("shipped shortcuts_logic.js did not export parse/layoutColumns");
}

let failed = 0;
function assert(cond, msg) {
  if (cond) console.log("ok  " + msg);
  else {
    failed += 1;
    console.log("FAIL  " + msg);
  }
}

function eq(got, expected, msg) {
  if (got === expected) console.log("ok  " + msg);
  else {
    failed += 1;
    console.log("FAIL  " + msg + " got=" + JSON.stringify(got) + " expected=" + JSON.stringify(expected));
  }
}

eq(logic.prettyDesc("toggle pin window (always on top)"), "Toggle pin window", "paren tail cut");
eq(logic.deriveDesc('hl.dsp.focus { workspace = "e+1" }'), "Next workspace", "derive next workspace");
eq(logic.deriveDesc("hl.dsp.window.close()"), "Close window", "derive close");

const chord = logic.parseChord('mod .. " + SHIFT + W"', null);
eq(chord.mods, "⌘⇧", "SUPER+SHIFT glyphs");
eq(chord.keys.join(","), "W", "W key");

const vol = logic.parseChord('"SHIFT + XF86AudioRaiseVolume"', null);
eq(vol.mods, "⇧", "media shift");
eq(vol.keys.join(","), "XF86AudioRaiseVolume", "media key token");
eq(logic.displayKeys(["h", "j", "k", "l"]), "H/J/K/L", "hjkl grouped");
eq(logic.displayKeys(["1", "2", "3", "4", "5", "6", "7", "8", "9", "0"]), "1–0", "workspace 1–10 wrap");

const sample = `
-- Apps and windows
hl.bind(mod .. " + T", hl.dsp.exec_cmd(launch(terminal)), { desc = "Terminal" })
hl.bind(mod .. " + SPACE", hl.dsp.global "quickshell:launcher-toggle", { desc = "Launcher" })
-- hl.bind(mod .. " + B", hl.dsp.exec_cmd(browser), { desc = "Browser" })
hl.bind(
  mod .. " + SHIFT + W",
  hl.dsp.exec_cmd "qs -c remix ipc call wallpaper toggle",
  { desc = "Wallpaper picker" }
)

-- Focus
hl.bind(mod .. " + H", hl.dsp.focus { direction = "l" }, { desc = "Focus left" })
hl.bind(mod .. " + L", hl.dsp.focus { direction = "r" }, { desc = "Focus right" })
hl.bind(mod .. " + K", hl.dsp.focus { direction = "u" }, { desc = "Focus up" })
hl.bind(mod .. " + J", hl.dsp.focus { direction = "d" }, { desc = "Focus down" })

-- Workspaces
for i = 1, 10 do
  local key = tostring(i % 10)
  hl.bind(mod .. " + " .. key, hl.dsp.focus { workspace = i }, { desc = "Workspace " .. i })
  hl.bind(
    mod .. " + CONTROL + " .. key,
    hl.dsp.window.move { workspace = i },
    { desc = "Move to workspace " .. i }
  )
end
hl.bind(mod .. " + I", hl.dsp.focus { workspace = "e-1" }, { desc = "Previous workspace" })
hl.bind(mod .. " + U", hl.dsp.focus { workspace = "e+1" }, { desc = "Next workspace" })
hl.bind(mod .. " + Page_Up", hl.dsp.focus { workspace = "e-1" }, { desc = "Previous workspace" })
hl.bind(mod .. " + Page_Down", hl.dsp.focus { workspace = "e+1" }, { desc = "Next workspace" })

-- Media
local function media_bind(key, action, opts)
  opts.locked = true
  hl.bind(key, hl.dsp.exec_cmd(scripts .. "/asahi-media-control " .. action), opts)
end
media_bind("XF86AudioRaiseVolume", "output-volume raise", { repeating = true, desc = "Volume up" })
media_bind("SHIFT + XF86AudioMute", "output-volume mute-toggle", { desc = "Mute" })
`;

const sections = logic.parse(sample);
eq(sections.length, 4, "four sections");
eq(sections[0].title, "Apps and windows", "apps section title");
eq(sections[1].title, "Focus", "focus section");
eq(sections[2].title, "Workspaces", "workspaces section");
eq(sections[3].title, "Media", "media section");

const apps = sections[0].rows;
eq(apps.length, 3, "apps rows (disabled browser skipped)");
eq(apps[0].desc, "Terminal", "terminal desc");
eq(apps[0].keys, "⌘ T", "terminal chord");
eq(apps[1].keys, "⌘ Space", "launcher space");
eq(apps[2].desc, "Wallpaper picker", "multiline bind desc");
eq(apps[2].keys, "⌘⇧ W", "multiline bind keys");
assert(!apps.some((r) => /Browser/i.test(r.desc)), "disabled bind excluded");

eq(sections[1].rows.length, 1, "focus directions merged");
eq(sections[1].rows[0].desc, "Focus", "focus prefix");
eq(sections[1].rows[0].keys, "⌘ H/L/K/J", "focus hjkl");

const ws = sections[2].rows;
const wsRow = ws.find((r) => r.desc === "Workspace");
const moveRow = ws.find((r) => r.desc === "Move to workspace");
const prevRow = ws.find((r) => r.desc === "Previous workspace");
const nextRow = ws.find((r) => r.desc === "Next workspace");
assert(!!wsRow, "workspace row exists");
eq(wsRow && wsRow.keys, "⌘ 1–0", "workspace 1–10 keys");
assert(!!moveRow, "move-to-workspace row exists");
eq(moveRow && moveRow.keys, "⌘⌃ 1–0", "move workspace uses control");
eq(prevRow && prevRow.keys, "⌘ I/⇞", "previous workspace merges page up");
eq(nextRow && nextRow.keys, "⌘ U/⇟", "next workspace merges page down");

eq(sections[3].rows.length, 2, "media helper body skipped");
eq(sections[3].rows[0].keys, "Vol+", "volume up key");
eq(sections[3].rows[1].keys, "⇧ Mute", "shift mute");

const layout = logic.layoutColumns(sections);
assert(layout.left.length > 0 && layout.right.length > 0, "two-column split");
eq(layout.source, "hypr", "source label hypr");
assert(layout.left[0].kind === "header", "left starts with header");

const bindingsPath = path.resolve(__dirname, "../../../../hypr/conf.d/bindings.lua");
const realText = fs.readFileSync(bindingsPath, "utf8");
const real = logic.parse(realText);
console.log("real sections " + real.length + " rows " + real.reduce((n, s) => n + s.rows.length, 0));
assert(real.length >= 8, "real bindings.lua has 8+ sections (" + real.length + ")");
const titles = real.map((s) => s.title);
assert(titles.indexOf("Apps and windows") !== -1, "real has Apps and windows");
assert(titles.indexOf("Workspaces") !== -1, "real has Workspaces");
assert(titles.indexOf("Media") !== -1, "real has Media");
assert(titles.indexOf("Keyboard Brightness") !== -1, "real has Keyboard Brightness");

const realApps = real.find((s) => s.title === "Apps and windows");
assert(realApps && realApps.rows.some((r) => r.desc === "Terminal" && r.keys === "⌘ T"), "real Terminal ⌘ T");
assert(realApps && realApps.rows.some((r) => r.desc === "Launcher" && r.keys === "⌘ Space"), "real Launcher ⌘ Space");
assert(realApps && !realApps.rows.some((r) => r.desc === "Browser"), "real commented Browser omitted");

const realWs = real.find((s) => s.title === "Workspaces");
assert(realWs && realWs.rows.some((r) => r.desc === "Workspace" && r.keys.indexOf("1–0") !== -1), "real workspace range");

const realMedia = real.find((s) => s.title === "Media");
assert(
  realMedia && realMedia.rows.some((r) => r.desc === "Volume" && String(r.keys).indexOf("Vol+") !== -1),
  "real volume grouped"
);
assert(realMedia && !realMedia.rows.some((r) => r.keys === "?"), "no placeholder chords from helper");

const qmlPath = path.join(__dirname, "components", "Shortcuts.qml");
const qml = fs.readFileSync(qmlPath, "utf8");
assert(qml.indexOf("ShortcutsLogic.parse") !== -1, "Shortcuts.qml uses shipped parser");
assert(qml.indexOf("KEYBOARD SHORTCUTS") !== -1, "Shortcuts.qml headed KEYBOARD SHORTCUTS");
assert(qml.indexOf("TooltipWindow") === -1, "Shortcuts.qml has no hover tooltip");
assert(qml.indexOf("bindings.lua") !== -1, "Shortcuts.qml reads bindings.lua");

if (failed > 0) {
  console.log("\n" + failed + " assertion(s) failed");
  process.exit(1);
}
console.log("\nall assertions passed");
