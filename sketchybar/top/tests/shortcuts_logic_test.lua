-- Drive the shipped skhdrc parser against a synthetic config + the real file.
local src = debug.getinfo(1, "S").source:gsub("^@", "")
if not src:match "^/" then
  local pwd = os.getenv "PWD" or "."
  src = pwd .. "/" .. src
end
local root = src:gsub("sketchybar/top/tests/shortcuts_logic_test.lua$", "")
if root == src then
  root = os.getenv "DOTFILES" or (os.getenv "HOME" .. "/.dotfiles")
  if root:sub(-1) ~= "/" then
    root = root .. "/"
  end
end

package.path = root
  .. "sketchybar/?.lua;"
  .. root
  .. "sketchybar/?/init.lua;"
  .. root
  .. "sketchybar/top/?.lua;"
  .. package.path

local logic = require "shortcuts_logic"

local failures = 0
local function fail(msg)
  failures = failures + 1
  io.stderr:write("FAIL " .. msg .. "\n")
end

local function ok(cond, msg)
  if cond then
    print("ok  " .. msg)
  else
    fail(msg)
  end
end

local function eq(got, expected, msg)
  if got == expected then
    print("ok  " .. msg)
  else
    fail(msg .. " (got " .. tostring(got) .. ", expected " .. tostring(expected) .. ")")
  end
end

-- desc cleanup
eq(logic.pretty_desc "move window to (n)ext display", "Move window to next display", "paren hints inlined")
eq(
  logic.pretty_desc "change layout of space (i3 defaults) — layout type only: pill refresh",
  "Change layout of space",
  "em-dash and paren tails cut"
)
eq(logic.pretty_desc "swap same-space: window_moved signal.", "Swap same-space", "colon tail cut")
eq(logic.pretty_desc "going stack (u)p and (d)own", "Going stack up and down", "multiple hints inlined")

-- derived descriptions
eq(logic.derive_desc "vicinae deeplink vicinae://launch/files/search", "Files search", "vicinae plugin path")
eq(logic.derive_desc 'open "vicinae://launch/manage-shortcuts/manage"', "Manage shortcuts", "vicinae dedup words")
eq(
  logic.derive_desc "vicinae deeplink vicinae://launch/@Dev/store.raycast.thing/proofread",
  "Proofread",
  "vicinae store path uses command"
)
eq(logic.derive_desc 'open "x-apple.systempreferences:"', "System Settings", "system settings url")
eq(logic.derive_desc 'open -a "About This Mac"', "About This Mac", "open -a quoted")
eq(logic.derive_desc 'yabai -m space --focus 5; open "/Applications/Signal.app/"', "Signal", "app bundle path")
eq(logic.derive_desc 'bash "$DOTFILES/scripts/toggle_app.bash" "$BROWSER_NAME"', "Toggle Browser", "env var app")
eq(logic.derive_desc 'bash "$DOTFILES/bin/Darwin/pick-screenshot"', "Pick screenshot", "script basename")
eq(logic.derive_desc 'yabai -m space --focus 3 || skhd -k "x"', "Focus space", "digit focus generic")

-- synthetic parse: sections, grouping, disabled bindings, continuations
local sample = [[
#!/usr/bin/env sh
# =============================================================================
# Modifiers: meh = ctrl+alt+shift | hyper = ctrl+alt+shift+cmd
# =============================================================================

# reload things
ctrl + alt + cmd - r : \
  yabai --restart-service; \
  skhd --restart-service;

########
#  FN  #
########

# # change window focus
fn - h : yabai -m window --focus west
fn - j : yabai -m window --focus south
fn - k : yabai -m window --focus north
fn - l : yabai -m window --focus east

fn - 1 : yabai -m space --focus 1 || skhd -k "ctrl + alt + cmd - 1"
fn - 2 : yabai -m space --focus 2 || skhd -k "ctrl + alt + cmd - 2"
fn - 3 : yabai -m space --focus 3
fn - 4 : yabai -m space --focus 4

# yabai scratchpads
fn + alt - m : yabai -m window --toggle music || open -a Music
# fn + alt - n : yabai -m window --toggle notes || open -a Notes
fn + alt - p : yabai -m window --toggle pw || open -a "Proton Pass"

# #######################################
#         Applications and Tools        #
# #######################################
meh - f : vicinae deeplink vicinae://launch/files/search
fn + shift - space: yabai -m window --toggle split
]]

local sections = logic.parse(sample)
eq(#sections, 3, "three sections")
eq(sections[1].title, "General", "leading bindings land in General")
eq(sections[2].title, "FN", "boxed FN header")
eq(sections[3].title, "Applications and Tools", "wide boxed header")

eq(#sections[1].rows, 1, "general has one row")
eq(sections[1].rows[1].desc, "Reload things", "continuation binding keeps comment")
eq(sections[1].rows[1].keys, "⌃⌥⌘ R", "mods render as glyphs")

local fn = sections[2].rows
eq(#fn, 3, "FN rows grouped")
eq(fn[1].desc, "Change window focus", "hash-prefixed comment stripped")
eq(fn[1].keys, "fn H/J/K/L", "hjkl grouped")
eq(fn[2].desc, "Focus space", "digit rows derive desc")
eq(fn[2].keys, "fn 1–4", "differing || tails still merge into range")
eq(fn[3].desc, "Yabai scratchpads", "comment survives disabled binding between")
eq(fn[3].keys, "fn⌥ M/P", "meh-free combo mods + grouped keys")

local apps = sections[3].rows
eq(#apps, 2, "apps rows")
eq(apps[1].keys, "⌃⌥⇧ F", "meh expands to glyphs")
eq(apps[1].desc, "Files search", "derived vicinae desc")
eq(apps[2].keys, "fn⇧ Space", "no-space-before-colon binding parses")

for _, sec in ipairs(sections) do
  for _, row in ipairs(sec.rows) do
    ok(not row.desc:match "[Nn]otes", "disabled binding excluded: " .. row.desc)
  end
end

-- real skhdrc must parse into a useful list
local f = io.open(root .. "skhd/skhdrc", "r")
ok(f ~= nil, "real skhdrc readable")
if f then
  local real = logic.parse(f:read "*a")
  f:close()
  ok(#real >= 5, "real file has 5+ sections (" .. #real .. ")")
  local titles = {}
  local n_rows = 0
  for _, sec in ipairs(real) do
    titles[sec.title] = true
    n_rows = n_rows + #sec.rows
    for _, row in ipairs(sec.rows) do
      ok(row.desc ~= "" and row.keys ~= "", sec.title .. ": " .. row.desc .. " [" .. row.keys .. "]")
    end
  end
  ok(titles["FN"] and titles["FN + SHIFT"] and titles["SHIFT + ALT"], "real section titles found")
  ok(n_rows >= 35 and n_rows <= 70, "sane grouped row count (" .. n_rows .. ")")
end

if failures > 0 then
  print(failures .. " failed")
  os.exit(1)
end
print "all passed"
