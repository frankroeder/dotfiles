require "lock"
require "items.media"

require "items.hardware"
require "items.ssd"

require "items.mails"
require "items.keyboard"
require "items.pomodoro"

-- New items moved from top bar
require "items.mode"
require "items.coffee"
require "items.vpn"

-- sbar.add("alias", "Control Center,FocusModes", "left")
-- sbar.add("alias", "Proton VPN,Item-0", "left")
-- sbar.add("alias", "SystemUIServer,AppleVPNExtra", "left")
-- sbar.add("alias", "WeatherMenu,Item-0", "left")

sbar.add("bracket", "bottom.group.utils", {
  "widgets.mail",
  "widgets.timer",
  "widgets.keyboard",
}, {
  background = {
    drawing = false,
  },
})
