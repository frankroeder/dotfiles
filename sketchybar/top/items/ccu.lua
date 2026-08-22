local colors = require "colors"
local settings = require "settings"
local ui = require "ui"
local logic = require "ccu_logic"

local theme = settings.theme
local helpers = os.getenv "HOME" .. "/.dotfiles/sketchybar/helpers"

local function has_bin(name)
  local h = io.popen("command -v " .. name .. " >/dev/null 2>&1 && echo yes")
  local out = h and h:read "*a" or ""
  if h then
    h:close()
  end
  return out:match "yes" ~= nil
end

local function path_exists(path)
  local h = io.popen('test -e "' .. path .. '" && echo yes')
  local out = h and h:read "*a" or ""
  if h then
    h:close()
  end
  return out:match "yes" ~= nil
end

local function has_cursor()
  local home = os.getenv "HOME" or ""
  return has_bin "cursor"
    or has_bin "cursor-agent"
    or path_exists "/Applications/Cursor.app"
    or path_exists(home .. "/Library/Application Support/Cursor")
    or path_exists(home .. "/.config/cursor/auth.json")
    or path_exists(home .. "/.cursor")
end

-- Grok + Cursor on the bar; Claude / Codex still in the popup (lower priority).
local provider_defs = {
  { id = "grok", label = "Grok", accent = colors.teal, bin = "grok", bar = true },
  { id = "cursor", label = "Cursor", accent = colors.mauve, detect = "cursor", bar = true },
  { id = "claude", label = "Claude", accent = colors.peach, bin = "claude", bar = false },
  { id = "codex", label = "Codex", accent = colors.sky, bin = "codex", bar = false },
}
local providers = {}
for _, p in ipairs(provider_defs) do
  local ok = false
  if p.detect == "cursor" then
    ok = has_cursor()
  elseif p.bin then
    ok = has_bin(p.bin)
  end
  if ok then
    providers[#providers + 1] = p
  end
end

local bar_list = {}
for _, p in ipairs(providers) do
  if p.bar then
    bar_list[#bar_list + 1] = p
  end
end
if #bar_list == 0 then
  bar_list = providers
end

local pad = 8
local content_w = 360
local plate_w = content_w + pad * 2
local row_h = 20
local extra_max = 3
local bar_h = 5
local name_w = 58

local title_font = {
  family = settings.font.family,
  style = settings.font.style_map["Bold"],
  size = 12.0,
}
local body_font = { family = settings.font.family, size = 11.0 }
local cap_font = { family = settings.font.family, size = 10.0 }
local chip_font = {
  family = settings.font.family,
  style = settings.font.style_map["Bold"],
  size = 12.0,
}

local function popup_fill()
  return colors.is_dark and colors.mantle or colors.base
end

local function frame_bg(h)
  return {
    drawing = true,
    color = popup_fill(),
    height = h,
    corner_radius = settings.ui.popup_corner_radius,
    border_width = 1,
    border_color = theme.popup_border,
  }
end

local ccu = ui.add_capsule("widgets.ccu", {
  padding_left = 2,
  padding_right = 2,
  drawing = #providers > 0,
  icon = { drawing = false },
  label = {
    string = bar_list[1] and (bar_list[1].label .. " —") or "—",
    font = chip_font,
    padding_left = 4,
    padding_right = 6,
  },
  popup = {
    align = "left",
    horizontal = true,
    height = row_h * 8,
    y_offset = 1,
    background = frame_bg(row_h * 8),
  },
})

if #providers == 0 then
  return
end

local last = {}
for _, p in ipairs(providers) do
  last[p.id] = { weekly = nil, days = {}, extras = {}, status = nil }
end

local bar_i = 1

local function track_color(accent)
  return colors.with_alpha(accent, colors.is_dark and 0.20 or 0.14)
end

-- Horizontal-popup quirk: a width=0 item still advances the pack cursor by its
-- paddings, so rows drift right cumulatively. Cancel the left pad with a
-- negative right pad → every row renders at x=pad and advances 0.
local function pop_item(name, spec)
  spec.position = "popup." .. ccu.name
  spec.width = 0
  spec.padding_left = spec.padding_left or pad
  spec.padding_right = spec.padding_right or -pad
  spec.background = spec.background or { drawing = false }
  return sbar.add("item", name, spec)
end

local header = pop_item("widgets.ccu.header", {
  icon = {
    string = "AGENT USAGE",
    width = content_w,
    align = "left",
    font = title_font,
    color = theme.text_primary,
    padding_left = 0,
    padding_right = 0,
  },
  label = { drawing = false },
})

local function make_slider(name, width, height)
  return sbar.add("slider", name, width, {
    position = "popup." .. ccu.name,
    width = 0,
    padding_left = pad,
    padding_right = -pad,
    icon = { drawing = false },
    label = { drawing = false },
    slider = {
      percentage = 0,
      highlight_color = theme.text_primary,
      background = {
        height = height,
        corner_radius = height / 2,
        color = track_color(theme.text_primary),
      },
      knob = { drawing = false, string = "" },
    },
    background = { drawing = false, height = row_h },
  })
end

local function set_slider(item, pct, accent, height, drawing)
  height = height or bar_h
  item:set {
    drawing = drawing ~= false,
    slider = {
      percentage = math.min(100, math.max(0, math.floor((pct or 0) + 0.5))),
      highlight_color = accent,
      background = {
        height = height,
        corner_radius = height / 2,
        color = track_color(accent),
      },
      knob = { drawing = false, string = "" },
    },
  }
end

-- Chart rows need a REAL monospace font: settings.font.family is "SF Pro"
-- (proportional) — space-padded cells drift. Menlo ships with macOS and is
-- uniformly 6.02 px/char at 10pt, so 7 cells × 8 chars = 337px ≤ content_w.
local mono = {
  family = "Menlo",
  size = 10.0,
}
local cards = {}
for _, p in ipairs(providers) do
  local prefix = "widgets.ccu." .. p.id
  local card = { id = p.id, label = p.label, accent = p.accent }
  card.sep = pop_item(prefix .. ".sep", {
    icon = {
      -- 35 dashes ≈ 350px in the fallback font (~10 px/char at 10pt) ≤ content_w.
      string = string.rep("─", 35),
      width = content_w,
      align = "left",
      font = cap_font,
      color = theme.text_muted,
      padding_left = 0,
      padding_right = 0,
    },
    label = { drawing = false },
  })
  card.head = pop_item(prefix .. ".head", {
    icon = {
      string = p.label,
      width = name_w,
      align = "left",
      font = title_font,
      color = p.accent,
      padding_left = 0,
      padding_right = 0,
    },
    label = {
      string = "0% used · resets in —",
      width = content_w - name_w,
      align = "left",
      font = body_font,
      color = theme.text_muted,
      padding_left = 0,
      padding_right = 0,
    },
  })
  card.meter = make_slider(prefix .. ".meter", content_w, bar_h)
  card.totals = pop_item(prefix .. ".totals", {
    icon = {
      string = "THIS MONTH · 0",
      width = math.floor(content_w * 0.50),
      align = "left",
      font = cap_font,
      color = theme.text_muted,
      padding_left = 0,
      padding_right = 0,
    },
    label = {
      string = "ALL TIME · 0",
      width = content_w - math.floor(content_w * 0.50),
      align = "right",
      font = cap_font,
      color = theme.text_muted,
      padding_left = 0,
      padding_right = 0,
    },
  })
  card.week = pop_item(prefix .. ".week", {
    icon = {
      string = "LAST 7 DAYS · 0 TOKENS",
      width = content_w,
      align = "left",
      font = cap_font,
      color = theme.text_muted,
      padding_left = 0,
      padding_right = 0,
    },
    label = { drawing = false },
  })
  local function chart_row(name, key)
    card[key] = pop_item(prefix .. "." .. name, {
      icon = {
        string = "",
        width = content_w,
        align = "left",
        font = mono,
        color = theme.text_muted,
        padding_left = 0,
        padding_right = 0,
      },
      label = { drawing = false },
    })
  end
  chart_row("counts", "counts")
  chart_row("spark", "spark")
  chart_row("dows", "dows")
  card.extras = {}
  for e = 1, extra_max do
    card.extras[e] = pop_item(prefix .. ".extra" .. e, {
      icon = {
        string = "",
        width = math.floor(content_w * 0.48),
        align = "left",
        font = cap_font,
        color = theme.text_muted,
        padding_left = 0,
        padding_right = 0,
      },
      label = {
        string = "",
        width = content_w - math.floor(content_w * 0.48),
        align = "right",
        font = cap_font,
        color = theme.text_muted,
        padding_left = 0,
        padding_right = 0,
      },
    })
  end
  cards[p.id] = card
end

-- Invisible last item: only job is popup window width = content. Added after
-- width=0 rows so it does not shift them (pack x stays 0 until this item).
sbar.add("item", "widgets.ccu.plate", {
  position = "popup." .. ccu.name,
  width = plate_w,
  icon = { drawing = false },
  label = { drawing = false },
  background = { drawing = false },
})

-- Vertical rhythm: rows carry their own slot height and sections are split by
-- small gaps, instead of a uniform row_h wall. y_offsets stack from the top.
local h_head = row_h
local h_meter = 12
local h_cap = 18
local h_chart = 15
local h_sep = 12
local gap_section = 4
local gap_header = 6

local function relayout()
  local entries = {}
  local function push(item, h)
    entries[#entries + 1] = { item = item, h = h }
  end
  local function gap(h)
    entries[#entries + 1] = { h = h }
  end

  push(header, row_h)
  gap(gap_header)
  for i, p in ipairs(providers) do
    local card = cards[p.id]
    local st = last[p.id]
    card.sep:set { drawing = i > 1 }
    if i > 1 then
      gap(gap_section)
      push(card.sep, h_sep)
      gap(gap_section)
    end
    push(card.head, h_head)
    if st.weekly then
      push(card.meter, h_meter)
    end
    local has_totals = st.month_tokens ~= nil or st.total_tokens ~= nil
    local has_days = st.days and #st.days > 0
    if has_totals or has_days then
      gap(gap_section)
    end
    if has_totals then
      push(card.totals, h_cap)
    end
    if has_days then
      push(card.week, h_cap)
      gap(2)
      push(card.counts, h_chart)
      push(card.spark, h_chart)
      push(card.dows, h_chart)
    end
    local n_extras = 0
    for e = 1, extra_max do
      local extra = st.extras and st.extras[e]
      card.extras[e]:set { drawing = extra ~= nil }
      if extra then
        n_extras = n_extras + 1
      end
    end
    if n_extras > 0 then
      gap(gap_section)
      for e = 1, extra_max do
        if st.extras and st.extras[e] then
          push(card.extras[e], h_cap)
        end
      end
    end
  end

  local total = 0
  for _, e in ipairs(entries) do
    total = total + e.h
  end
  local y = total / 2
  for _, e in ipairs(entries) do
    if e.item then
      e.item:set { y_offset = math.floor(y - e.h / 2 + 0.5), width = 0 }
    end
    y = y - e.h
  end
  local h = total + 12
  ccu:set {
    popup = {
      height = h,
      y_offset = 1,
      align = "left",
      horizontal = true,
      background = frame_bg(h),
    },
  }
end

local function fg_color(weekly, now)
  if not weekly then
    return theme.text_muted
  end
  if logic.behind_pace(weekly, now) then
    return theme.critical
  end
  return theme.text_primary
end

-- Fixed chip width = longest chip among rotating providers, so the capsule
-- does not resize (and shift neighbours) on every rotation. 6.9 px/char is
-- calibrated against SF Pro at 12pt bold (measured 6.56 px/char via a probe
-- item: "Grok 0% · 6d 20h" = 105px / 16 chars) with ~5% headroom.
local chip_px_per_char = 6.9

local function chip_width(now)
  local max_len = 0
  for _, p in ipairs(bar_list) do
    local s = logic.bar_chip(p.label, (last[p.id] or {}).weekly, now)
    local n = (utf8 and utf8.len(s)) or #s
    if n > max_len then
      max_len = n
    end
  end
  return math.ceil(max_len * chip_px_per_char)
end

local function chip_label(p, now)
  local weekly = (last[p.id] or {}).weekly
  local label = {
    string = logic.bar_chip(p.label, weekly, now),
    color = fg_color(weekly, now),
  }
  if #bar_list > 1 then
    label.width = chip_width(now)
    label.align = "left"
  end
  return label
end

local function apply_bar(now)
  if #bar_list == 0 then
    return
  end
  if bar_i < 1 or bar_i > #bar_list then
    bar_i = 1
  end
  now = now or os.time()
  local label = chip_label(bar_list[bar_i], now)
  -- y_offset = 0 also recovers the chip if a refresh lands mid-rotation tween.
  label.y_offset = 0
  ccu:set {
    background = ui.capsule(),
    label = label,
  }
end

-- Rotation animation: the current chip slides up and fades out, the string
-- swaps while invisible, then the next chip slides in from below. The label
-- width is fixed (chip_width), so the capsule itself never moves.
local rotate_rise = 7
local rotating = false

local function rotate_to_next()
  if rotating or #bar_list < 2 then
    return
  end
  rotating = true
  local now = os.time()
  local cur_fg = fg_color((last[bar_list[bar_i].id] or {}).weekly, now)
  sbar.animate("tanh", settings.motion.fast, function()
    ccu:set { label = { y_offset = rotate_rise, color = colors.with_alpha(cur_fg, 0) } }
  end)
  sbar.delay(0.18, function()
    bar_i = logic.next_bar(bar_i, #bar_list)
    local label = chip_label(bar_list[bar_i], os.time())
    -- Start pose set instantly (string is not animatable): below the slot,
    -- fully transparent.
    ccu:set {
      label = {
        string = label.string,
        width = label.width,
        align = label.align,
        y_offset = -rotate_rise,
        color = colors.with_alpha(label.color, 0),
      },
    }
    sbar.animate("tanh", settings.motion.normal, function()
      ccu:set { label = { y_offset = 0, color = label.color } }
    end)
    rotating = false
  end)
end

local function apply_card(p, now)
  local card = cards[p.id]
  local st = last[p.id]
  local weekly = st.weekly
  local behind = logic.behind_pace(weekly, now)
  local fg = fg_color(weekly, now)
  local muted = behind and theme.critical or theme.text_muted
  local fill = behind and theme.critical or p.accent

  card.sep:set { drawing = p ~= providers[1], icon = { color = theme.text_muted } }
  card.head:set {
    drawing = true,
    icon = { string = p.label, color = fg },
    label = {
      string = weekly and logic.used_line(weekly, now) or (st.status or logic.NO_WEEKLY),
      color = muted,
    },
  }
  -- Meter fill = used (not remaining). Behind-pace only tints chip/meter.
  if weekly then
    set_slider(card.meter, weekly.used * 100, fill, bar_h, true)
  else
    set_slider(card.meter, 0, p.accent, bar_h, false)
  end

  local days = st.days or {}
  local has_days = #days > 0
  local has_totals = st.month_tokens ~= nil or st.total_tokens ~= nil
  card.totals:set {
    drawing = has_totals,
    icon = { string = logic.month_line(st.month_tokens), color = theme.text_muted },
    label = { string = logic.total_line(st.total_tokens), color = theme.text_muted },
  }
  card.week:set {
    drawing = has_days,
    icon = { string = logic.week_header(days), color = theme.text_muted },
  }
  local counts, spark, labels = logic.chart_lines(days)
  card.counts:set { drawing = has_days, icon = { string = counts, color = theme.text_primary } }
  card.spark:set { drawing = has_days, icon = { string = spark, color = fill } }
  card.dows:set { drawing = has_days, icon = { string = labels, color = theme.text_muted } }

  for e = 1, extra_max do
    local extra = st.extras and st.extras[e]
    if extra then
      card.extras[e]:set {
        drawing = true,
        icon = { string = extra.label, color = theme.text_muted },
        label = { string = logic.extra_line(extra.weekly, now), color = theme.text_primary },
      }
    else
      card.extras[e]:set { drawing = false }
    end
  end
end

local function apply_all()
  local now = os.time()
  apply_bar(now)
  for _, p in ipairs(providers) do
    apply_card(p, now)
  end
  relayout()
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

local function apply_claude(result)
  local st = last.claude
  if not st then
    return
  end
  if result.error then
    if not st.weekly then
      st.status = result.error
    end
  else
    st.weekly = logic.from_helper_window(result.weekly)
    st.extras = logic.extra_windows(result.limits)
    if #st.extras == 0 then
      local extras = {}
      if result.session then
        extras[#extras + 1] = {
          label = logic.extra_label(result.session),
          weekly = logic.from_helper_window(result.session),
        }
      end
      if result.scoped then
        extras[#extras + 1] = {
          label = logic.extra_label(result.scoped),
          weekly = logic.from_helper_window(result.scoped),
        }
      end
      st.extras = extras
    end
    st.status = nil
  end
  apply_all()
end

local function apply_grok(result)
  local st = last.grok
  if not st then
    return
  end
  if result.error then
    if not st.weekly then
      st.status = result.error
    end
  else
    local used = tonumber(result.utilization)
    local reset = tonumber(result.reset_unix) or logic.iso_to_unix(result.resets_at)
    local span = tonumber(result.span_sec)
    if not span then
      local start = tonumber(result.period_start_unix) or logic.iso_to_unix(result.period_start)
      if start and reset and reset > start then
        span = reset - start
      end
    end
    st.weekly = used ~= nil and logic.weekly(used / 100, reset, span) or nil
    st.status = nil
  end
  apply_all()
end

local function apply_cursor(result)
  local st = last.cursor
  if not st then
    return
  end
  if result.error then
    if not st.weekly then
      st.status = result.error
    end
  else
    st.weekly = logic.from_helper_window {
      utilization = result.utilization,
      reset_unix = result.reset_unix,
      span_sec = result.span_sec,
      period_start_unix = result.period_start_unix,
    }
    st.extras = logic.extra_windows(result.limits)
    st.status = nil
  end
  apply_all()
end

local function apply_cost(result)
  if result.error then
    return
  end
  local by_id = {}
  local list = result.providers
  if type(list) == "table" then
    for i = 1, #list do
      local prov = list[i]
      if type(prov) == "table" and prov.id then
        by_id[prov.id] = prov
      end
    end
  end
  for _, p in ipairs(providers) do
    local prov = by_id[p.id]
    if prov then
      if type(prov.weekdays) == "table" then
        last[p.id].days = prov.weekdays
      end
      local month = prov.month
      local tot = prov.total
      last[p.id].month_tokens = type(month) == "table" and tonumber(month.tokens) or nil
      last[p.id].total_tokens = type(tot) == "table" and tonumber(tot.tokens) or nil
    end
  end
  apply_all()
end

local function get_claude_usage(callback)
  sbar.exec("python3 " .. helpers .. "/claude_usage.py", function(lit)
    callback(parse_lua_table(lit, "ccu_claude"))
  end)
end

local function get_grok_usage(callback)
  sbar.exec("python3 " .. helpers .. "/grok_usage.py", function(lit)
    callback(parse_lua_table(lit, "ccu_grok"))
  end)
end

local function get_cursor_usage(callback)
  sbar.exec("python3 " .. helpers .. "/cursor_usage.py", function(lit)
    callback(parse_lua_table(lit, "ccu_cursor"))
  end)
end

local function get_cost_estimate(callback)
  sbar.exec("python3 " .. helpers .. "/ccu_cost.py", function(lit)
    callback(parse_lua_table(lit, "ccu_cost"))
  end)
end

local function refresh_usage()
  if last.grok then
    get_grok_usage(apply_grok)
  end
  if last.cursor then
    get_cursor_usage(apply_cursor)
  end
  if last.claude then
    get_claude_usage(apply_claude)
  end
  get_cost_estimate(apply_cost)
end

local function refresh_theme()
  for _, p in ipairs(provider_defs) do
    if p.id == "grok" then
      p.accent = colors.teal
    elseif p.id == "cursor" then
      p.accent = colors.mauve
    elseif p.id == "claude" then
      p.accent = colors.peach
    else
      p.accent = colors.sky
    end
  end
  header:set { icon = { string = "AGENT USAGE", color = theme.text_primary } }
  apply_all()
end

ccu:subscribe("theme_colors_updated", refresh_theme)
refresh_theme()

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

if #bar_list > 1 then
  local rotate_timer = sbar.add("item", "widgets.ccu.rotate", {
    update_freq = 10,
    drawing = false,
    updates = true,
  })
  rotate_timer:subscribe("routine", rotate_to_next)
end

ui.bind_popup(ccu, { on_open = refresh_usage, on_right = refresh_usage })
refresh_usage()
