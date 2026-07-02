-- Credits to https://github.com/TaterDoge/dotfiles/tree/main
local colors = require "colors"
local icons = require "icons"
local settings = require "settings"
local ui = require "ui"

local theme = settings.theme
local metrics = settings.ui
local accent = colors.peach

local popup_width = 280
local popup_pad =  metrics.popup_label_padding
local bar_height = 12
local bar_track_width = popup_width - popup_pad * 2

local popup_row = { drawing = false, height = metrics.popup_row_height }

local ccu_item = ui.add_capsule("widgets.ccu", {
  position = "left",
  icon = { drawing = false },
  label = {
    string = "CCu",
    font = {
      family = settings.font.numbers,
      style = settings.font.style_map["Bold"],
      size = 12.0,
    },
    color = accent,
    padding_right = 10,
  },
})

local ccu_bracket = sbar.add("bracket", "widgets.ccu.bracket", {
  ccu_item.name,
}, {
  background = ui.capsule {
    color = colors.with_alpha(accent, colors.is_dark and 0.16 or 0.10),
    border_width = 0,
  },
  popup = {
    align = "center",
    y_offset = metrics.popup_y_offset,
    background = ui.popup(accent),
  },
})

local function popup_item(name, spec)
  return sbar.add("item", name, {
    position = "popup." .. ccu_bracket.name,
    width = popup_width,
    background = popup_row,
    icon = spec.icon or { drawing = false },
    label = spec.label or { drawing = false },
    align = spec.align,
    click_script = spec.click_script,
  })
end

local function set_bar_percent(label_item, bar_item, percent)
  local fill_width = math.floor(percent / 100 * bar_track_width + 0.5)
  bar_item:set({ icon = { width = fill_width } })
  label_item:set({ label = { string = percent .. "%" } })
end

local title_font = {
  family = settings.font.text,
  style = settings.font.style_map["Bold"],
  size = 13.0,
}
local value_font = {
  family = settings.font.numbers,
  size = 12.0,
}
local meta_font = {
  family = settings.font.numbers,
  size = 11.0,
}

popup_item("widgets.ccu.spacer_0", {
  label = { string = "", font = meta_font, color = theme.text_muted },
})

local session_label = popup_item("widgets.ccu.session_label", {
  icon = {
    string = "Current Session",
    color = colors.mauve,
    width = popup_width / 2,
    font = title_font,
  },
  label = {
    string = "--%",
    color = colors.mauve,
    align = "right",
    width = popup_width / 2,
    font = value_font,
  },
})

local session_bar = popup_item("widgets.ccu.session_bar", {
  icon = {
    string = " ",
    width = 0,
    padding_left = 0,
    padding_right = 0,
    background = {
      color = colors.mauve,
      height = bar_height,
      corner_radius = 2,
    },
  },
  label = { drawing = false },
})
session_bar:set({
  background = {
    drawing = true,
    color = colors.with_alpha(colors.mauve, 0.22),
    height = bar_height,
    corner_radius = 2,
    border_width = 0,
    padding_left = popup_pad,
    padding_right = popup_pad,
  },
})

local session_reset = popup_item("widgets.ccu.session_reset", {
  label = {
    string = "Resets: --",
    color = theme.text_muted,
    font = meta_font,
  },
})

popup_item("widgets.ccu.spacer_1", {
  label = { string = "", font = meta_font, color = theme.text_muted },
})

local weekly_label = popup_item("widgets.ccu.weekly_label", {
  icon = {
    string = "Weekly Usage",
    color = colors.blue,
    width = popup_width / 2,
    font = title_font,
  },
  label = {
    string = "--%",
    color = colors.blue,
    align = "right",
    width = popup_width / 2,
    font = value_font,
  },
})

local weekly_bar = popup_item("widgets.ccu.weekly_bar", {
  icon = {
    string = " ",
    width = 0,
    padding_left = 0,
    padding_right = 0,
    background = {
      color = colors.blue,
      height = bar_height,
      corner_radius = 2,
    },
  },
  label = { drawing = false },
})
weekly_bar:set({
  background = {
    drawing = true,
    color = colors.with_alpha(colors.blue, 0.22),
    height = bar_height,
    corner_radius = 2,
    border_width = 0,
    padding_left = popup_pad,
    padding_right = popup_pad,
  },
})

local weekly_reset = popup_item("widgets.ccu.weekly_reset", {
  label = {
    string = "Resets: --",
    color = theme.text_muted,
    font = meta_font,
  },
})

popup_item("widgets.ccu.spacer_2", {
  label = { string = "", font = meta_font, color = theme.text_muted },
})

local extra_label = popup_item("widgets.ccu.extra_label", {
  icon = {
    string = "Extra Usage",
    color = colors.green,
    width = popup_width / 2,
    font = title_font,
  },
  label = {
    string = "--%",
    color = colors.green,
    align = "right",
    width = popup_width / 2,
    font = value_font,
  },
})

