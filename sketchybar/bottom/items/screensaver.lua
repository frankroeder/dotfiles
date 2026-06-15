local colors = require "colors"
local icons = require "icons"
local settings = require "settings"
local ui = require "ui"

local saver = sbar.add("item", "widgets.screensaver", {
  position = "left",
  icon = {
    string = icons.saver,
    color = colors.sky,
    padding_left = 6,
    padding_right = 6,
    font = {
      family = "Hack Nerd Font",
      style = settings.font.style_map["Regular"],
      size = 18.0,
    },
  },
  label = { drawing = false },
  background = ui.capsule {},
})

saver:subscribe("mouse.clicked", function(env)
  if env.BUTTON == "right" then
    sbar.exec "pmset displaysleepnow"
  else
    sbar.exec "open -a ScreenSaverEngine"
  end
end)
