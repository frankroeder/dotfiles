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

-- require "items.weather"
-- require "items.mode"
-- require "items.coffee"
-- require "items.mic"
-- require "items.brew"
-- require "items.front_app"

-- Grouping items into brackets
sbar.add("bracket", "top.group.connectivity", {
  "top.widgets.vpn",
  "top.widgets.bluetooth",
}, {
  background = {
    drawing = true,
  },
})

sbar.add("bracket", "top.group.network", {
  "widgets.ip",
  "widgets.network_down",
  "widgets.network_up",
}, {
	-- TODO: add group padding --
	padding_left= 100,
	padding_right= 100,
  background = {
    drawing = true,
  },
})

sbar.add("bracket", "top.group.tools", {
  "widgets.mode",
  "widgets.coffee",
  "widgets.brew",
}, {
  background = {
    drawing = false,
  },
})
