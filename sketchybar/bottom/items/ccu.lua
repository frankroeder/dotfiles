-- Credits to https://github.com/TaterDoge/dotfiles/tree/main
local colors = require "colors"
local icons = require "icons"
local settings = require "settings"
local ui = require "ui"

local theme = settings.theme
local metrics = settings.ui

local popup_width = 440
local popup_pad = 12
local title_width = 72
local bar_width = 120
local bar_height = 18
local row_height = 34

local accent_session = colors.mauve or theme.accent
local accent_weekly = colors.blue or theme.accent
local last_usage = { session = 0, weekly = 0 }

local NO_BG = { drawing = false }

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
  style = settings.font.style_map["Bold"],
  size = 15.0,
}
local value_font = {
  family = settings.font.numbers,
  size = 13.0,
}

local function track_color(accent)
  return colors.with_alpha(accent, colors.is_dark and 0.18 or 0.12)
end

-- One slider row per metric: title (icon) + proportional bar + value (label).
local function metric_row(name, title, accent)
  return sbar.add("slider", name, bar_width, {
    position = "popup." .. ccu.name,
    width = popup_width,
    padding_left = popup_pad,
    padding_right = popup_pad,
    icon = {
      string = title,
      width = title_width,
      align = "left",
      padding_left = 0,
      padding_right = 6,
      font = title_font,
      color = accent,
    },
    label = {
      string = "…",
      align = "right",
      padding_left = 6,
      padding_right = 0,
      max_chars = 40,
      font = value_font,
      color = theme.text_muted,
    },
    slider = {
      percentage = 0,
      highlight_color = accent,
      background = {
        height = bar_height,
        corner_radius = bar_height / 2,
        color = track_color(accent),
      },
      knob = { drawing = false, string = "" },
    },
    background = { drawing = false, height = row_height },
  })
end

local function set_percent(item, accent, percent)
  item:set({
    slider = {
      percentage = percent == nil and 0 or math.floor(percent + 0.5),
      highlight_color = accent,
      background = {
        height = bar_height,
        corner_radius = bar_height / 2,
        color = track_color(accent),
      },
      knob = { drawing = false, string = "" },
    },
  })
end

local session_row = metric_row("widgets.ccu.session", "Session", accent_session)
local weekly_row = metric_row("widgets.ccu.weekly", "Weekly", accent_weekly)

local extra_row = sbar.add("item", "widgets.ccu.extra", {
  position = "popup." .. ccu.name,
  width = popup_width,
  padding_left = popup_pad,
  padding_right = popup_pad,
  icon = {
    string = "Extra",
    width = title_width,
    align = "left",
    padding_left = 0,
    padding_right = 6,
    font = title_font,
    color = theme.text_muted,
  },
  label = {
    string = "…",
    align = "right",
    padding_left = 0,
    padding_right = 0,
    max_chars = 24,
    font = value_font,
    color = theme.text_muted,
  },
  background = { drawing = false, height = row_height },
})

local link = sbar.add("item", "widgets.ccu.link", {
  position = "popup." .. ccu.name,
  width = popup_width,
  padding_left = popup_pad,
  padding_right = popup_pad,
  icon = {
    string = icons.external_link,
    color = theme.text_muted,
    font = { size = 13.0 },
    padding_left = 0,
    padding_right = 6,
  },
  label = {
    string = "Anthropic Usage page",
    color = theme.text_muted,
    font = {
      family = settings.font.numbers,
      size = 13.0,
    },
    padding_left = 0,
    padding_right = 0,
  },
  align = "center",
  background = { drawing = false, height = row_height },
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
      callback({ error = "empty_response" })
      return
    end

    local fn = load("return " .. lit, "ccu_json", "t", {})
    local result = (fn and fn()) or {}

    if type(result) ~= "table" then
      callback({ error = "invalid_response" })
      return
    end

    if result.error then
      callback({ error = result.error })
      return
    end

    local fh = result.five_hour
    local sd = result.seven_day

    callback({
      five_hour = pct_value(fh),
      weekly = pct_value(sd),
      resets_at = fh and (fh.resets_at_de or fh.resets_at),
      weekly_resets_at = sd and (sd.resets_at_de or sd.resets_at),
      extra_usage = result.extra_usage,
    })
  end)
end

local function format_pct(percent, reset)
  if percent == nil then
    return "—"
  end
  local text = string.format("%.0f%%", percent)
  if reset and reset ~= "" then
    text = text .. " · " .. reset
  end
  return text
end

local function apply_usage(result)
  if result.error then
    last_usage.session, last_usage.weekly = 0, 0
    session_row:set({ label = { string = result.error, color = theme.critical } })
    weekly_row:set({ label = { string = "—", color = theme.text_muted } })
    extra_row:set({ label = { string = "—", color = theme.text_muted } })
    set_percent(session_row, accent_session, 0)
    set_percent(weekly_row, accent_weekly, 0)
    return
  end

  last_usage.session = result.five_hour or 0
  last_usage.weekly = result.weekly or 0

  session_row:set({
    label = { string = format_pct(result.five_hour, result.resets_at), color = theme.text_muted },
  })
  weekly_row:set({
    label = { string = format_pct(result.weekly, result.weekly_resets_at), color = theme.text_muted },
  })
  set_percent(session_row, accent_session, result.five_hour)
  set_percent(weekly_row, accent_weekly, result.weekly)

  local eu = result.extra_usage
  if eu and eu.is_enabled then
    local pct = pct_value(eu) or 0
    local used = eu.used_credits and string.format("%.2f", tonumber(eu.used_credits) / 100) or "?"
    local limit = eu.monthly_limit and string.format("%.2f", tonumber(eu.monthly_limit) / 100) or "?"
    extra_row:set({
      label = { string = string.format("%.0f%% · €%s/€%s", pct, used, limit), color = theme.text_muted },
    })
  else
    extra_row:set({ label = { string = "disabled", color = theme.text_muted } })
  end
end

local function refresh_theme()
  ccu:set({
    background = ui.capsule(),
    label = { color = theme.text_muted },
  })
  link:set({
    icon = { color = theme.text_muted },
    label = { color = theme.text_muted },
  })
  set_percent(session_row, accent_session, last_usage.session)
  set_percent(weekly_row, accent_weekly, last_usage.weekly)
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
