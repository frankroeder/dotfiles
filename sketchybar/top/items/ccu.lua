-- Credits to https://github.com/TaterDoge/dotfiles/tree/main
local colors = require "colors"
local icons = require "icons"
local settings = require "settings"
local ui = require "ui"

local theme = settings.theme
local metrics = settings.ui

-- Fixed columns: title | bar | value.
-- Item padding must stay 0 (horizontal pack advances x by it). Gaps between
-- title/bar/value use icon/label padding inside fixed column widths instead.
local pad = 10
local col_gap = 10
local title_w = 88 -- "This month" / "All time" / "Past 7d"
local bar_w = 72 -- slimmer intensity bar
local value_w = 200 -- spark + "$305 · 225M"
local bar_h = 6
local row_h = metrics.popup_row_height
local content_w = title_w + bar_w + value_w
local popup_width = content_w + pad * 2
local helpers = os.getenv "HOME" .. "/.dotfiles/sketchybar/helpers"

-- Only poll tools whose CLI is on PATH (claude / grok).
local function has_bin(name)
  local h = io.popen("command -v " .. name .. " >/dev/null 2>&1 && echo yes")
  local out = h and h:read "*a" or ""
  if h then
    h:close()
  end
  return out:match "yes" ~= nil
end

local has_claude = has_bin "claude"
local has_grok = has_bin "grok"
local has_codex = has_bin "codex"

