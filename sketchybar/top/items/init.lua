local colors = require "colors"
local settings = require "settings"

require "items.yabai_spaces"

require "items.front_app"

require "items.calendar"
require "items.battery"
require "items.network"
require "items.wifi"
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
