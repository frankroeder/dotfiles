local settings = require("settings")
local colors = require("colors")

local cal = sbar.add("item", "top.widgets.calendar", {
  position = "right",
  update_freq = 30,
  icon = {
    color = colors.white,
    padding_left = 8,
    font = {
      style = settings.font.style_map["Black"],
      size = 12.0,
    },
  },
  label = {
    color = colors.white,
    padding_right = 8,
    width = 49,
    align = "right",
    font = { family = settings.font.numbers },
  },
  click_script = "open -a 'Calendar'"
})

cal:subscribe({ "forced", "routine", "system_woke" }, function(env)
  cal:set({ icon = os.date("%a. %d %b."), label = os.date("%H:%M") })
end)
