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
local title_w = 72
local bar_w = 100
local value_w = 148
local bar_h = 6
local row_h = metrics.popup_row_height
local content_w = title_w + bar_w + value_w
local popup_width = content_w + pad * 2
local helpers = os.getenv "HOME" .. "/.dotfiles/sketchybar/helpers"

-- Horizontal popup (like media): width=0 rows stack via y_offset; link buttons share
-- the bottom y_offset and pack left-to-right.
local row_gap = 2
local popup_h = row_h * 4 + row_gap * 3 + 10
local y_session = math.floor(1.5 * (row_h + row_gap))
local y_weekly = math.floor(0.5 * (row_h + row_gap))
local y_grok = -math.floor(0.5 * (row_h + row_gap))
local y_links = -math.floor(1.5 * (row_h + row_gap))
local btn_gap = 6
local btn_w = math.floor((content_w - btn_gap) / 2)

local accent_session = colors.mauve
local accent_weekly = colors.blue
local accent_grok = colors.teal
local last = { session = nil, weekly = nil, grok = nil }

local ccu = ui.add_capsule("widgets.ccu", {
  position = "left",
  icon = { drawing = false },
  label = {
    string = "CCu",
    font = {
      family = settings.font.numbers,
      style = settings.font.style_map["Bold"],
      size = 12.0,
    },
    padding_right = 10,
  },
  popup = {
    align = "center",
    horizontal = true,
    height = popup_h,
    background = ui.popup(),
  },
})

-- Mono for titles+values so fixed icon/label widths actually column-align.
local title_font = {
  family = settings.font.numbers,
  style = settings.font.style_map["Semibold"],
  size = 12.0,
}
local value_font = {
  family = settings.font.numbers,
  size = 11.0,
}

local function track_color(accent)
  return colors.with_alpha(accent, colors.is_dark and 0.20 or 0.14)
end

local function usage_color(pct)
  if pct == nil then
    return theme.text_muted
  end
  if pct >= 90 then
    return theme.critical
  end
  if pct >= 75 then
    return colors.orange
  end
  if pct >= 50 then
    return theme.warn
  end
  return theme.text_muted
end

