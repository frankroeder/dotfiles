local colors = require("colors")
local icons = require("icons")
local settings = require("settings")

local calendar = sbar.add("item", "top.widgets.calendar", {
  position = "right",
  update_freq = 30,
  icon = {
    string = icons.calendar,
    padding_left = 8,
    color = colors.white,
  },
  label = {
    color = colors.white,
    padding_right = 8,
    font = {
      style = settings.font.style_map["Bold"],
      size = 14.0,
    }
  },
})

calendar:subscribe({ "routine", "system_woke" }, function()
  sbar.exec("date '+%a %d. %b %H:%M'", function(date)
    calendar:set({ label = date })
  end)
end)

calendar:subscribe("mouse.clicked", function()
  sbar.exec("open -a Calendar")
end)
