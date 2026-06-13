local colors = require "colors"
local settings = require "settings"
local ui = require "ui"

local cal = sbar.add("item", "widgets.calendar", {
  position = "right",
  padding_left = settings.paddings,
  padding_right = settings.paddings,
  update_freq = 30,
  icon = { drawing = false },
  label = {
    color = colors.cal,
    padding_right = 10,
    padding_left = 10,
    font = {
      family = settings.font.numbers,
      style = settings.font.style_map["Semibold"],
      size = 13.0,
    },
  },
  background = ui.capsule {},
  popup = { align = "center" },
  click_script = "open -a 'Calendar'",
})

cal:subscribe({ "forced", "routine", "system_woke" }, function(env)
  cal:set { label = os.date "%a %d %b  -  %H:%M" }
end)
