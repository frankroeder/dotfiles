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
    battery = {
      ["100"] = "􀛨",
      ["75"] = "􀺸",
      ["50"] = "􀺶",
      ["25"] = "􀛩",
      ["0"] = "􀛪",
      charging = "􀢋",
    },
    clock = "􀐫",
    date = "􀉉",
    brew = "􀐛",
    zen = "􀋲",
    coffee = {
      on = "􀐶",
      off = "􀐵",
    },
    volume = {
      [100] = "􀊩",
      [66] = "􀊧",
      [33] = "􀊥",
      [10] = "􀊡",
      [0] = "􀊣",
    },
    mic = {
      on = "􀊰",
      off = "􀊲",
    },
    reminder = "􀌂",
    weather = "􀇞",
    downloads = "􀈖",
    mode = {
      light = "􀆮",
      dark = "􀆺",
    },
    github = "􀉽",
    python = "􀏋",
    ssh = "􀀰",
    hackernews = "􀢞",
    arxiv = "􀫊",
    bluetooth = {
      on = "􀟥",
      off = "􀟛",
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
    battery = {
      ["100"] = "",
      ["75"] = "",
      ["50"] = "",
      ["25"] = "",
      ["0"] = "",
      charging = "",
    },
    volume = {
      [100] = "",
      [66] = "",
      [33] = "",
      [10] = "",
      [0] = "",
    },
    mic = {
      on = "",
      off = "",
    },
    reminder = "",
    clock = "",
    date = "󰃭",
    brew = "",
    zen = "",
    coffee = {
      on = "",
      off = "",
    },
    weather = "󰖐",
    downloads = "",
    mode = {
      light = "",
      dark = "",
    },
    github = "",
    python = "",
    ssh = "󰣀",
    hackernews = "",
    arxiv = "󰑔",
    bluetooth = {
      on = "󰂱",
      off = "󰂲",
    },
  },
}

if not (settings.icons == "NerdFont") then
  return icons.sf_symbols
else
  return icons.nerdfont
end
