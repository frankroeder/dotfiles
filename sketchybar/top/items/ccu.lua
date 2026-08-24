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
local content_w = 440
local plate_w = content_w + pad * 2
-- All time · 1.6B · $2.0k needs ~164px at 13pt; 30d/7d are shorter.
local col_all = 176
local col_30 = 132
local col_7 = content_w - col_all - col_30
local row_h = 20
local extra_max = 3
local bar_h = 5
local name_w = 58
local legend_dot_w = 12

local title_font = {
  family = settings.font.family,
  style = settings.font.style_map["Bold"],
  size = 13.0,
}
local body_font = { family = settings.font.family, size = 12.0 }
local cap_font = { family = settings.font.family, size = 11.0 }
local stat_font = { family = settings.font.family, size = 13.0 }
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
    padding_right = 2,
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

-- Meter rows are plain items whose BACKGROUND is the bar, positioned with the
-- same padding trick as pop_item (padding_left = pad + x, negative right pad
-- cancels the advance). One item per usage category segment plus one for the
-- remaining track — segments never overlap, so z-order never matters.
local seg_max = 5
local seg_gap = 2

local function bar_seg_item(name)
  return sbar.add("item", name, {
    position = "popup." .. ccu.name,
    drawing = false,
    width = 0,
    padding_left = pad,
    padding_right = -pad,
    icon = { drawing = false },
    label = { drawing = false },
    background = {
      drawing = true,
      color = colors.transparent,
      height = bar_h,
      corner_radius = math.floor(bar_h / 2),
    },
  })
end

local function set_bar_seg(item, x, w, color)
  x = math.floor(x + 0.5)
  w = math.floor(w + 0.5)
  if w < 1 then
    item:set { drawing = false }
    return
  end
  item:set {
    drawing = true,
    width = w,
    padding_left = pad + x,
    padding_right = -(pad + x + w),
    background = {
      drawing = true,
      color = color,
      height = bar_h,
      corner_radius = math.floor(bar_h / 2),
    },
  }
end

