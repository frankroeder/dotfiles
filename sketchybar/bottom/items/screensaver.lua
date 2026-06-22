local colors = require "colors"
local icons = require "icons"
local settings = require "settings"
local ui = require "ui"

local saver = ui.add_capsule("widgets.screensaver", {
  position = "left",
  icon = {
    string = icons.saver,
    color = colors.sky,
    font = {
      family = settings.font.family,
      style = settings.font.style_map["Regular"],
      size = 18.0,
    },
  },
  label = { drawing = false },
})

saver:subscribe("mouse.clicked", function(env)
  if env.BUTTON == "right" then
    sbar.exec "pmset displaysleepnow"
  else
    sbar.exec "open -a ScreenSaverEngine"
  end
end)
