local icons = require "icons"
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

local rate_font = settings.font.numbers .. ":" .. settings.font.style_map["Bold"] .. ":11.0"

local function rate_inactive(rate)
  return not rate or rate:match "^0+%s" ~= nil
end

local network_up = sbar.add("item", "widgets.network_up", {
  position = "right",
  padding_left = 6,
  width = 0,
  icon = {
    font = rate_font,
    string = icons.wifi.upload,
    color = settings.theme.critical,
    width = 21,
    align = "left",
    padding_left = 2,
    padding_right = 2,
  },
  label = {
    font = rate_font,
    color = settings.theme.critical,
    string = "000 Bps",
    width = 58,
    align = "right",
  },
  y_offset = 6,
  background = { drawing = false },
})

local network_down = sbar.add("item", "widgets.network_down", {
  position = "right",
  padding_left = 6,
  padding_right = settings.paddings,
  width = 74,
  icon = {
    font = rate_font,
    string = icons.wifi.download,
    color = settings.theme.accent,
    width = 21,
    align = "left",
    padding_left = 2,
    padding_right = 2,
  },
  label = {
    font = rate_font,
    color = settings.theme.accent,
    string = "000 Bps",
    width = 58,
    align = "right",
  },
  y_offset = -6,
  background = { drawing = false },
})

local network_gap = sbar.add("item", "widgets.network_gap", {
  position = "right",
  width = 8,
  padding_left = 0,
  padding_right = 0,
  icon = { drawing = false },
  label = { drawing = false },
  background = { drawing = false },
})

network_up:subscribe("network_update", function(env)
  local up_color = rate_inactive(env.upload) and settings.theme.text_muted
    or settings.theme.critical
  local down_color = rate_inactive(env.download) and settings.theme.text_muted
    or settings.theme.accent
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

return {
  up = network_up,
  down = network_down,
  gap = network_gap,
}
