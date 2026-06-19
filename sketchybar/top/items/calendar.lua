local colors = require "colors"
local settings = require "settings"
local ui = require "ui"

local cal = ui.add_capsule("widgets.calendar", {
  update_freq = 30,
  icon = { drawing = false },
  label = {
    color = colors.cal,
    padding_left = 10,
    padding_right = 10,
    font = {
      family = settings.font.numbers,
      style = settings.font.style_map["Semibold"],
      size = 13.0,
    },
  },
  popup = { align = "center" },
  click_script = "open -a 'Calendar'",
})

cal:subscribe({ "forced", "routine", "system_woke" }, function()
  cal:set { label = os.date "%a %d %b  -  %H:%M" }
end)
