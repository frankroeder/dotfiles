-- Pace / countdown / token / chart math for the top-bar CCU widget.
-- Mirrors robzolkos/omarchy-agent-usage Model.js. No sbar.
local M = {}

M.WEEK_SEC = 7 * 24 * 60 * 60
M.TITLE = "AGENT USAGE"
M.AHEAD = "ahead of pace"
M.BEHIND = "behind pace"
M.ON_PACE = "On pace"
M.NO_WEEKLY = "Weekly limit unavailable"
M.DOW = { "Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat" }

function M.clamp(value, lo, hi)
  if value < lo then
    return lo
  end
  if value > hi then
    return hi
  end
  return value
end

function M.number(value, fallback)
  local n = tonumber(value)
  if n == nil then
    return fallback
  end
  return n
end

-- used is a 0–1 fraction (Model.js). Helpers that emit 0–100 must divide first.
-- span is the window length in seconds (7d default; Cursor/Grok billing period when known).
function M.weekly(used, reset, span)
  if used == nil then
    return nil
  end
  local u = M.clamp(M.number(used, 0), 0, 1)
  local s = M.number(span, M.WEEK_SEC)
  if s <= 0 then
    s = M.WEEK_SEC
  end
  return { used = u, remaining = 1 - u, reset = M.number(reset, 0), span = s }
end

-- Claude/Grok/Cursor helpers emit used as 0–100 plus resets_at ISO and optional reset_unix.
function M.from_helper_window(block)
  if type(block) ~= "table" then
    return nil
  end
  local used = tonumber(block.used)
  if used == nil then
    used = tonumber(block.utilization)
  end
  if used == nil then
    return nil
  end
  local reset = tonumber(block.reset_unix) or M.iso_to_unix(block.resets_at)
  local span = tonumber(block.span_sec)
  if not span then
    local start = tonumber(block.period_start_unix) or M.iso_to_unix(block.period_start)
    if start and reset and reset > start then
      span = reset - start
    end
  end
  return M.weekly(used / 100, reset, span)
end

