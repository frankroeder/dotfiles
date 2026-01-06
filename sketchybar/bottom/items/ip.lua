local icons = require "icons"
local settings = require "settings"

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

local function network_update_ip()
  local ip_cmd = [[
    ipconfig getifaddr en0
  ]]
  sbar.exec(ip_cmd, function(output)
    if output ~= "" then
      ip_item:set { label = output, drawing = true }
    else
      ip_item:set { drawing = false }
    end
  end)
end

ip_item:subscribe("wifi_change", network_update_ip)
ip_item:subscribe("routine", network_update_ip)
network_update_ip()