-- Product colors for the shared-pool split (Grok usage categories).
local function category_color(label, index)
  local named = {
    ["Chat"] = colors.blue,
    ["Grok Build"] = colors.mauve,
    ["API"] = colors.green,
    ["Imagine"] = colors.pink,
    ["Voice"] = colors.yellow,
  }
  if named[label] then
    return named[label]
  end
  local fallback = { colors.sky, colors.teal, colors.peach, colors.lavender, colors.maroon }
  return fallback[(index - 1) % #fallback + 1]
end

-- Chart rows need a REAL monospace font: settings.font.family is "SF Pro"
-- (proportional) — space-padded cells drift. Menlo 10pt is 6.02 px/char;
-- cell width is content_w / 7 so the week chart spans the popup.
local mono = {
  family = "Menlo",
  size = 10.0,
}
local mono_bar = {
  family = "Menlo",
  style = "Bold",
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
  -- Identity peer on the head row: account email + rebill, right-aligned.
  card.ident = pop_item(prefix .. ".ident", {
    drawing = false,
    icon = { drawing = false },
    label = {
      string = "",
      width = content_w,
      align = "right",
      font = cap_font,
      color = theme.text_muted,
      padding_left = 0,
      padding_right = 0,
    },
  })
  -- Usage subline: "21% of weekly limit used" | "Resets Aug 29, 2:48 AM · 5d 11h".
  card.sub = pop_item(prefix .. ".sub", {
    drawing = false,
    icon = {
      string = "",
      width = 200,
      align = "left",
      font = body_font,
      color = theme.text_primary,
      padding_left = 0,
      padding_right = 0,
    },
    label = {
      string = "",
      width = content_w - 200,
      align = "right",
      font = body_font,
      color = theme.text_muted,
      padding_left = 0,
      padding_right = 0,
    },
  })
  card.meter_segs = {}
  for k = 1, seg_max do
    card.meter_segs[k] = bar_seg_item(prefix .. ".seg" .. k)
  end
  card.meter_rest = bar_seg_item(prefix .. ".rest")
  -- Legend under the meter: one dot + "Chat 1%" cell per category, packed left.
  card.legend = {}
  for k = 1, seg_max do
    card.legend[k] = pop_item(prefix .. ".legend" .. k, {
      drawing = false,
      icon = {
        string = "●",
        width = legend_dot_w,
        align = "left",
        font = { family = settings.font.family, size = 9.0 },
        color = theme.text_muted,
        padding_left = 0,
        padding_right = 0,
      },
      label = {
        string = "",
        align = "left",
        font = cap_font,
        color = theme.text_muted,
        padding_left = 0,
        padding_right = 0,
      },
    })
  end
  card.totals = pop_item(prefix .. ".totals", {
    icon = {
      string = "All time · —",
      width = col_all,
      align = "left",
      font = stat_font,
      color = theme.text_muted,
      padding_left = 0,
      padding_right = 0,
    },
    label = {
      string = "30d · —",
      width = col_30,
      align = "left",
      font = stat_font,
      color = theme.text_muted,
      padding_left = 0,
      padding_right = 0,
    },
  })
  -- Same y as totals (relayout peer): empty icon holds All+30d, label is 7d.
  card.week = pop_item(prefix .. ".week", {
    icon = {
      string = "",
      width = col_all + col_30,
      align = "left",
      font = stat_font,
      color = theme.text_muted,
      padding_left = 0,
      padding_right = 0,
    },
    label = {
      string = "7d · —",
      width = col_7,
      align = "left",
      font = stat_font,
      color = theme.text_muted,
      padding_left = 0,
      padding_right = 0,
    },
  })
  local function chart_row(name, key, font)
    card[key] = pop_item(prefix .. "." .. name, {
      icon = {
        string = "",
        width = content_w,
        align = "left",
        font = font or mono,
        color = theme.text_muted,
        padding_left = 0,
        padding_right = 0,
      },
      label = { drawing = false },
    })
  end
  chart_row("counts", "counts")
  chart_row("spark", "spark", mono_bar)
  chart_row("dows", "dows")
  card.extras = {}
  for e = 1, extra_max do
    card.extras[e] = pop_item(prefix .. ".extra" .. e, {
      icon = {
        string = "",
        width = math.floor(content_w * 0.48),
        align = "left",
        font = body_font,
        color = theme.text_muted,
        padding_left = 0,
        padding_right = 0,
      },
      label = {
        string = "",
        width = content_w - math.floor(content_w * 0.48),
        align = "right",
        font = body_font,
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
local h_sub = 18
local h_meter = 12
local h_legend = 16
local h_cap = 20
local h_chart = 18
local h_sep = 14
local gap_section = 6
local gap_header = 8

local function card_tier(st)
  local tier = st.tier
  if type(tier) == "string" and tier ~= "" then
    return tier
  end
  return nil
end

local function show_ident(st)
  if not card_tier(st) then
    return false
  end
  return (type(st.email) == "string" and st.email ~= "") or tonumber(st.renews_unix) ~= nil
end

local function show_sub(st)
  return st.weekly ~= nil and card_tier(st) ~= nil
end

local function relayout()
  local entries = {}
  -- peers share the row's y_offset; keep_w rows own their width (bar segments
  -- are positioned via width + paddings, so width must not be reset to 0).
  local function push(item, h, peers, keep_w)
    entries[#entries + 1] = { item = item, h = h, peers = peers, keep_w = keep_w }
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
    push(card.head, h_head, show_ident(st) and { card.ident } or nil)
    if show_sub(st) then
      push(card.sub, h_sub)
    end
    if st.weekly then
      push(card.meter_rest, h_meter, card.meter_segs, true)
    end
    if (st.legend_n or 0) > 0 then
      push(card.legend[1], h_legend, card.legend, true)
    end
    local has_days = next(st.days or {}) ~= nil
    local has_totals = st.total_tokens ~= nil or st.days30_tokens ~= nil
    if has_totals or has_days then
      gap(gap_section)
      push(card.totals, h_cap, { card.week })
    end
    if has_days then
      gap(4)
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
      local y_off = math.floor(y - e.h / 2 + 0.5)
      if e.keep_w then
        e.item:set { y_offset = y_off }
      else
        e.item:set { y_offset = y_off, width = 0 }
      end
      for _, peer in ipairs(e.peers or {}) do
        peer:set { y_offset = y_off }
      end
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

local function fg_color(weekly)
  if not weekly then
    return theme.text_muted
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
    color = fg_color(weekly),
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
  local cur_fg = fg_color((last[bar_list[bar_i].id] or {}).weekly)
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

local function apply_meter(card, weekly, cats, accent)
  if not weekly then
    for k = 1, seg_max do
      card.meter_segs[k]:set { drawing = false }
    end
    card.meter_rest:set { drawing = false }
    return
  end
  local x = 0
  local n = cats and #cats or 0
  for k = 1, seg_max do
    local cat = cats and cats[k]
    if cat and x < content_w then
      local w = math.max(cat.pct * content_w, 2)
      if x + w > content_w then
        w = content_w - x
      end
      set_bar_seg(card.meter_segs[k], x, w - (k < n and seg_gap or 0), category_color(cat.label, k))
      x = x + w
    else
      card.meter_segs[k]:set { drawing = false }
    end
  end
  if n == 0 then
    x = logic.clamp(logic.number(weekly.used, 0), 0, 1) * content_w
    set_bar_seg(card.meter_segs[1], 0, x, accent)
  end
  local rest_x = x > 0 and (x + seg_gap) or 0
  if rest_x < content_w - 1 then
    set_bar_seg(card.meter_rest, rest_x, content_w - rest_x, track_color(accent))
  else
    card.meter_rest:set { drawing = false }
  end
end

-- 11pt legend text ≈ 6.4 px/char (SF Pro, same calibration family as chips).
local legend_px_per_char = 6.4

local function apply_legend(card, cats)
  local shown = 0
  local x = 0
  for k = 1, seg_max do
    local cat = cats and cats[k]
    if cat then
      local text = cat.label .. " " .. logic.category_percent(cat.pct)
      local chars = (utf8 and utf8.len(text)) or #text
      local tw = math.ceil(chars * legend_px_per_char) + 4
      if x + legend_dot_w + tw <= content_w then
        card.legend[k]:set {
          drawing = true,
          padding_left = pad + x,
          padding_right = -(pad + x),
          icon = { string = "●", color = category_color(cat.label, k) },
          label = { string = text, width = tw, color = theme.text_muted },
        }
        shown = shown + 1
        x = x + legend_dot_w + tw + 10
      else
        card.legend[k]:set { drawing = false }
      end
    else
      card.legend[k]:set { drawing = false }
    end
  end
  return shown
end

local function apply_card(p, now)
  local card = cards[p.id]
  local st = last[p.id]
  local weekly = st.weekly
  local fill = p.accent
  local tier = card_tier(st)
  local cats = weekly and st.cats or nil
  if cats and #cats == 0 then
    cats = nil
  end

  card.sep:set { drawing = p ~= providers[1], icon = { color = theme.text_muted } }

  -- Head: plan name when known (usage detail moves to the subline), else the
  -- classic "x% used · resets in" line.
  local head_label
  if tier then
    head_label = tier
  elseif weekly then
    head_label = logic.used_line(weekly, now)
  else
    head_label = st.status or logic.NO_WEEKLY
  end
  card.head:set {
    drawing = true,
    icon = { string = p.label, color = p.accent },
    label = {
      string = head_label,
      color = (tier or weekly) and theme.text_primary or theme.text_muted,
    },
  }

  local ident_parts = {}
  if type(st.email) == "string" and st.email ~= "" then
    ident_parts[#ident_parts + 1] = st.email
  end
  local renews = logic.renews_line(st.renews_unix, st.cancels)
  if renews ~= "" then
    ident_parts[#ident_parts + 1] = renews
  end
  card.ident:set {
    drawing = show_ident(st),
    label = { string = table.concat(ident_parts, " · "), color = theme.text_muted },
  }

  card.sub:set {
    drawing = show_sub(st),
    icon = { string = weekly and logic.usage_line(weekly) or "", color = theme.text_primary },
    label = { string = weekly and logic.reset_line(weekly, now) or "", color = theme.text_muted },
  }

  apply_meter(card, weekly, cats, fill)
  st.legend_n = apply_legend(card, cats)

  local days = st.days or {}
  local has_days = next(days) ~= nil
  local has_totals = st.total_tokens ~= nil or st.days30_tokens ~= nil
  local show_stats = has_totals or has_days
  local wtok, wusd = st.week_tokens, st.week_usd
  if wtok == nil and has_days then
    wtok, wusd = logic.window_sum(days, now)
    if wusd == 0 then
      wusd = nil
    end
  end
  card.totals:set {
    drawing = show_stats,
    icon = { string = logic.total_line(st.total_tokens, st.total_usd), color = theme.text_muted },
    label = {
      string = logic.days30_line(st.days30_tokens, st.days30_usd),
      color = theme.text_muted,
    },
  }
  card.week:set {
    drawing = show_stats,
    icon = { string = "", width = col_all + col_30 },
    label = { string = logic.week_line(wtok, wusd), color = theme.text_muted },
  }
  local counts, spark, labels = logic.chart_lines(days, now, logic.chart_cell_for(content_w))
  card.counts:set { drawing = has_days, icon = { string = counts, color = theme.text_primary } }
  card.spark:set { drawing = has_days, icon = { string = spark, color = fill } }
  card.dows:set { drawing = has_days, icon = { string = labels, color = theme.text_muted } }

  for e = 1, extra_max do
    local extra = st.extras and st.extras[e]
    if extra then
      card.extras[e]:set {
        drawing = true,
        icon = { string = extra.label, color = theme.text_muted },
        label = {
          string = extra.text or logic.extra_line(extra.weekly, now),
          color = theme.text_primary,
        },
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
  -- sbar.exec JSON → table. Lua-literal helpers still arrive as a string.
  if type(lit) == "table" then
    if lit.error then
      return { error = lit.error }
    end
    return lit
  end
  if type(lit) ~= "string" or lit == "" then
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
    st.cats = logic.categories(result.categories)
    st.tier = result.tier
    st.email = result.email
    st.renews_unix = tonumber(result.renews_unix)
    st.cancels = result.cancels == true
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
    -- On-demand / usage-based spend (cents): "$86 of $400 used" or the
    -- included allowance when Cursor reports no remaining figure.
    local lim = tonumber(result.spend_limit_cents) or tonumber(result.included_spend_cents)
    if lim and lim > 0 and #st.extras < extra_max then
      local rem = tonumber(result.spend_remaining_cents)
      local text
      if rem then
        text = logic.usd(math.max(0, lim - rem) / 100) .. " of " .. logic.usd(lim / 100) .. " used"
      else
        text = logic.usd(lim / 100) .. " included"
      end
      st.extras[#st.extras + 1] = { label = "Usage-based spend", text = text }
    end
    st.tier = result.plan
    st.email = result.email
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
      local week = prov.week
      local d30 = prov.days30
      last[p.id].month_tokens = type(month) == "table" and tonumber(month.tokens) or nil
      last[p.id].month_usd = type(month) == "table" and tonumber(month.usd) or nil
      last[p.id].total_tokens = type(tot) == "table" and tonumber(tot.tokens) or nil
      last[p.id].total_usd = type(tot) == "table" and tonumber(tot.usd) or nil
      last[p.id].week_tokens = type(week) == "table" and tonumber(week.tokens) or nil
      last[p.id].week_usd = type(week) == "table" and tonumber(week.usd) or nil
      last[p.id].days30_tokens = type(d30) == "table" and tonumber(d30.tokens) or nil
      last[p.id].days30_usd = type(d30) == "table" and tonumber(d30.usd) or nil
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
