local settings = require "settings"

local icons = {
  sf_symbols = {
    swap = "􁁀",
    mail = "􀍕",
    vpn = "􁅏",
    ram = "􀫦",
    plus = "􀅼",
    loading = "􀖇",
    apple = "􀣺",
    gear = "􀍟",
    cpu = "􀫥",
    clipboard = "􀉄",
    calendar = "􀧞",
    ip = "􀤆",
    wifi = {
      upload = "􀄨",
      download = "􀄩",
      connected = "􀙇",
      disconnected = "􀙈",
      router = "􁓤",
    },
    media = {
      back = "􀊊",
      forward = "􀊌",
      play_pause = "􀊈",
    },
    yabai = {
      float = "􀏜",
      stack = "􀢌",
      bsp = "􀏝",
    },
  },

  -- Alternative NerdFont icons
  nerdfont = {
    plus = "",
    loading = "",
    apple = "",
    gear = "",
    cpu = "",
    clipboard = "Missing Icon",
    calendar = "",
    swap = "󰍛",
    mail = "􀍕",
    vpn = "󰦝",
    ram = "",
    ip = "󰩟",
    wifi = {
      upload = "",
      download = "",
      connected = "󰖩",
      disconnected = "󰖪",
      router = "󰑩",
    },
    media = {
      back = "",
      forward = "",
      play_pause = "",
    },
  },
}

if not (settings.icons == "NerdFont") then
  return icons.sf_symbols
else
  return icons.nerdfont
end
