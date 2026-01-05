local colors = require "colors"
local icons = require "icons"
local settings = require "settings"

local weather = sbar.add("item", "top.widgets.weather", {
  position = "right",
  update_freq = 1800,
  icon = {
    string = icons.weather,
    color = colors.yellow,
    padding_left = 8,
    padding_right = 4,
    font = {
      style = "Regular",
      size = 16.0,
    },
  },
  label = {
    string = "?°",
    font = {
      style = settings.font.style_map["Bold"],
      size = 14.0,
    },
    padding_right = 8,
    color = colors.white,
  },
})

weather:subscribe({ "routine", "system_woke" }, function()
  sbar.exec("curl -s 'wttr.in/?format=%t'", function(temp)
    if temp and temp:match "%S" then
      weather:set {
        label = { string = temp:gsub("\n", "") },
      }
    end
  end)
end)

weather:subscribe("mouse.clicked", function()
  sbar.exec "open -a Weather"
end)
