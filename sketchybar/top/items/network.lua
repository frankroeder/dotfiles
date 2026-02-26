local icons = require "icons"
local colors = require "colors"
local settings = require "settings"
local utils = require "utils"

local function start_provider(interface)
  if not interface or interface == "" then
    return
  end
  local cmd = "killall network_load >/dev/null 2>&1; "
    .. settings.network.provider_path
    .. " "
    .. interface
    .. " network_update 2.0"
  sbar.exec(cmd)
end

local interface = utils.get_primary_interface()
start_provider(interface)

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
    color = settings.theme.critical,
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
    color = settings.theme.accent,
  },
  y_offset = -5,
  background = { drawing = false },
})

network_up:subscribe("network_update", function(env)
  local up_color = (env.upload == "000 Bps") and settings.theme.text_muted or settings.theme.critical
  local down_color = (env.download == "000 Bps") and settings.theme.text_muted or settings.theme.accent
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

network_up:subscribe({ "system_woke", "wifi_change" }, function()
  interface = utils.get_primary_interface()
  start_provider(interface)
end)
