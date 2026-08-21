local colors = require "colors"
local settings = require "settings"
local logic = require "logic"

local WTTR_URL = "https://wttr.in/?format=%t&m"

local weather = sbar.add("item", "center.weather", {
  position = "center",
  icon = {
    string = "􀆭",
    color = colors.blue,
    padding_left = 5,
    padding_right = 2,
    font = {
      family = settings.font.family,
      style = settings.font.style_map["Bold"],
      size = 13.0,
    },
  },
  label = {
    string = "--°",
    color = colors.text,
    padding_left = 2,
    padding_right = 6,
    font = {
      family = settings.font.family,
      style = settings.font.style_map["Bold"],
      size = 12.0,
    },
  },
  background = { drawing = false },
  update_freq = 1800,
})

local function update()
  sbar.exec("curl -s --max-time 5 '" .. WTTR_URL .. "'", function(out)
    local temp = logic.weather_label(out)
    if temp then
      weather:set { label = { string = temp } }
    end
  end)
end

weather:subscribe({ "routine", "system_woke", "forced", "deferred_wake" }, update)
weather:subscribe("theme_colors_updated", function()
  weather:set {
    icon = { color = colors.blue },
    label = { color = colors.text },
  }
end)

update()
