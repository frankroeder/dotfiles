local colors = require "colors"
local settings = require "settings"

require "items.yabai_spaces"

require "items.calendar"
require "items.battery"
require "items.volume"
require "items.network"
require "items.wifi"
require "items.vpn"
require "items.bluetooth"

require "items.front_app"

require "items.weather"
require "items.mode"
require "items.coffee"
require "items.mic"
require "items.brew"

-- Grouping items into brackets
sbar.add("bracket", "top.group.connectivity", {
  "top.widgets.vpn",
  "top.widgets.bluetooth",
}, {
  background = {
    drawing = true,
    color = colors.purple,
    height = 34,
  },
})

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

sbar.add("bracket", "top.group.tools", {
  "widgets.mode",
  "widgets.coffee",
  "widgets.brew",
}, {
  background = {
    drawing = true,
    color = colors.purple,
    height = 34,
  },
})
