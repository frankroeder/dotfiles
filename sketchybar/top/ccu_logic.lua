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

function M.week_header(days)
  return "LAST 7 DAYS · " .. M.token_count(M.recent_total(days)) .. " TOKENS"
end

function M.month_line(n)
  return "THIS MONTH · " .. M.token_count(n or 0)
end

function M.total_line(n)
  return "ALL TIME · " .. M.token_count(n or 0)
end

function M.chart_columns(days)
  local list = days or {}
  local peak = M.recent_peak(list)
  local cols = {}
  for i = 1, 7 do
    local day = list[i]
    local tokens = M.day_tokens(day)
    local date = day and day.date
    cols[i] = {
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
    return M.SPARK[1]
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

function M.pad_cell(s, w)
  s = tostring(s or "")
  local n = (utf8 and utf8.len(s)) or #s
  if n >= w then
    return s
  end
  local pad = w - n
  local left = math.floor(pad / 2)
  return string.rep(" ", left) .. s .. string.rep(" ", pad - left)
end

-- Three monospaced lines (counts / spark / weekdays). Cell width 8 so 24.5M isn't jammed.
M.CHART_CELL = 8

function M.chart_lines(days)
  local cols = M.chart_columns(days)
  local w = M.CHART_CELL
  local counts, sparks, labels = {}, {}, {}
  for i = 1, 7 do
    local c = cols[i]
    local lab = c.label or "—"
    if #lab > 3 then
      lab = lab:sub(1, 3)
    end
    counts[i] = M.pad_cell(c.compact, w)
    sparks[i] = M.pad_cell(M.spark_char(c.height), w)
    labels[i] = M.pad_cell(lab, w)
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
