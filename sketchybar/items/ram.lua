local colors = require "colors"
local settings = require "settings"
local icons = require "icons"

local ram = sbar.add("item", "widgets.ram1", {
  position = "right",
  width = 60,
  icon = {
    font = {
      family = settings.font.text,
      style = settings.font.style_map["Bold"],
      size = 18.0,
    },
    string = icons.ram,
    y_offset = 1,
  },
  label = {
    font = {
      family = settings.font.text,
      style = "Bold",
      size = 12.0,
    },
    padding_right = 8,
    string = "??%",
  },
  update_freq = 180,
  background = {
    color = colors.lightblack,
  },
})

ram:subscribe({ "routine", "forced", "system_woke" }, function(env)
  sbar.exec(
    "memory_pressure | grep -o 'System-wide memory free percentage: [0-9]*' | awk '{print $5}'",
    function(freeram)
      local usedram = 100 - tonumber(freeram)
      local Color = colors.white
      local label = tostring(usedram) .. "%"

      if usedram >= 80 then
        Color = colors.red
        label = "KILL ME"
        Padding_left = 0
      elseif usedram >= 60 then
        Color = colors.red
      elseif usedram >= 30 then
        Color = colors.orange
      elseif usedram >= 20 then
        Color = colors.yellow
      end

      ram:set {
        label = {
          string = label,
          color = Color,
          padding_left = Padding_left,
        },
        icon = {
          color = Color,
        },
      }
    end
  )
end)