function M.extra_windows(limits)
  local out = {}
  if type(limits) ~= "table" then
    return out
  end
  for i = 1, #limits do
    local lim = limits[i]
    if type(lim) == "table" and lim.kind ~= "weekly_all" then
      local label = M.extra_label(lim)
      if M.is_extra(label) then
        out[#out + 1] = { label = label, weekly = M.from_helper_window(lim) }
      end
    end
  end
  return out
end

function M.percent(value)
  return string.format("%.0f%%", math.floor(M.clamp(M.number(value, 0), 0, 1) * 100 + 0.5))
end

function M.countdown(reset, now)
  reset = M.number(reset, 0)
  now = M.number(now, 0)
  if reset <= 0 or reset <= now then
    return "now"
  end
  local minutes = math.max(0, math.floor((reset - now) / 60))
  local days = math.floor(minutes / 1440)
  local hours = math.floor((minutes % 1440) / 60)
  local mins = minutes % 60
  if days > 0 then
    return days .. "d " .. hours .. "h"
  end
  if hours > 0 then
    return hours .. "h " .. mins .. "m"
  end
  return mins .. "m"
end

function M.expected_remaining(weekly, now)
  if not weekly or M.number(weekly.reset, 0) <= 0 then
    return 0
  end
  local span = M.number(weekly.span, M.WEEK_SEC)
  if span <= 0 then
    span = M.WEEK_SEC
  end
  return M.clamp((weekly.reset - now) / span, 0, 1)
end

function M.behind_pace(weekly, now)
  if not weekly or M.number(weekly.reset, 0) <= 0 then
    return false
  end
  return weekly.remaining + 0.0005 < M.expected_remaining(weekly, now)
end

function M.pace_difference(weekly, now)
  if not weekly then
    return 0
  end
  return weekly.remaining - M.expected_remaining(weekly, now)
end

function M.pace_text(weekly, now)
  if not weekly then
    return "No weekly limit"
  end
  local points = math.floor(math.abs(M.pace_difference(weekly, now)) * 100 + 0.5)
  if points == 0 then
    return M.ON_PACE
  end
  if M.behind_pace(weekly, now) then
    return points .. "% " .. M.BEHIND
  end
  return points .. "% " .. M.AHEAD
end

function M.expected_text(weekly, now)
  return "Expected " .. M.percent(1 - M.expected_remaining(weekly, now)) .. " used"
end

function M.used_line(weekly, now)
  if not weekly then
    return M.NO_WEEKLY
  end
  return M.percent(weekly.used) .. " used · resets in " .. M.countdown(weekly.reset, now)
end

function M.extra_line(weekly, now)
  if not weekly then
    return "—"
  end
  return M.percent(weekly.used) .. " used · " .. M.countdown(weekly.reset, now)
end

function M.bar_chip(name, weekly, now)
  if not weekly then
    return name .. " —"
  end
  return name .. " " .. M.percent(weekly.used) .. " · " .. M.countdown(weekly.reset, now)
end

function M.next_bar(i, n)
  if n < 1 then
    return 1
  end
  return (i % n) + 1
end

function M.bar_label(chips, now)
  local parts = {}
  for i, c in ipairs(chips or {}) do
    parts[i] = M.bar_chip(c.name, c.weekly, now)
  end
  return table.concat(parts, "  ")
end

local function strip_point_zero(s)
  return (s:gsub("%.0$", ""))
end

function M.token_count(value)
  local amount = math.max(0, M.number(value, 0))
  if amount >= 1e9 then
    local digits = amount >= 1e10 and 0 or 1
    return strip_point_zero(string.format("%." .. digits .. "f", amount / 1e9)) .. "B"
  end
  if amount >= 1e6 then
    local digits = amount >= 1e8 and 0 or 1
    return strip_point_zero(string.format("%." .. digits .. "f", amount / 1e6)) .. "M"
  end
  if amount >= 1e3 then
    local digits = amount >= 1e5 and 0 or 1
    return strip_point_zero(string.format("%." .. digits .. "f", amount / 1e3)) .. "K"
  end
  return string.format("%.0f", amount)
end

function M.day_tokens(day)
  if type(day) ~= "table" then
    return 0
  end
  return math.max(0, M.number(day.tokens, M.number(day.messageCount, 0)))
end

function M.recent_total(days)
  local total = 0
  for i = 1, #(days or {}) do
    total = total + M.day_tokens(days[i])
  end
  return total
end

function M.recent_peak(days)
  local peak = 0
  for i = 1, #(days or {}) do
    local n = M.day_tokens(days[i])
    if n > peak then
      peak = n
    end
  end
  return peak
end

function M.day_label(value)
  local y, m, d = tostring(value or ""):match "^(%d%d%d%d)%-(%d%d)%-(%d%d)$"
  if not y then
    return "—"
  end
  local t = os.time { year = tonumber(y), month = tonumber(m), day = tonumber(d), hour = 12 }
  return M.DOW[tonumber(os.date("%w", t)) + 1]
end

function M.bar_height(tokens, peak)
  tokens = M.number(tokens, 0)
  peak = M.number(peak, 0)
  if tokens <= 0 or peak <= 0 then
    return 0
  end
  return tokens / peak
end

-- Rolling window: oldest on the left, current local day on the right.
function M.last_7_days(days, now)
  local t = os.date("*t", M.number(now, os.time()))
  t.hour, t.min, t.sec = 12, 0, 0
  local today = os.time(t)
  local by_date = {}
  for _, day in pairs(days or {}) do
    if type(day) == "table" and day.date then
      by_date[tostring(day.date)] = day
    end
  end
  local out = {}
  for i = 1, 7 do
    local d = os.date("*t", today)
    d.day = d.day - (7 - i)
    d.hour = 12
    local ts = os.time(d)
    local key = os.date("%Y-%m-%d", ts)
    local src = by_date[key]
    out[i] = {
      date = key,
      dow = M.DOW[tonumber(os.date("%w", ts)) + 1],
      tokens = src and M.day_tokens(src) or 0,
      usd = src and M.number(src.usd, 0) or 0,
    }
  end
  return out
end

function M.week_header(days, now, usd)
  local tok, u = M.window_sum(days, now)
  if usd ~= nil then
    u = usd
  end
  return M.stat_line("Last 7 days", tok, (u and u > 0) and u or nil)
end

function M.window_sum(days, now)
  local list = M.last_7_days(days, now)
  local tok, usd = 0, 0
  for i = 1, #list do
    tok = tok + list[i].tokens
    usd = usd + M.number(list[i].usd, 0)
  end
  return tok, usd
end

-- Same steps as master bottom-bar ccu: $1.5k / $120 / $12.34
function M.usd(u)
  u = M.number(u, 0)
  if u >= 1000 then
    return string.format("$%.1fk", u / 1000)
  end
  if u >= 100 then
    return string.format("$%.0f", u)
  end
  return string.format("$%.2f", u)
end

function M.stat_line(label, tokens, usd)
  if tokens == nil and usd == nil then
    return label .. " · —"
  end
  local s = label .. " · " .. M.token_count(tokens or 0)
  if usd ~= nil then
    s = s .. " · " .. M.usd(usd)
  end
  return s
end

function M.month_line(tokens, usd)
  return M.stat_line("This month", tokens, usd)
end

function M.total_line(tokens, usd)
  return M.stat_line("All time", tokens, usd)
end

function M.all_line(tokens, usd)
  return M.stat_line("All", tokens, usd)
end

function M.days30_line(tokens, usd)
  return M.stat_line("30d", tokens, usd)
end

function M.week_line(tokens, usd)
  return M.stat_line("7d", tokens, usd)
end

function M.chart_columns(days, now)
  local list = M.last_7_days(days, now)
  local peak = M.recent_peak(list)
  local cols = {}
  for i = 1, 7 do
    local day = list[i]
    local tokens = M.day_tokens(day)
    local date = day and day.date
    cols[i] = {
      date = date,
      tokens = tokens,
      compact = M.token_count(tokens),
      height = M.bar_height(tokens, peak),
      label = (day and day.dow) or M.day_label(date),
    }
  end
  return cols, peak, M.recent_total(list)
end

M.SPARK = { "▁", "▂", "▃", "▄", "▅", "▆", "▇", "█" }

function M.spark_char(height)
  height = M.number(height, 0)
  if height <= 0 then
    return "·"
  end
  local i = math.floor(height * (#M.SPARK - 1) + 1.5)
  if i < 2 then
    i = 2
  end
  if i > #M.SPARK then
    i = #M.SPARK
  end
  return M.SPARK[i]
end

-- ASCII space / NBSP are trimmed AND collapsed by sketchybar, which jammed
-- "24.5M" into "294M". Figure space is digit-wide and survives as interior pad.
M.FIGSP = "\u{2007}"

function M.pad_cell(s, w)
  s = tostring(s or "")
  local n = (utf8 and utf8.len(s)) or #s
  if n >= w then
    return s
  end
  return s .. string.rep(M.FIGSP, w - n)
end

function M.center_cell(s, w)
  s = tostring(s or "")
  local n = (utf8 and utf8.len(s)) or #s
  if n >= w then
    return s
  end
  local left = math.floor((w - n) / 2)
  return string.rep(M.FIGSP, left) .. s .. string.rep(M.FIGSP, w - n - left)
end

-- Three monospaced lines (counts / spark / weekdays). Menlo 10pt ≈ 6.02px/char;
-- default 10 fills a 440px popup (7×10=421). Floor so 24.5M never jams.
M.CHART_CELL = 10
M.MONO_PX = 6.02

function M.chart_cell_for(width)
  local n = math.floor(M.number(width, 0) / (M.MONO_PX * 7))
  if n < 8 then
    return 8
  end
  return n
end

function M.chart_lines(days, now, cell)
  local cols = M.chart_columns(days, now)
  local w = math.floor(M.number(cell, M.CHART_CELL))
  if w < 8 then
    w = M.CHART_CELL
  end
  local counts, sparks, labels = {}, {}, {}
  for i = 1, 7 do
    local c = cols[i]
    local lab = c.label or "—"
    if #lab > 3 then
      lab = lab:sub(1, 3)
    end
    counts[i] = M.center_cell(c.compact, w)
    -- Two block chars: a single 10pt bar is ~6px and hard to read.
    sparks[i] = M.center_cell(string.rep(M.spark_char(c.height), 2), w)
    labels[i] = M.center_cell(lab, w)
  end
  return table.concat(counts), table.concat(sparks), table.concat(labels)
end

-- Extra windows: label does not start with "weekly" (Fable Weekly stays; primary Weekly drops).
function M.is_extra(label)
  return string.lower(tostring(label or "")):sub(1, 6) ~= "weekly"
end

function M.extra_label(lim)
  if type(lim) ~= "table" then
    return "Limit"
  end
  local kind = tostring(lim.kind or "")
  if kind == "session" then
    return "Session (5-hour)"
  end
  local label = lim.label or "Limit"
  if label == "" then
    label = "Limit"
  end
  local lower = string.lower(label)
  if kind:find "weekly" and not lower:find "weekly" then
    return label .. " Weekly"
  end
  return label
end

function M.iso_to_unix(s)
  if type(s) ~= "string" or s == "" then
    return nil
  end
  local y, mo, d, h, mi, se = s:match "(%d%d%d%d)%-(%d%d)%-(%d%d)[T ](%d%d):(%d%d):(%d%d)"
  if not y then
    y, mo, d, h, mi = s:match "(%d%d%d%d)%-(%d%d)%-(%d%d)[T ](%d%d):(%d%d)"
    se = "0"
  end
  if not y then
    return nil
  end
  local t = {
    year = tonumber(y),
    month = tonumber(mo),
    day = tonumber(d),
    hour = tonumber(h),
    min = tonumber(mi),
    sec = tonumber(se),
    isdst = false,
  }
  -- os.time(t) reads t as local; t is UTC clock numbers, so add UTC offset.
  local as_local = os.time(t)
  local now = os.time()
  local offset = os.difftime(now, os.time(os.date("!*t", now)))
  return as_local + offset
end

return M
