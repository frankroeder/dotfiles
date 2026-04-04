local settings = require "settings"
local colors = require "colors"
local icons = require "icons"
local ui = require "ui"

local cal = sbar.add("item", "widgets.calendar", {
  position = "right",
  update_freq = 30,
  label = {
    color = settings.theme.text_primary,
    padding_right = 8,
    padding_left = 0,
    font = {
      family = settings.font.numbers,
      style = settings.font.style_map["Semibold"],
      size = 13.0,
    },
  },
  background = ui.capsule {
    color = settings.theme.surface_alt,
    border_color = colors.with_alpha(settings.theme.success, 0.42),
  },
  click_script = "open -a 'Calendar'",
})

cal:subscribe({ "forced", "routine", "system_woke" }, function(env)
  cal:set { label = os.date "%a %d %b  %H:%M" }
end)
