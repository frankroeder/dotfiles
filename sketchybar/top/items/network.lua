local icons = require "icons"
local colors = require "colors"
local settings = require "settings"
local utils = require "utils"

local interface = utils.get_primary_interface()

sbar.exec(
  "killall network_load >/dev/null; "
    .. os.getenv "HOME"
    .. "/.dotfiles/sketchybar/helpers/event_providers/network_load/bin/network_load "
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
  padding_left = 0,
  padding_right = 0,
  icon = { drawing = false },
  label = {
    font = rate_font,
    padding_left = 2,
    padding_right = 6,
    align = "right",
    string = "0 B/s",
    color = colors.red,
  },
  y_offset = 5,
  background = { drawing = false },
})

local network_down = sbar.add("item", "widgets.network_down", {
  position = "right",
  padding_left = 0,
  padding_right = 0,
  icon = { drawing = false },
  label = {
    font = rate_font,
    width = rate_label_width,
    padding_left = 2,
    padding_right = 6,
    align = "right",
    string = "0 B/s",
    color = colors.blue,
  },
  y_offset = -5,
  background = { drawing = false },
})

local function convert_rate(rate)
  local formatted = rate or "0 Bps"
  -- Convert Bps to KB/s if needed
  if formatted:match " Bps$" then
    local value = tonumber(formatted:match "^%d+")
    if value then
      if value < 1000 then
        formatted = value .. " B/s"
      else
        formatted = string.format("%d KB/s", math.floor(value / 1000))
      end
    end
  end
  return formatted:gsub("Bps$", "B/s"):gsub("ps$", "/s")
end

network_up:subscribe("network_update", function(env)
  local up = convert_rate(env.upload)
  local up_color = (env.upload == "000 Bps" or up == "0 B/s") and colors.grey or colors.red
  network_up:set {
    label = {
      string = icons.wifi.upload .. " " .. up,
      color = up_color,
    },
  }
end)

network_down:subscribe("network_update", function(env)
  local down = convert_rate(env.download)
  local down_color = (env.download == "000 Bps" or down == "0 B/s") and colors.grey or colors.blue
  network_down:set {
    label = {
      string = icons.wifi.download .. " " .. down,
      color = down_color,
    },
  }
end)
