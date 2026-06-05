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
local WIFI_SLOT_WIDTH = 28
local function rate_inactive(rate)
  return not rate or rate:match "^0+%s" ~= nil
end

local network_down
local last_download = "000 KBps"

local network_up = sbar.add("item", "widgets.network_up", {
  position = "right",
  width = RATE_ITEM_WIDTH,
  padding_left = 0,
  padding_right = 0,
  icon = {
    string = icons.wifi.upload,
    drawing = true,
    font = rate_font,
    width = RATE_ICON_WIDTH,
    align = "center",
    padding_left = 0,
    padding_right = 0,
  },
  label = {
    font = rate_font,
    padding_left = 2,
    padding_right = 6,
    align = "right",
    width = RATE_LABEL_WIDTH,
    string = "000 KBps",
    color = settings.theme.critical,
  },
  y_offset = 5,
  background = { drawing = false },
})

local function set_download(download)
  last_download = download or last_download
  if not network_down then
    return
  end

  local down_color = rate_inactive(last_download) and settings.theme.text_muted
    or settings.theme.accent
  network_down:set {
    icon = { color = down_color },
    label = {
      string = last_download,
      color = down_color,
    },
  }
end

local function add_download()
  if network_down then
    return network_down
  end

  network_down = sbar.add("item", "widgets.network_down", {
    position = "right",
    width = RATE_ITEM_WIDTH,
    padding_left = WIFI_SLOT_WIDTH,
    padding_right = -(RATE_ITEM_WIDTH + WIFI_SLOT_WIDTH),
    icon = {
      string = icons.wifi.download,
      drawing = true,
      font = rate_font,
      width = RATE_ICON_WIDTH,
      align = "center",
      padding_left = 0,
      padding_right = 0,
    },
    label = {
      font = rate_font,
      padding_left = 2,
      padding_right = 6,
      align = "right",
      width = RATE_LABEL_WIDTH,
      string = last_download,
      color = settings.theme.accent,
    },
    y_offset = -5,
    background = { drawing = false },
  })

  set_download(last_download)
  return network_down
end

network_up:subscribe("network_update", function(env)
  local up_color = rate_inactive(env.upload) and settings.theme.text_muted or settings.theme.critical
  network_up:set {
    icon = { color = up_color },
    label = {
      string = env.upload,
      color = up_color,
    },
  }
  set_download(env.download)
end)

network_up:subscribe({ "system_woke", "wifi_change" }, function()
  interface = utils.get_primary_interface()
  start_provider(interface)
end)

return {
  add_download = add_download,
}
