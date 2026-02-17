local settings = require "settings"
local colors = require "colors"

local cal = sbar.add("item", "widgets.calendar", {
  position = "right",
  update_freq = 30,
  icon = { drawing = false },
  label = {
    color = colors.white,
    padding_right = 8,
    padding_left = 8,
    font = {
      family = settings.font.numbers,
      style = settings.font.style_map["Bold"],
      size = 14.0,
    },
  },
  click_script = "open -a 'Calendar'",
})

cal:subscribe({ "forced", "routine", "system_woke" }, function(env)
  cal:set { label = os.date "%a. %d %b. %H:%M" }
end)
