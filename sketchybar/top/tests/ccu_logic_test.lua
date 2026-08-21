-- Drive shipped CCU format/pace/chart helpers. No sbar, no reimplementation oracle.
local src = debug.getinfo(1, "S").source:gsub("^@", "")
if not src:match "^/" then
  local pwd = os.getenv "PWD" or "."
  src = pwd .. "/" .. src
end
local root = src:gsub("sketchybar/top/tests/ccu_logic_test.lua$", "")
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

local logic = require "ccu_logic"

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
    fail(msg .. " got=" .. tostring(got) .. " expected=" .. tostring(expected))
  end
end

local now = 1700000000
local week = logic.WEEK_SEC

-- Image #1-like weekly: 31% used, 15h 59m to reset
local claude_reset = now + 15 * 3600 + 59 * 60
local claude = logic.weekly(0.31, claude_reset)
eq(logic.percent(claude.used), "31%", "31% used")
eq(logic.countdown(claude_reset, now), "15h 59m", "15h 59m countdown")
ok(logic.countdown(claude_reset, now):find "h", "countdown has h")
ok(logic.countdown(claude_reset, now):find "m", "countdown has m")
eq(logic.used_line(claude, now), "31% used · resets in 15h 59m", "used · resets in")

local codex_reset = now + 4 * 86400 + 22 * 3600
local codex = logic.weekly(0.18, codex_reset)
eq(logic.countdown(codex_reset, now), "4d 22h", "4d 22h countdown")
eq(logic.bar_chip("Claude", claude, now), "Claude 31% · 15h 59m", "claude chip")
eq(logic.bar_chip("Codex", codex, now), "Codex 18% · 4d 22h", "codex chip")

local bar = logic.bar_label({
  { name = "Claude", weekly = claude },
  { name = "Codex", weekly = codex },
}, now)
ok(bar:find("Claude", 1, true), "bar has Claude")
ok(bar:find("31%", 1, true), "bar has 31%")
ok(bar:find("·", 1, true), "bar has ·")
ok(bar:find("15h 59m", 1, true), "bar has countdown")
ok(bar:find("Codex", 1, true), "bar has Codex")
ok(not bar:find("CCu", 1, true), "bar is not CCu aggregate")
print("bar=" .. bar)

local grok = logic.weekly(0.22, now + 3 * 86400, week)
local cursor = logic.from_helper_window {
  utilization = 31,
  reset_unix = now + 16 * 86400,
  span_sec = 30 * 86400,
}
eq(logic.bar_chip("Grok", grok, now), "Grok 22% · 3d 0h", "grok chip")
eq(logic.bar_chip("Cursor", cursor, now), "Cursor 31% · 16d 0h", "cursor chip")
local primary = logic.bar_label({
  { name = "Grok", weekly = grok },
  { name = "Cursor", weekly = cursor },
}, now)
ok(primary:find("Grok", 1, true) and primary:find("Cursor", 1, true), "primary bar Grok+Cursor")
print("primary=" .. primary)

-- monthly window (Cursor): 70% elapsed of 30d, same behind-pace rule
local month = 30 * 86400
local month_reset = now + 0.3 * month
ok(logic.behind_pace(logic.weekly(0.76, month_reset, month), now), "76% of month at 70% elapsed is behind")
ok(not logic.behind_pace(logic.weekly(0.58, month_reset, month), now), "58% of month at 70% elapsed is not behind")
eq(logic.expected_text(logic.weekly(0.58, month_reset, month), now), "Expected 70% used", "monthly expected uses span")

-- 16h exactly still an h/m countdown (Model.js includes minutes)
eq(logic.countdown(now + 16 * 3600, now), "16h 0m", "16h 0m")
eq(logic.countdown(now, now), "now", "now when reset==now")
eq(logic.countdown(0, now), "now", "now when reset missing")

-- 70% of the week elapsed
local reset70 = now + 0.3 * week
local behind = logic.weekly(0.76, reset70)
local ahead = logic.weekly(0.58, reset70)
ok(logic.behind_pace(behind, now), "76% used at 70% elapsed is behind pace")
ok(not logic.behind_pace(ahead, now), "58% used at 70% elapsed is not behind")
eq(logic.pace_text(behind, now), "6% behind pace", "behind pace text")
eq(logic.pace_text(ahead, now), "12% ahead of pace", "ahead of pace text")
eq(logic.expected_text(behind, now), "Expected 70% used", "Expected N% used")
eq(logic.pace_text(logic.weekly(0.70, reset70), now), "On pace", "on pace")

