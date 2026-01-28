local colors = require "colors"
local icons = require "icons"
local settings = require "settings"

local coffee = sbar.add("item", "widgets.coffee", {
  position = "left",
  icon = {
    string = icons.coffee.off,
    color = colors.grey,
    padding_left = 8,
    padding_right = 8,
    font = {
      style = settings.font.style_map["Regular"],
      size = 16.0,
    },
  },
  label = { drawing = false },
})

local function update_coffee()
  sbar.exec("pgrep -x caffeinate", function(pid)
    if pid ~= "" then
      coffee:set {
        icon = {
          string = icons.coffee.on,
          color = colors.yellow,
        },
      }
    else
      coffee:set {
        icon = {
          string = icons.coffee.off,
          color = colors.grey,
        },
      }
    end
  end)
end

coffee:subscribe({ "routine", "system_woke" }, update_coffee)

coffee:subscribe("mouse.clicked", function()
  sbar.exec("pgrep -x caffeinate", function(pid)
    if pid ~= "" then
      sbar.exec "killall caffeinate"
    else
      sbar.exec "caffeinate -d -i &"
    end
    sbar.delay(0.5, update_coffee)
  end)
end)

update_coffee()