local function metric_row(name, title, accent, y)
  return sbar.add("slider", name, bar_w, {
    position = "popup." .. ccu.name,
    -- width=0 + zero item pads: pack length 0 so every row shares the same x.
    -- (In horizontal popups, padding_left/right advances x and staggered the rows.)
    width = 0,
    padding_left = 0,
    padding_right = 0,
    y_offset = y,
    icon = {
      string = title,
      width = title_w,
      align = "right",
      padding_left = 0,
      padding_right = col_gap, -- gap title → bar (inside title column)
      font = title_font,
      color = accent,
    },
    label = {
      string = "…",
      width = value_w,
      align = "left",
      padding_left = col_gap, -- gap bar → value (inside value column)
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

local function set_percent(item, accent, percent)
  item:set {
    slider = {
      percentage = percent == nil and 0 or math.floor(percent + 0.5),
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

-- Leading inset (horizontal pack). Metric rows use width=0 so they stay on this x.
sbar.add("item", "widgets.ccu.inset", {
  position = "popup." .. ccu.name,
  width = pad,
  padding_left = 0,
  padding_right = 0,
  icon = { drawing = false },
  label = { drawing = false },
  background = { drawing = false },
})

local session_row = metric_row("widgets.ccu.session", "Session", accent_session, y_session)
local weekly_row = metric_row("widgets.ccu.weekly", "Weekly", accent_weekly, y_weekly)
local grok_row = metric_row("widgets.ccu.grok", "Grok/mo", accent_grok, y_grok)

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

-- Side-by-side under the metric columns (total width = content_w).
local claude_link = link_button(
  "widgets.ccu.claude_link",
  "Claude",
  "https://claude.ai/settings/usage",
  0,
  math.floor(btn_gap / 2)
)
local grok_link = link_button(
  "widgets.ccu.grok_link",
  "Grok",
  "https://grok.com/?_s=usage",
  math.ceil(btn_gap / 2),
  0
)

local function parse_lua_table(lit, tag)
  if not lit or lit == "" then
    return { error = "empty_response" }
  end
  local fn = load("return " .. lit, tag, "t", {})
  local result = (fn and fn()) or {}
  if type(result) ~= "table" then
    return { error = "invalid_response" }
  end
  if result.error then
    return { error = result.error }
  end
  return result
end

local function pct_value(block)
  if not block or block.utilization == nil then
    return nil
  end
  return tonumber(block.utilization)
end

local function get_claude_usage(callback)
  sbar.exec("python3 " .. helpers .. "/claude_usage.py", function(lit)
    local result = parse_lua_table(lit, "ccu_claude")
    if result.error then
      callback(result)
      return
    end
    local fh = result.five_hour
    local sd = result.seven_day
    callback {
      five_hour = pct_value(fh),
      weekly = pct_value(sd),
      resets_at = fh and (fh.resets_at_de or fh.resets_at),
      weekly_resets_at = sd and (sd.resets_at_de or sd.resets_at),
    }
  end)
end

local function get_grok_usage(callback)
  sbar.exec("python3 " .. helpers .. "/grok_usage.py", function(lit)
    local result = parse_lua_table(lit, "ccu_grok")
    if result.error then
      callback(result)
      return
    end
    callback {
      utilization = tonumber(result.utilization),
      resets_at = result.resets_at_de or result.resets_at,
    }
  end)
end

-- "2026-07-09 11:19 (CEST)" → "09.07. 11:19" (German date)
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

local function format_pct(percent, reset)
  if percent == nil then
    return "—"
  end
  -- Fixed-width percent (mono) so · dates share one column.
  local text = string.format("%3.0f%%", percent)
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

local function set_capsule(session_pct, weekly_pct, grok_pct, err)
  if err then
    ccu:set {
      background = ui.capsule(),
      label = { string = "CCu ?", color = theme.critical },
    }
    return
  end

  local pct = max_pct(session_pct, weekly_pct, grok_pct)
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

local function apply_claude(result)
  if result.error then
    last.session, last.weekly = nil, nil
    session_row:set { label = { string = result.error, color = theme.critical } }
    weekly_row:set { label = { string = "—", color = theme.text_muted } }
    set_percent(session_row, accent_session, 0)
    set_percent(weekly_row, accent_weekly, 0)
  else
    last.session = result.five_hour
    last.weekly = result.weekly
    session_row:set {
      label = {
        string = format_pct(result.five_hour, result.resets_at),
        color = usage_color(result.five_hour),
      },
    }
    weekly_row:set {
      label = {
        string = format_pct(result.weekly, result.weekly_resets_at),
        color = usage_color(result.weekly),
      },
    }
    set_percent(session_row, accent_session, result.five_hour)
    set_percent(weekly_row, accent_weekly, result.weekly)
  end
  set_capsule(last.session, last.weekly, last.grok, result.error and not last.grok)
end

local function apply_grok(result)
  if result.error then
    last.grok = nil
    grok_row:set { label = { string = result.error, color = theme.critical } }
    set_percent(grok_row, accent_grok, 0)
  else
    last.grok = result.utilization
    grok_row:set {
      label = {
        string = format_pct(result.utilization, result.resets_at),
        color = usage_color(result.utilization),
      },
    }
    set_percent(grok_row, accent_grok, result.utilization)
  end
  set_capsule(last.session, last.weekly, last.grok, result.error and not last.session)
end

local function refresh_theme()
  -- Re-read palette: these track colors.* which mutate in place on theme change.
  accent_session = colors.mauve
  accent_weekly = colors.blue
  accent_grok = colors.teal
  ccu:set { popup = { background = ui.popup() } }
  session_row:set { icon = { color = accent_session }, label = { color = usage_color(last.session) } }
  weekly_row:set { icon = { color = accent_weekly }, label = { color = usage_color(last.weekly) } }
  grok_row:set { icon = { color = accent_grok }, label = { color = usage_color(last.grok) } }
  for _, btn in ipairs { claude_link, grok_link } do
    btn:set {
      label = { color = theme.text_muted },
      background = ui.button { height = row_h },
    }
  end
  set_percent(session_row, accent_session, last.session)
  set_percent(weekly_row, accent_weekly, last.weekly)
  set_percent(grok_row, accent_grok, last.grok)
  set_capsule(last.session, last.weekly, last.grok)
end

ccu:subscribe("theme_colors_updated", refresh_theme)
refresh_theme()

local function refresh_usage()
  get_claude_usage(apply_claude)
  get_grok_usage(apply_grok)
end

local refresh_timer = sbar.add("item", "widgets.ccu.refresh_timer", {
  update_freq = 10,
  drawing = false,
})

refresh_timer:subscribe("routine", function()
  if ccu:query().popup.drawing == "on" then
    refresh_usage()
  end
end)

ui.bind_popup(ccu, { on_open = refresh_usage })
refresh_usage()
