require "items.media"

require "items.ram"
require "items.cpu"
require "items.swap"
require "items.ssd"
require "items.ip"

require "items.mails"
require "items.keyboard"
require "items.messages"
require "items.pomodoro"
-- sbar.add("alias", "Control Center,FocusModes", "left")
-- sbar.add("alias", "Proton VPN,Item-0", "left")
-- sbar.add("alias", "SystemUIServer,AppleVPNExtra", "left")
-- sbar.add("alias", "WeatherMenu,Item-0", "left")

local colors = require "colors"

sbar.add("bracket", "bottom.group.hw", {
  "widgets.ssd.volume",
  "widgets.cpu",
  "widgets.ram",
  "widgets.swap",
}, {
  background = {
    drawing = false,
  },
})

sbar.add("bracket", "bottom.group.utils", {
  "widgets.mail",
  "widgets.timer",
  "widgets.keyboard",
  "widgets.messages",
}, {
  background = {
    drawing = false,
  },
})
