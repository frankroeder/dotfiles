require "items.media"

require "items.ssd"
require "items.cpu"
require "items.ram"
require "items.swap"

require "items.network"
require "items.mails"
require "items.pomodoro"

local colors = require "colors"

sbar.add("bracket", "bottom.group.hw", {
  "widgets.ssd.volume",
  "widgets.cpu",
  "widgets.ram",
  "widgets.swap"
}, {
  background = {
    color = colors.bg1,
    border_color = colors.bg2,
    border_width = 1,
  }
})

sbar.add("bracket", "bottom.group.network", {
  "widgets.ip",
  "widgets.network_down",
  "widgets.network_up"
}, {
  background = {
    color = colors.bg1,
    border_color = colors.bg2,
    border_width = 1,
  }
})

sbar.add("bracket", "bottom.group.utils", {
  "widgets.mail",
  "widgets.timer"
}, {
  background = {
    color = colors.bg1,
    border_color = colors.bg2,
    border_width = 1,
  }
})