local extra_bar = popup_item("widgets.ccu.extra_bar", {
  icon = {
    string = " ",
    width = 0,
    padding_left = 0,
    padding_right = 0,
    background = {
      color = colors.green,
      height = bar_height,
      corner_radius = 2,
    },
  },
  label = { drawing = false },
})
extra_bar:set({
  background = {
    drawing = true,
    color = colors.with_alpha(colors.green, 0.22),
    height = bar_height,
    corner_radius = 2,
    border_width = 0,
    padding_left = popup_pad,
    padding_right = popup_pad,
  },
})

local extra_info = popup_item("widgets.ccu.extra_info", {
  label = {
    string = "",
    color = theme.text_muted,
    font = meta_font,
  },
})

local link = popup_item("widgets.ccu.link", {
  icon = {
    string = icons.external_link,
    color = theme.text_muted,
    font = { size = 11.0 },
    padding_left = popup_pad,
    padding_right = 4,
  },
  label = {
    string = "open Anthropic usage page",
    color = theme.text_muted,
    font = meta_font,
    padding_right = popup_pad,
  },
  align = "right",
  click_script = "open https://claude.ai/settings/usage",
})

local function ccu_fetch_cmd()
  return "python3 " .. os.getenv "HOME" .. "/.dotfiles/sketchybar/helpers/claude_usage.py"
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
    local eu = result.extra_usage

    callback({
      five_hour = fh and tonumber(fh.utilization),
      weekly = sd and tonumber(sd.utilization),
      resets_at = fh and (fh.resets_at_de or fh.resets_at),
      weekly_resets_at = sd and (sd.resets_at_de or sd.resets_at),
      extra_usage = eu,
      source = result.source,
    })
  end)
end

local function refresh_theme()
  local pill = ui.capsule {
    color = colors.with_alpha(accent, colors.is_dark and 0.16 or 0.10),
    border_width = 0,
  }

  ccu_bracket:set({
    background = pill,
    popup = { background = ui.popup(accent) },
  })

  ccu_item:set({
    background = ui.capsule(),
    label = { color = accent },
  })

  session_label:set({
    icon = { color = colors.mauve },
    label = { color = colors.mauve },
  })
  session_bar:set({
    icon = { background = { color = colors.mauve } },
    background = { color = colors.with_alpha(colors.mauve, 0.22) },
  })
  session_reset:set({ label = { color = theme.text_muted } })

  weekly_label:set({
    icon = { color = colors.blue },
    label = { color = colors.blue },
  })
  weekly_bar:set({
    icon = { background = { color = colors.blue } },
    background = { color = colors.with_alpha(colors.blue, 0.22) },
  })
  weekly_reset:set({ label = { color = theme.text_muted } })

  extra_label:set({
    icon = { color = colors.green },
    label = { color = colors.green },
  })
  extra_bar:set({
    icon = { background = { color = colors.green } },
    background = { color = colors.with_alpha(colors.green, 0.22) },
  })
  extra_info:set({ label = { color = theme.text_muted } })

  link:set({
    icon = { color = theme.text_muted },
    label = { color = theme.text_muted },
  })
end

ccu_bracket:subscribe("theme_colors_updated", refresh_theme)
refresh_theme()

local function update_popup()
  get_claude_usage(function(result)
    if ccu_bracket:query().popup.drawing ~= "on" then
      return
    end

    if result.error then
      session_label:set({ label = { string = "err" } })
      session_reset:set({ label = { string = result.error } })
      weekly_label:set({ label = { string = "--%" } })
      weekly_reset:set({ label = { string = "" } })
      extra_label:set({ label = { string = "Disabled" } })
      extra_bar:set({ background = { drawing = false }, icon = { drawing = false } })
      extra_info:set({ label = { string = "" } })
      return
    end

    if result.five_hour then
      set_bar_percent(session_label, session_bar, result.five_hour)
    end
    session_reset:set({
      label = { string = "Resets: " .. (result.resets_at or "---") },
    })

    if result.weekly then
      set_bar_percent(weekly_label, weekly_bar, result.weekly)
    end
    weekly_reset:set({
      label = { string = "Resets: " .. (result.weekly_resets_at or "---") },
    })

    local eu = result.extra_usage
    if eu and eu.is_enabled then
      local pct = eu.utilization and tonumber(eu.utilization) or 0
      set_bar_percent(extra_label, extra_bar, pct)
      extra_bar:set({ background = { drawing = true }, icon = { drawing = true } })
      local used = eu.used_credits and string.format("%.2f", tonumber(eu.used_credits) / 100) or "?"
      local limit = eu.monthly_limit and string.format("%.2f", tonumber(eu.monthly_limit) / 100) or "?"
      extra_info:set({ label = { string = "Used: €" .. used .. " / €" .. limit } })
    else
      extra_label:set({ label = { string = "Disabled" } })
      extra_bar:set({ background = { drawing = false }, icon = { drawing = false } })
      extra_info:set({ label = { string = "" } })
    end
  end)
end

local refresh_timer = sbar.add("item", "widgets.ccu.refresh_timer", {
  update_freq = 10,
  drawing = false,
})

refresh_timer:subscribe("routine", function()
  if ccu_bracket:query().popup.drawing == "on" then
    update_popup()
  end
end)

ui.bind_popup_group(ccu_bracket, { ccu_item }, { on_open = update_popup })