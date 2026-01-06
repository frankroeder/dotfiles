local icons = require "icons"
local colors = require "colors"
local settings = require "settings"

sbar.exec "killall network_load >/dev/null; /Users/frankroeder/.dotfiles/sketchybar/helpers/event_providers/network_load/bin/network_load en0 network_update 2.0"

local ip_item = sbar.add("item", "widgets.ip", {
  position = "right",
  update_freq = 180,
  icon = {
    string = icons.ip,
    padding_left = 8,
    font = {
      style = "Regular",
      size = 16.0,
    },
  },
  label = {
    padding_right = 8,
    string = "???.???.???.???",
    font = {
      style = settings.font.style_map["Bold"],
      size = 14.0,
    },
  },
  drawing = false,
  background = {
    drawing = true,
  },
})

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

local function network_update_ip()
  local ip_cmd = [[
    ipconfig getifaddr en0
  ]]
  sbar.exec(ip_cmd, function(output)
    if output ~= "" then
      sbar.animate("sin", settings.animation_duration, function()
        ip_item:set { label = output, drawing = true }
      end)
    else
      ip_item:set { drawing = false }
    end
  end)
end

network_up:subscribe("routine", network_update_ip)
network_update_ip()
