local colors = require "colors"

require "items.yabai_spaces"

require "items.calendar"
require "items.battery"
require "items.wifi"
require "items.volume"
require "items.vpn"
require "items.bluetooth"

require "items.weather"
require "items.mode"
require "items.coffee"
require "items.mic"
require "items.brew"
require "items.front_app"

-- Grouping items into brackets
sbar.add("bracket", "top.group.connectivity", {
  "top.widgets.wifi",
  "top.widgets.vpn",
  "top.widgets.bluetooth"
}, {
  background = {
    color = colors.bg1,
    border_color = colors.bg2,
    border_width = 1,
  }
})

sbar.add("bracket", "top.group.system", {
  "top.widgets.volume",
  "top.widgets.battery",
  "widgets.mic"
}, {
  background = {
    color = colors.bg1,
    border_color = colors.bg2,
    border_width = 1,
  }
})

sbar.add("bracket", "top.group.tools", {
  "widgets.mode",
  "widgets.coffee",
  "widgets.brew",
}, {
  background = {
    color = colors.bg1,
    border_color = colors.bg2,
    border_width = 1,
  }
})

sbar.add("bracket", "top.group.time", {
  "top.widgets.calendar",
  "top.widgets.weather"
}, {
  background = {
    color = colors.bg1,
    border_color = colors.bg2,
    border_width = 1,
  }
})
