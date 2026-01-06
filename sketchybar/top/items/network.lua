local icons = require "icons"
local colors = require "colors"
local settings = require "settings"

sbar.exec "killall network_load >/dev/null; /Users/frankroeder/.dotfiles/sketchybar/helpers/event_providers/network_load/bin/network_load en0 network_update 2.0"

local network_up = sbar.add("item", "widgets.network_up", {
  position = "right",
  icon = {
    string = icons.wifi.upload,
    font = {
      size = 10.0,
    },
    highlight_color = colors.red,
  },
  label = {
    string = "",
    font = {
      size = 10.0,
    },
    padding_right = 8,
  },
  y_offset = 6,
  width = 0,
  updates = true,
  background = {
    drawing = false,
  },
})

local network_down = sbar.add("item", "widgets.network_down", {
  position = "right",
  icon = {
    string = icons.wifi.download,
    font = {
      size = 10.0,
    },
    highlight_color = colors.blue,
  },
  label = {
    string = "",
    font = {
      size = 10.0,
    },
    padding_right = 8,
  },
  y_offset = -6,
  updates = true,
  background = {
    drawing = false,
  },
})

network_up:subscribe("network_update", function(env)
  local down_highlight = (tonumber(env.downloadraw) > 0)
  local up_highlight = (tonumber(env.uploadraw) > 0)

  network_down:set {
    label = env.download,
    icon = {
      highlight = down_highlight,
    },
  }
  network_up:set {
    label = env.upload,
    icon = {
      highlight = up_highlight,
    },
  }
end)
