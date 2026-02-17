local icons = require "icons"
local colors = require "colors"
local settings = require "settings"
local utils = require "utils"

local interface = utils.get_primary_interface()

sbar.exec(
  "killall network_load >/dev/null; "
    .. settings.network.provider_path
    .. " "
    .. interface
    .. " network_update 2.0"
)

local rate_font = {
  family = settings.font.numbers,
  style = settings.font.style_map["Bold"],
  size = 10.0,
}

local network_up = sbar.add("item", "widgets.network_up", {
  position = "right",
  width = 0,
  padding_left = 2,
  padding_right = 0,
  icon = {
    string = icons.wifi.upload,
    drawing = true,
    font = rate_font,
  },
  label = {
    font = rate_font,
    padding_left = 2,
    padding_right = 6,
    align = "right",
    string = "??? Bps",
    color = colors.red,
  },
  y_offset = 5,
  background = { drawing = false },
})

local network_down = sbar.add("item", "widgets.network_down", {
  position = "right",
  padding_left = 0,
  padding_right = 0,
  icon = {
    string = icons.wifi.download,
    drawing = true,
    font = rate_font,
  },
  label = {
    font = rate_font,
    padding_left = 2,
    padding_right = 6,
    align = "right",
    string = "??? Bps",
    color = colors.blue,
  },
  y_offset = -5,
  background = { drawing = false },
})

network_up:subscribe("network_update", function(env)
  local up_color = (env.upload == "000 Bps") and colors.grey or colors.red
  local down_color = (env.download == "000 Bps") and colors.grey or colors.blue
  network_up:set {
    icon = { color = up_color },
    label = {
      string = env.upload,
      color = up_color,
    },
  }
  network_down:set {
    icon = { color = down_color },
    label = {
      string = env.download,
      color = down_color,
    },
  }
end)

network_up:subscribe("system_woke", function()
  interface = utils.get_primary_interface()
end)