-- Cost providers = installed CLIs only (separate sections each).
local cost_providers = {}
if has_grok then
  cost_providers[#cost_providers + 1] = { id = "grok", label = "Grok", accent = colors.teal }
end
if has_claude then
  cost_providers[#cost_providers + 1] = { id = "claude", label = "Claude", accent = colors.peach }
end
if has_codex then
  cost_providers[#cost_providers + 1] = { id = "codex", label = "Codex", accent = colors.sky }
end

-- Window accents (cost rows) — distinct from quota palette.
local win_today = colors.peach
local win_week = colors.green
local win_month = colors.lavender
local win_total = colors.mauve

-- Horizontal popup: width=0 rows stack via y_offset; link buttons share bottom.
-- Layout: [quota…] [─ API $ ─] [per CLI: Today/7d/Month/Total] [links]
-- One divider only (no second provider header).
local row_gap = 2
local step = row_h + row_gap
local n_quota = (has_claude and 2 or 0) + (has_grok and 1 or 0)
local n_div = (n_quota > 0 and #cost_providers > 0) and 1 or 0
local n_cost = #cost_providers * 4 -- Today / 7d / Month / Total
local n_links = (has_claude or has_grok) and 1 or 0
local n_rows = n_quota + n_div + n_cost + n_links
local popup_h = n_rows > 0 and (row_h * n_rows + row_gap * math.max(0, n_rows - 1) + 10) or row_h

-- y_offset: top → bottom, centered on 0. i=0 is top row.
local function row_y(i)
  return ((n_rows - 1) / 2 - i) * step
end

local row_i = 0
local y_session, y_weekly, y_grok, y_div, y_links
if has_claude then
  y_session = row_y(row_i)
  row_i = row_i + 1
  y_weekly = row_y(row_i)
  row_i = row_i + 1
end
if has_grok then
  y_grok = row_y(row_i)
  row_i = row_i + 1
end
if n_div > 0 then
  y_div = row_y(row_i)
  row_i = row_i + 1
end
local cost_y0 = row_i
row_i = row_i + n_cost
if has_claude or has_grok then
  y_links = row_y(row_i)
end

local btn_gap = 6
local both_links = has_claude and has_grok
local btn_w = both_links and math.floor((content_w - btn_gap) / 2) or content_w

local accent_session = colors.mauve
local accent_weekly = colors.blue
local accent_grok = colors.teal
local last = { session = nil, weekly = nil, grok = nil, cost = nil }

local ccu = ui.add_capsule("widgets.ccu", {
  padding_left = 2,
  padding_right = 2,
  drawing = has_claude or has_grok or has_codex,
  icon = { drawing = false },
  label = {
    string = "CCu",
    font = {
      family = settings.font.family,
      style = settings.font.style_map["Bold"],
      size = 12.0,
    },
    padding_left = 4,
    padding_right = 6,
  },
  popup = {
    -- Top bar: open downward, grow right so the wide panel stays on-screen.
    align = "left",
    horizontal = true,
    height = popup_h,
    y_offset = 1,
    background = ui.popup(),
  },
})

-- Nothing to show: skip rows / polling.
if not has_claude and not has_grok and not has_codex then
  return
end

-- Mono for titles+values so fixed icon/label widths actually column-align.
local title_font = {
  family = settings.font.family,
  style = settings.font.style_map["Semibold"],
  size = 12.0,
}
local value_font = {
  family = settings.font.family,
  size = 11.0,
}

local function track_color(accent)
  return colors.with_alpha(accent, colors.is_dark and 0.20 or 0.14)
end

-- Color by used % (high = bad), even when UI shows remaining.
local function usage_color(used)
  if used == nil then
    return theme.text_muted
  end
  if used >= 90 then
    return theme.critical
  end
  if used >= 75 then
    return colors.orange
  end
  if used >= 50 then
    return theme.warn
  end
  return theme.text_muted
end

-- opts.no_bar: text-only row (no slider) — used for All time.
local function metric_row(name, title, accent, y, opts)
  opts = opts or {}
  if opts.no_bar then
    return sbar.add("item", name, {
      position = "popup." .. ccu.name,
      width = 0,
      padding_left = 0,
      padding_right = 0,
      y_offset = y,
      icon = {
        string = title,
        width = title_w,
        align = "right",
        padding_left = 0,
        padding_right = col_gap,
        font = title_font,
        color = accent,
      },
      label = {
        string = "…",
        width = bar_w + value_w + col_gap,
        align = "left",
        padding_left = col_gap,
        padding_right = 0,
        font = value_font,
        color = theme.text_muted,
      },
      background = { drawing = false, height = row_h },
    })
  end
  return sbar.add("slider", name, bar_w, {
    position = "popup." .. ccu.name,
    -- width=0 + zero item pads: pack length 0 so every row shares the same x.
    width = 0,
    padding_left = 0,
    padding_right = 0,
    y_offset = y,
    icon = {
      string = title,
      width = title_w,
      align = "right",
      padding_left = 0,
      padding_right = col_gap,
      font = title_font,
      color = accent,
    },
    label = {
      string = "…",
      width = value_w,
      align = "left",
      padding_left = col_gap,
      padding_right = 0,
      font = value_font,
      color = theme.text_muted,
    },
    slider = {
      percentage = 0,
      width = bar_w,
      highlight_color = accent,
      background = {
        height = bar_h,
        corner_radius = bar_h / 2,
        color = track_color(accent),
      },
      knob = { drawing = false, string = "" },
    },
    background = { drawing = false, height = row_h },
  })
end

local function clamp_pct(percent)
  if percent == nil then
    return 0
  end
  local n = math.floor(percent + 0.5)
  if n < 0 then
    return 0
  end
  if n > 100 then
    return 100
  end
  return n
end

local function set_percent(item, accent, percent)
  item:set {
    slider = {
      percentage = clamp_pct(percent),
      width = bar_w,
      highlight_color = accent,
      background = {
        height = bar_h,
        corner_radius = bar_h / 2,
        color = track_color(accent),
      },
      knob = { drawing = false, string = "" },
    },
  }
end

sbar.add("item", "widgets.ccu.inset", {
  position = "popup." .. ccu.name,
  width = pad,
  padding_left = 0,
  padding_right = 0,
  icon = { drawing = false },
  label = { drawing = false },
  background = { drawing = false },
})

local session_row, weekly_row, grok_row
if has_claude then
  session_row = metric_row("widgets.ccu.session", "Session (5h)", accent_session, y_session)
  weekly_row = metric_row("widgets.ccu.weekly", "Week (7d)", accent_weekly, y_weekly)
end
if has_grok then
  grok_row = metric_row("widgets.ccu.grok", "Grok (7d)", accent_grok, y_grok)
end

-- One divider between quota and local API cost/token estimates.
local div_row = nil
if n_div > 0 then
  local who = #cost_providers == 1 and (cost_providers[1].label .. " · ") or ""
  local div_title = "── " .. who .. "API cost & tokens ──"
  div_row = sbar.add("item", "widgets.ccu.div", {
    position = "popup." .. ccu.name,
    width = 0,
    padding_left = 0,
    padding_right = 0,
    y_offset = y_div,
    icon = {
      string = div_title,
      width = content_w,
      align = "center",
      padding_left = 0,
      padding_right = 0,
      font = {
        family = settings.font.family,
        style = settings.font.style_map["Semibold"],
        size = 10.0,
      },
      color = theme.text_muted,
    },
    label = { drawing = false },
    background = { drawing = false, height = row_h },
  })
end

-- Per-CLI: Today / Past 7d / Month / All time (no extra header row).
local cost_rows = {} -- [id] = { today, week, month, total, accent, label }
do
  local yi = cost_y0
  for _, p in ipairs(cost_providers) do
    local multi = #cost_providers > 1
    local t_today = multi and (p.label .. " today") or "Today"
    local t_week = multi and (p.label .. " 7d") or "Past 7d"
    local t_month = multi and (p.label .. " mo") or "Month"
    local t_total = multi and (p.label .. " total") or "All time"
    cost_rows[p.id] = {
      label = p.label,
      accent = p.accent,
      today = metric_row("widgets.ccu.cost_" .. p.id .. "_today", t_today, win_today, row_y(yi)),
      week = metric_row("widgets.ccu.cost_" .. p.id .. "_week", t_week, win_week, row_y(yi + 1)),
      month = metric_row("widgets.ccu.cost_" .. p.id .. "_month", t_month, win_month, row_y(yi + 2)),
      total = metric_row(
        "widgets.ccu.cost_" .. p.id .. "_total",
        t_total,
        win_total,
        row_y(yi + 3),
        { no_bar = true }
      ),
    }
    yi = yi + 4
  end
end

local function link_button(name, title, url, pad_l, pad_r)
  return sbar.add("item", name, {
    position = "popup." .. ccu.name,
    width = btn_w,
    align = "center",
    padding_left = pad_l,
    padding_right = pad_r,
    y_offset = y_links,
    icon = { drawing = false },
    label = {
      string = icons.external_link .. "  " .. title,
      color = theme.text_muted,
      font = value_font,
      align = "center",
      width = btn_w,
      padding_left = 0,
      padding_right = 0,
    },
    background = ui.button { height = row_h },
    click_script = "open '" .. url .. "'",
  })
end

local claude_link, grok_link
if has_claude then
  claude_link = link_button(
    "widgets.ccu.claude_link",
    "Claude",
    "https://claude.ai/settings/usage",
    0,
    both_links and math.floor(btn_gap / 2) or 0
  )
end
if has_grok then
  grok_link = link_button(
    "widgets.ccu.grok_link",
    "Grok",
    "https://grok.com/?_s=usage",
    both_links and math.ceil(btn_gap / 2) or 0,
    0
  )
end

local function parse_lua_table(lit, tag)
  if not lit or lit == "" then
    return { error = "empty_response" }
  end
  local fn, err = load("return " .. lit, tag, "t", {})
  if not fn then
    return { error = "parse_error" }
  end
  local ok, result = pcall(fn)
  if not ok or type(result) ~= "table" then
    return { error = "invalid_response" }
  end
  if result.error then
    return { error = result.error }
  end
  return result
end

local function window_fields(block)
  if not block or type(block) ~= "table" then
    return nil
  end
  local used = tonumber(block.used)
  local remaining = tonumber(block.remaining)
  if used == nil and remaining == nil then
    return nil
  end
  if used == nil then
    used = 100 - remaining
  end
  if remaining == nil then
    remaining = math.max(0, 100 - used)
  end
  return {
    used = used,
    remaining = math.max(0, remaining),

    reset_text = block.reset_text,
    label = block.label,
    kind = block.kind,
    model = block.model,
    active = block.active == true,
  }
end

local function get_claude_usage(callback)
  sbar.exec("python3 " .. helpers .. "/claude_usage.py", function(lit)
    local result = parse_lua_table(lit, "ccu_claude")
    if result.error then
      callback(result)
      return
    end
    callback {
      session = window_fields(result.session),
      weekly = window_fields(result.weekly),
    }
  end)
end

local function grok_title(period_type)
  if type(period_type) == "string" and period_type:find("WEEKLY") then
    return "Grok (7d)"
  end
  if type(period_type) == "string" and period_type:find("MONTHLY") then
    return "Grok (30d)"
  end
  return "Grok (7d)" -- Build credits default weekly
end

local function get_grok_usage(callback)
  sbar.exec("python3 " .. helpers .. "/grok_usage.py", function(lit)
    local result = parse_lua_table(lit, "ccu_grok")
    if result.error then
      callback(result)
      return
    end
    local used = tonumber(result.utilization)
    local remaining = tonumber(result.remaining)
    if remaining == nil and used ~= nil then
      remaining = math.max(0, 100 - used)
    end
    callback {
      utilization = used,
      remaining = remaining,
      resets_at = result.resets_at_de or result.resets_at,
      period_type = result.period_type,
    }
  end)
end

local function get_cost_estimate(callback)
  -- Local stats only — no OAuth; safe on every refresh.
  sbar.exec("python3 " .. helpers .. "/ccu_cost.py", function(lit)
    callback(parse_lua_table(lit, "ccu_cost"))
  end)
end

-- "2026-07-09 11:19 (CEST)" → "09.07. 11:19" (Grok absolute date fallback)
local function short_reset(s)
  if not s or s == "" then
    return nil
  end
  local m, d, t = s:match "%d%d%d%d%-(%d%d)%-(%d%d) (%d%d:%d%d)"
  if m then
    return string.format("%s.%s. %s", d, m, t)
  end
  return s
end

-- Remaining % + relative reset; [active] = currently counting window (CLI style).
local function format_remaining(win)
  if not win or win.remaining == nil then
    return "—"
  end
  local text = string.format("%3.0f%%", win.remaining)
  if win.reset_text and win.reset_text ~= "" then
    text = text .. "  " .. win.reset_text
  end
  if win.active then
    text = text .. " [active]"
  end
  return text
end

-- Fixed CLI-style titles (window length / weekly scope). Scoped uses model name.
local function row_title(win, fallback)
  if not win then
    return fallback
  end
  if win.kind == "weekly_scoped" or (win.label and win.label ~= "Session" and win.label ~= "Weekly") then
    local model = win.model or win.label
    if model and model ~= "" and model ~= "Scoped" then
      return "Weekly " .. model
    end
  end
  return fallback
end

local function format_pct(percent, reset, used)
  if percent == nil and used == nil then
    return "—"
  end
  -- Prefer remaining; if over-limit (used > 100) show used so we never print "-30%".
  local show = percent
  local suffix = ""
  if used ~= nil and used > 100 then
    show = used
    suffix = " used"
  elseif show == nil then
    show = used
  end
  local text = string.format("%3.0f%%%s", show, suffix)
  local r = short_reset(reset)
  if r then
    text = text .. "  " .. r
  end
  return text
end

local function max_pct(...)
  local best = nil
  for i = 1, select("#", ...) do
    local v = select(i, ...)
    if v ~= nil and (best == nil or v > best) then
      best = v
    end
  end
  return best
end

local function set_capsule(session_used, weekly_used, grok_used, err)
  if err then
    ccu:set {
      background = ui.capsule(),
      label = { string = "CCu ?", color = theme.critical },
    }
    return
  end

  local pct = max_pct(session_used, weekly_used, grok_used)
  if pct == nil then
    ccu:set {
      background = ui.capsule(),
      label = { string = "CCu", color = theme.text_muted },
    }
    return
  end

  ccu:set {
    background = ui.capsule(),
    label = {
      string = string.format("CCu %.0f%%", pct),
      color = usage_color(pct),
    },
  }
end

local function apply_window_row(row, accent, win, title_fallback)
  if not win then
    row:set {
      icon = { string = title_fallback, color = accent },
      label = { string = "—", color = theme.text_muted },
    }
    set_percent(row, accent, 0)
    return nil
  end
  row:set {
    icon = { string = row_title(win, title_fallback), color = accent },
    label = {
      string = format_remaining(win),
      color = usage_color(win.used),
    },
  }
  -- Bar shows remaining (CLI progress bar style).
  set_percent(row, accent, win.remaining)
  return win.used
end

local function apply_claude(result)
  if not has_claude then
    return
  end
  if result.error then
    -- Keep last-good rows on transient failures (429 / parse / network).
    local had = last.session ~= nil or last.weekly ~= nil
    if not had then
      session_row:set {
        icon = { string = "Session (5h)", color = accent_session },
        label = { string = result.error, color = theme.critical },
      }
      weekly_row:set {
        icon = { string = "Week (7d)", color = accent_weekly },
        label = { string = "—", color = theme.text_muted },
      }
      set_percent(session_row, accent_session, 0)
      set_percent(weekly_row, accent_weekly, 0)
    end
  else
    last.session = apply_window_row(session_row, accent_session, result.session, "Session (5h)")
    last.weekly = apply_window_row(weekly_row, accent_weekly, result.weekly, "Week (7d)")
  end
  set_capsule(last.session, last.weekly, last.grok, result.error and not last.grok and not last.session)
end

local function apply_grok(result)
  if not has_grok then
    return
  end
  if result.error then
    if last.grok == nil then
      grok_row:set {
        icon = { string = "Grok (7d)", color = accent_grok },
        label = { string = result.error, color = theme.critical },
      }
      set_percent(grok_row, accent_grok, 0)
    end
  else
    local used = result.utilization
    local remaining = result.remaining
    if remaining == nil and used ~= nil then
      remaining = math.max(0, 100 - used)
    end
    last.grok = used
    grok_row:set {
      icon = { string = grok_title(result.period_type), color = accent_grok },
      label = {
        string = format_pct(remaining, result.resets_at, used),
        color = usage_color(used),
      },
    }
    -- Bar = remaining (CLI style); over-limit → 0%.
    set_percent(grok_row, accent_grok, remaining or 0)
  end
  set_capsule(last.session, last.weekly, last.grok, result.error and not last.session and not last.grok)
end

local function fmt_tokens(n)
  n = tonumber(n) or 0
  if n >= 1e6 then
    return string.format("%.1fM", n / 1e6)
  end
  if n >= 1e3 then
    return string.format("%.0fk", n / 1e3)
  end
  return string.format("%.0f", n)
end

local function fmt_usd(u)
  u = tonumber(u) or 0
  if u >= 1000 then
    return string.format("$%.1fk", u / 1000)
  end
  if u >= 100 then
    return string.format("$%.0f", u)
  end
  return string.format("$%.2f", u)
end

-- Cost-first; tokens secondary. e.g. "$21 · 16.7M"
local function money_tok(usd, tokens)
  return fmt_usd(usd) .. " · " .. fmt_tokens(tokens)
end

-- Slim spark: 4 height steps only (less visual weight than full block set).
local spark_blocks = { "▁", "▂", "▃", "▅" }
local function sparkline(days, max_usd, max_bars)
  max_usd = tonumber(max_usd) or 0
  max_bars = max_bars or 7
  if not days or #days == 0 then
    return string.rep("▁", max_bars)
  end
  local n = #days
  local chars = {}
  local function level(u)
    if max_usd > 0 and u > 0 then
      return math.max(1, math.min(4, math.floor(u / max_usd * 3 + 1.25)))
    end
    return 1
  end
  if n <= max_bars then
    for i = 1, n do
      chars[i] = spark_blocks[level(tonumber(days[i].usd) or 0)]
    end
  else
    for i = 1, max_bars do
      local idx = math.floor((i - 0.5) * n / max_bars) + 1
      if idx > n then
        idx = n
      end
      chars[i] = spark_blocks[level(tonumber(days[idx].usd) or 0)]
    end
  end
  return table.concat(chars)
end

local function apply_provider_cost(rows, prov)
  local today = prov.today or {}
  local week = prov.week or {}
  local month = prov.month or {}
  local total = prov.total or {}
  local weekdays = prov.weekdays or {}
  local max_day = tonumber(week.max_day_usd) or 0
  local today_usd = tonumber(today.usd) or 0
  local week_usd = tonumber(week.usd) or 0
  local month_usd = tonumber(month.usd) or 0
  local total_usd = tonumber(total.usd) or 0
  local peak = math.max(max_day, today_usd, 0.01)

  -- Today
  rows.today:set {
    icon = { color = win_today },
    label = {
      string = money_tok(today_usd, today.tokens),
      color = today_usd > 0 and theme.text_primary or theme.text_muted,
    },
  }
  set_percent(rows.today, win_today, (today_usd / peak) * 100)

  -- Past 7d: slim 7-bar spark + $ · tokens
  rows.week:set {
    icon = { color = win_week },
    label = {
      string = sparkline(weekdays, max_day, 7) .. " " .. money_tok(week_usd, week.tokens),
      color = week_usd > 0 and theme.text_primary or theme.text_muted,
    },
  }
  local week_pct = (month_usd > 0) and (week_usd / math.max(month_usd, week_usd) * 100)
    or (week_usd > 0 and 100 or 0)
  set_percent(rows.week, win_week, week_pct)

  -- Month: API $ + tokens used (no day-spark; bar already shows share of all-time)
  rows.month:set {
    icon = { color = win_month },
    label = {
      string = money_tok(month_usd, month.tokens),
      color = month_usd > 0 and theme.text_primary or theme.text_muted,
    },
  }
  local month_pct = (total_usd > 0) and (month_usd / total_usd * 100) or (month_usd > 0 and 100 or 0)
  set_percent(rows.month, win_month, month_pct)

  -- All time: text only (no bar)
  rows.total:set {
    icon = { color = win_total },
    label = {
      string = money_tok(total_usd, total.tokens),
      color = total_usd > 0 and theme.text_primary or theme.text_muted,
    },
  }
end

local function apply_cost(result)
  if result.error and not last.cost then
    for _, rows in pairs(cost_rows) do
      rows.today:set { label = { string = result.error, color = theme.critical } }
      rows.week:set { label = { string = "—", color = theme.text_muted } }
      rows.month:set { label = { string = "—", color = theme.text_muted } }
      rows.total:set { label = { string = "—", color = theme.text_muted } }
      set_percent(rows.today, win_today, 0)
      set_percent(rows.week, win_week, 0)
      set_percent(rows.month, win_month, 0)
    end
    return
  end
  if result.error then
    return
  end

  last.cost = result
  local by_id = {}
  local list = result.providers
  if type(list) == "table" then
    for i = 1, #list do
      local p = list[i]
      if type(p) == "table" and p.id then
        by_id[p.id] = p
      end
    end
    for k, p in pairs(list) do
      if type(k) == "string" and type(p) == "table" then
        by_id[k] = p
      end
    end
  end

  for id, rows in pairs(cost_rows) do
    local prov = by_id[id]
    if prov then
      apply_provider_cost(rows, prov)
    else
      rows.today:set { label = { string = "$0 · 0", color = theme.text_muted } }
      rows.week:set { label = { string = "▁▁▁▁▁▁▁ $0 · 0", color = theme.text_muted } }
      rows.month:set { label = { string = "▁▁▁▁▁▁▁▁ $0", color = theme.text_muted } }
      rows.total:set { label = { string = "$0 · 0", color = theme.text_muted } }
      set_percent(rows.today, win_today, 0)
      set_percent(rows.week, win_week, 0)
      set_percent(rows.month, win_month, 0)
    end
  end
end

local function refresh_theme()
  accent_session = colors.mauve
  accent_weekly = colors.blue
  accent_grok = colors.teal
  win_today = colors.peach
  win_week = colors.green
  win_month = colors.lavender
  win_total = colors.mauve
  ui.theme_popup(ccu)
  ccu:set { popup = { y_offset = 1, align = "left" } }
  if has_claude then
    session_row:set { icon = { color = accent_session }, label = { color = usage_color(last.session) } }
    weekly_row:set { icon = { color = accent_weekly }, label = { color = usage_color(last.weekly) } }
    set_percent(session_row, accent_session, last.session and (100 - last.session) or 0)
    set_percent(weekly_row, accent_weekly, last.weekly and (100 - last.weekly) or 0)
  end
  if has_grok then
    grok_row:set { icon = { color = accent_grok }, label = { color = usage_color(last.grok) } }
    set_percent(grok_row, accent_grok, last.grok and (100 - last.grok) or 0)
  end
  if div_row then
    div_row:set { icon = { color = theme.text_muted } }
  end
  if cost_rows.grok then
    cost_rows.grok.accent = colors.teal
  end
  if cost_rows.claude then
    cost_rows.claude.accent = colors.peach
  end
  if cost_rows.codex then
    cost_rows.codex.accent = colors.sky
  end
  if last.cost then
    apply_cost(last.cost)
  else
    for _, rows in pairs(cost_rows) do
      rows.today:set { icon = { color = win_today } }
      rows.week:set { icon = { color = win_week } }
      rows.month:set { icon = { color = win_month } }
      rows.total:set { icon = { color = win_total } }
    end
  end
  local link_style = {
    label = { color = theme.text_muted },
    background = ui.button { height = row_h },
  }
  if claude_link then
    claude_link:set(link_style)
  end
  if grok_link then
    grok_link:set(link_style)
  end
  set_capsule(last.session, last.weekly, last.grok)
end

ccu:subscribe("theme_colors_updated", refresh_theme)
refresh_theme()

local function refresh_usage()
  if has_claude then
    get_claude_usage(apply_claude)
  end
  if has_grok then
    get_grok_usage(apply_grok)
  end
  get_cost_estimate(apply_cost)
end

-- Always refresh capsule (was stuck after first failed fetch when popup closed).
-- Open popup: 20s; closed: 60s — avoids Claude 429 from 10s hammering.
local refresh_timer = sbar.add("item", "widgets.ccu.refresh_timer", {
  update_freq = 60,
  drawing = false,
  updates = true,
})

refresh_timer:subscribe("routine", function()
  local q = ccu:query()
  local open = q and q.popup and q.popup.drawing == "on"
  refresh_timer:set { update_freq = open and 20 or 60 }
  refresh_usage()
end)

ui.bind_popup(ccu, { on_open = refresh_usage })
refresh_usage()