-- compact tokens (Model.js tokenCount)
eq(logic.token_count(5.63e7), "56.3M", "5.63e7 → 56.3M")
eq(logic.token_count(1.86e8), "186M", "1.86e8 → 186M")
eq(logic.token_count(1000), "1K", "1000 → 1K")
eq(logic.token_count(999), "999", "999 stays raw")
eq(logic.token_count(1e9), "1B", "1e9 → 1B")

-- 7-day total / peak / zero-height
local days = {
  { date = "2026-08-15", tokens = 10 },
  { date = "2026-08-16", tokens = 0 },
  { date = "2026-08-17", tokens = 50 },
  { date = "2026-08-18", tokens = 20 },
  { date = "2026-08-19", tokens = 0 },
  { date = "2026-08-20", tokens = 5 },
  { date = "2026-08-21", tokens = 15 },
}
eq(logic.recent_total(days), 100, "7-day total")
eq(logic.recent_peak(days), 50, "7-day peak")
eq(logic.bar_height(0, 50), 0, "zero day has no bar")
eq(logic.bar_height(50, 50), 1, "peak day is full height")
eq(logic.bar_height(20, 50), 0.4, "20/50 height")
eq(logic.week_header(days), "LAST 7 DAYS · 100 TOKENS", "week header")
eq(logic.day_label "2026-08-21", "Fri", "2026-08-21 is Fri")

local cols, peak, total = logic.chart_columns(days)
eq(peak, 50, "chart peak")
eq(total, 100, "chart total")
eq(cols[2].compact, "0", "zero day compact")
eq(cols[2].height, 0, "zero day height")
eq(cols[3].compact, "50", "peak compact")
eq(cols[3].label, "Mon", "2026-08-17 is Mon")
eq(logic.spark_char(0), "▁", "zero spark")
eq(logic.spark_char(1), "█", "peak spark")
local cl, sl, ll = logic.chart_lines(days)
ok(cl:find("50", 1, true), "chart counts line has peak")
ok(cl:find("0", 1, true), "chart counts line has zero day")
ok(ll:find("Mon", 1, true) and ll:find("Sat", 1, true), "chart labels packed Sat..Mon")
ok(not cl:find("padding", 1, true), "chart lines are plain text")
eq(#cl, 42, "7×6 count cells")
eq(#ll, 42, "7×6 label cells")

-- helper window mapping (0–100 used + reset_unix)
local win = logic.from_helper_window { used = 31, reset_unix = claude_reset }
eq(logic.percent(win.used), "31%", "helper used 31 → 31%")
eq(logic.countdown(win.reset, now), "15h 59m", "helper reset_unix")

local extras = logic.extra_windows {
  { kind = "session", label = "Session", used = 42, reset_unix = now + 3 * 3600 + 12 * 60 },
  { kind = "weekly_all", label = "Weekly", used = 31, reset_unix = claude_reset },
  { kind = "weekly_scoped", label = "Fable", used = 12, reset_unix = codex_reset },
}
eq(#extras, 2, "session + fable extras, weekly dropped")
eq(extras[1].label, "Session (5-hour)", "session extra label")
eq(extras[2].label, "Fable Weekly", "fable extra label")
eq(logic.extra_line(extras[1].weekly, now), "42% used · 3h 12m", "extra line has no resets-in")
ok(logic.is_extra "Fable Weekly", "Fable Weekly is extra")
ok(not logic.is_extra "Weekly", "Weekly is not extra")
ok(not logic.is_extra "Weekly limit (7-day)", "weekly 7-day is not extra")

local cursor_extras = logic.extra_windows {
  { kind = "cursor_auto", label = "Cursor Models", used = 40, reset_unix = now + 86400 },
  { kind = "cursor_api", label = "Other Models", used = 12, reset_unix = now + 86400 },
}
eq(#cursor_extras, 2, "cursor auto+api extras")
eq(cursor_extras[1].label, "Cursor Models", "cursor models extra")
eq(cursor_extras[2].label, "Other Models", "cursor other extra")
eq(logic.extra_line(cursor_extras[2].weekly, now), "12% used · 1d 0h", "cursor extra line")

eq(logic.bar_chip("Codex", nil, now), "Codex —", "unavailable weekly chip")
eq(logic.used_line(nil, now), "Weekly limit unavailable", "unavailable used line")

-- iso fallback
local iso = logic.iso_to_unix "2026-01-01T00:00:00Z"
ok(iso ~= nil, "iso_to_unix parses")
eq(logic.iso_to_unix "2026-01-01T00:00:00Z", logic.iso_to_unix "2026-01-01 00:00:00", "iso T and space")

if failures > 0 then
  print(failures .. " failed")
  os.exit(1)
end
print "all passed"
