local colors = require "colors"
local settings = require "settings"

require "items.yabai_spaces"
-- Add padding between spaces and front app
sbar.add("item", {
  position = "left",
  width = 50,
  background = {
    drawing = false
  }
})
require "items.front_app"

require "items.calendar"
require "items.battery"
require "items.network"
require "items.wifi"
require "items.brew"
require "items.volume"
require "items.mic"
require "items.bluetooth"

sbar.add("bracket", "top.group.network", {
  "widgets.wifi",
  "widgets.network_down",
  "widgets.network_up",
}, {
  background = {
    drawing = true,
    color = colors.bg,
  },
})
