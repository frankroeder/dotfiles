local colors = require "colors"
local settings = require "settings"

require "items.yabai_spaces"

require "items.calendar"
require "items.battery"
require "items.volume"
require "items.mic"
require "items.network"
require "items.wifi"
require "items.vpn"
require "items.bluetooth"

require "items.front_app"

require "items.mode"
require "items.coffee"

-- Grouping items into brackets
sbar.add("bracket", "top.group.network", {
  "widgets.wifi",
  "widgets.network_down",
  "widgets.network_up",
}, {
  background = {
    drawing = true,
    color = colors.bg,
    height = 34,
  },
})