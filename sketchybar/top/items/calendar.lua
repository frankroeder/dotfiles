local settings = require "settings"
local ui = require "ui"

local cal = sbar.add("item", "widgets.calendar", {
  position = "right",
  update_freq = 30,
  icon = { drawing = false },
  label = {
    color = settings.theme.text_muted,
    padding_right = 8,
    padding_left = 8,
    font = {
      family = settings.font.numbers,
      style = settings.font.style_map["Semibold"],
      size = 13.0,
    },
  },
  background = ui.capsule {
    color = settings.theme.surface,
    border_color = settings.theme.border,
  },
  popup = { align = "center" },
  click_script = "open -a 'Calendar'",
})

cal:subscribe({ "forced", "routine", "system_woke" }, function(env)
  cal:set { label = os.date "%a %d %b  %H:%M" }
end)
