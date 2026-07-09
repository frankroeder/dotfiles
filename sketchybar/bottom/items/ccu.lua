-- Credits to https://github.com/TaterDoge/dotfiles/tree/main
local colors = require "colors"
local icons = require "icons"
local settings = require "settings"
local ui = require "ui"

local theme = settings.theme
local metrics = settings.ui

local popup_width = 280
local title_w = 52
local bar_w = 100
local value_w = 112
local bar_h = 6
local row_h = metrics.popup_row_height
local pad = 6

local accent_session = colors.mauve
local accent_weekly = colors.blue
local last = { session = nil, weekly = nil }

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
  popup = { align = "center" },
})

local title_font = {
  family = settings.font.text,
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

local function metric_row(name, title, accent)
  return sbar.add("slider", name, bar_w, {
    position = "popup." .. ccu.name,
    width = popup_width,
    align = "center",
    padding_left = pad,
    padding_right = pad,
    icon = {
      string = title,
      width = title_w,
      align = "right",
      padding_left = 0,
      padding_right = 6,
      font = title_font,
      color = accent,
    },
    label = {
      string = "…",
      width = value_w,
      align = "left",
      padding_left = 6,
      padding_right = 0,
      max_chars = 22,
      font = value_font,
      color = theme.text_muted,
    },
    slider = {
      percentage = 0,
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

local session_row = metric_row("widgets.ccu.session", "Session", accent_session)
local weekly_row = metric_row("widgets.ccu.weekly", "Weekly", accent_weekly)

local link = sbar.add("item", "widgets.ccu.link", {
  position = "popup." .. ccu.name,
  width = popup_width,
  align = "center",
  padding_left = pad,
  padding_right = pad,
  icon = { drawing = false },
  label = {
    string = icons.external_link .. "  claude.ai/usage",
    color = theme.text_muted,
    font = value_font,
    align = "center",
    padding_left = 0,
    padding_right = 0,
  },
  background = ui.button { height = row_h },
  click_script = "open https://claude.ai/settings/usage",
})

local function ccu_fetch_cmd()
  return "python3 " .. os.getenv "HOME" .. "/.dotfiles/sketchybar/helpers/claude_usage.py"
end

local function pct_value(block)
  if not block or block.utilization == nil then
    return nil
  end
  return tonumber(block.utilization)
end

local function get_claude_usage(callback)
  sbar.exec(ccu_fetch_cmd(), function(lit)
    if not lit or lit == "" then
      callback { error = "empty_response" }
      return
    end

    local fn = load("return " .. lit, "ccu_json", "t", {})
    local result = (fn and fn()) or {}

    if type(result) ~= "table" then
      callback { error = "invalid_response" }
      return
    end

    if result.error then
      callback { error = result.error }
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
  local text = string.format("%.0f%%", percent)
  local r = short_reset(reset)
  if r then
    text = text .. " · " .. r
  end
  return text
end

local function set_capsule(session_pct, weekly_pct, err)
  if err then
    ccu:set {
      background = ui.capsule(),
      label = { string = "CCu ?", color = theme.critical },
    }
    return
  end

  local pct = session_pct
  if pct == nil and weekly_pct ~= nil then
    pct = weekly_pct
  elseif pct ~= nil and weekly_pct ~= nil then
    pct = math.max(pct, weekly_pct)
  end

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

local function apply_usage(result)
  if result.error then
    last.session, last.weekly = nil, nil
    session_row:set { label = { string = result.error, color = theme.critical } }
    weekly_row:set { label = { string = "—", color = theme.text_muted } }
    set_percent(session_row, accent_session, 0)
    set_percent(weekly_row, accent_weekly, 0)
    set_capsule(nil, nil, true)
    return
  end

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
  set_capsule(result.five_hour, result.weekly)
end

local function refresh_theme()
  session_row:set { icon = { color = accent_session } }
  weekly_row:set { icon = { color = accent_weekly } }
  link:set {
    label = { color = theme.text_muted },
    background = ui.button { height = row_h },
  }
  set_percent(session_row, accent_session, last.session)
  set_percent(weekly_row, accent_weekly, last.weekly)
  set_capsule(last.session, last.weekly)
end

ccu:subscribe("theme_colors_updated", refresh_theme)
refresh_theme()

local function refresh_usage()
  get_claude_usage(apply_usage)
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
