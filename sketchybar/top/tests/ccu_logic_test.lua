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
local friday = os.time { year = 2026, month = 8, day = 21, hour = 12 }
eq(logic.week_header(days, friday), "Last 7 days · 100", "week header")
eq(logic.day_label "2026-08-21", "Fri", "2026-08-21 is Fri")

local cols, peak, total = logic.chart_columns(days, friday)
eq(peak, 50, "chart peak")
eq(total, 100, "chart total")
eq(cols[2].compact, "0", "zero day compact")
eq(cols[2].height, 0, "zero day height")
eq(cols[3].compact, "50", "peak compact")
eq(cols[3].label, "Mon", "2026-08-17 is Mon")
eq(cols[7].label, "Fri", "rightmost is current day")
eq(cols[1].date, "2026-08-15", "leftmost is 6 days ago")
eq(logic.spark_char(0), "·", "zero spark is a dot not a fake bar")
eq(logic.spark_char(1), "█", "peak spark")
local cl, sl, ll = logic.chart_lines(days, friday)
ok(sl:find("██", 1, true), "week bars are two blocks wide")
ok(cl:find("50", 1, true), "chart counts line has peak")
ok(cl:find("0", 1, true), "chart counts line has zero day")
ok(ll:find("Mon", 1, true) and ll:find("Sat", 1, true), "chart labels packed Sat..Mon")
ok(not cl:find("padding", 1, true), "chart lines are plain text")
eq(utf8.len(cl), 7 * logic.CHART_CELL, "7 chart count cells")
eq(utf8.len(ll), 7 * logic.CHART_CELL, "7 chart label cells")
eq(logic.chart_cell_for(440), 10, "440px popup → 10-wide cells")
eq(logic.chart_cell_for(400), 9, "400px popup → 9-wide cells")
local cl11 = select(1, logic.chart_lines(days, friday, 11))
eq(utf8.len(cl11), 7 * 11, "chart_lines honors cell width")
ok(logic.pad_cell("0", 8):find("\u{2007}", 1, true), "pad_cell uses figure space")
ok(not logic.pad_cell("0", 8):find(" ", 1, true), "pad_cell no ascii space")
eq(utf8.len(logic.center_cell("24.5M", 8)), 8, "center_cell width 8")
local sunday = os.time { year = 2026, month = 8, day = 23, hour = 12 }
local rolled = logic.chart_columns(days, sunday)
eq(rolled[1].date, "2026-08-17", "sunday window starts Mon 17")
eq(rolled[1].label, "Mon", "sunday window leftmost Mon")
eq(rolled[7].date, "2026-08-23", "sunday window ends today")
eq(rolled[7].label, "Sun", "rightmost is today")
eq(rolled[7].compact, "0", "today with no data is zero")
eq(rolled[1].compact, "50", "Mon 17 tokens follow the date not list order")
local empty_week = logic.last_7_days({}, sunday)
eq(#empty_week, 7, "empty input still last 7 days")
eq(empty_week[1].date, "2026-08-17", "empty window starts 6d ago")
eq(empty_week[7].date, "2026-08-23", "empty window ends today")
eq(empty_week[7].tokens, 0, "empty today is zero")
local keyed = { d = { date = "2026-08-23", tokens = 9 } }
eq(logic.last_7_days(keyed, sunday)[7].tokens, 9, "date-keyed days still map")
local shuffled = {
  days[7],
  days[1],
  days[4],
  days[3],
  days[6],
  days[2],
  days[5],
}
local ordered = logic.chart_columns(shuffled, friday)
eq(ordered[1].date, "2026-08-15", "shuffled input still oldest-left")
eq(ordered[7].label, "Fri", "shuffled input still today-right")
local with_usd = {
  { date = "2026-08-15", tokens = 10, usd = 1 },
  { date = "2026-08-16", tokens = 0, usd = 0 },
  { date = "2026-08-17", tokens = 50, usd = 4 },
  { date = "2026-08-18", tokens = 20, usd = 2 },
  { date = "2026-08-19", tokens = 0, usd = 0 },
  { date = "2026-08-20", tokens = 5, usd = 0.5 },
  { date = "2026-08-21", tokens = 15, usd = 1.5 },
}
local wtok, wusd = logic.window_sum(with_usd, friday)
eq(wtok, 100, "window_sum tokens")
eq(wusd, 9, "window_sum usd")

eq(logic.month_line(5.63e7), "This month · 56.3M", "month line")
eq(logic.total_line(1.86e8), "All time · 186M", "all-time line")
eq(logic.usd(12.3), "$12.30", "usd cents")
eq(logic.usd(100), "$100", "usd dollars")
eq(logic.usd(1500), "$1.5k", "usd thousands")
eq(logic.month_line(5.63e7, 12.3), "This month · 56.3M · $12.30", "month line with cost")
eq(logic.total_line(1.86e8, 1500), "All time · 186M · $1.5k", "all-time line with cost")
eq(logic.all_line(1.86e8, 1500), "All · 186M · $1.5k", "all window cell")
eq(logic.days30_line(5.63e7, 12.3), "30d · 56.3M · $12.30", "30d window cell")
eq(logic.week_line(450e6, 8), "7d · 450M · $8.00", "7d window cell")
eq(logic.stat_line("30d", nil, nil), "30d · —", "missing window is em dash")

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
eq(logic.next_bar(1, 2), 2, "rotate 1/2 → 2")
eq(logic.next_bar(2, 2), 1, "rotate 2/2 → 1")
eq(logic.next_bar(1, 1), 1, "rotate single stays")
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
