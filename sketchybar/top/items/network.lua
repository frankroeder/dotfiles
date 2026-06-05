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
    .. " network_update 2.0 >/dev/null 2>&1 &"
  sbar.exec(cmd)
end

local interface = utils.get_primary_interface()
start_provider(interface)

local rate_font = {
  family = settings.font.numbers,
  style = settings.font.style_map["Bold"],
  size = 10.0,
}

local RATE_LABEL_WIDTH = 58
local RATE_ICON_WIDTH = 14
local RATE_ITEM_WIDTH = RATE_ICON_WIDTH + RATE_LABEL_WIDTH + 8
local function rate_inactive(rate)
  return not rate or rate:match "^0+%s" ~= nil
end

local network_up = sbar.add("item", "widgets.network_up", {
  position = "right",
  width = RATE_ITEM_WIDTH,
  padding_left = 0,
  padding_right = 0,
  icon = {
    string = icons.wifi.upload .. " 000 KBps",
    drawing = true,
    font = rate_font,
    width = RATE_ITEM_WIDTH,
    align = "left",
    padding_left = 0,
    padding_right = 0,
    y_offset = 5,
    color = settings.theme.critical,
  },
  label = {
    font = rate_font,
    padding_left = -RATE_ITEM_WIDTH,
    padding_right = 0,
    align = "left",
    width = 0,
    string = icons.wifi.download .. " 000 KBps",
    color = settings.theme.accent,
    y_offset = -5,
  },
  background = { drawing = false },
})

network_up:subscribe("network_update", function(env)
  local up_color = rate_inactive(env.upload) and settings.theme.text_muted or settings.theme.critical
  local down_color = rate_inactive(env.download) and settings.theme.text_muted
    or settings.theme.accent
  network_up:set {
    icon = {
      string = icons.wifi.upload .. " " .. env.upload,
      color = up_color,
    },
    label = {
      string = icons.wifi.download .. " " .. env.download,
      color = down_color,
    },
  }
end)

network_up:subscribe({ "system_woke", "wifi_change" }, function()
  interface = utils.get_primary_interface()
  start_provider(interface)
end)
