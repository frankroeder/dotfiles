local colors = require("colors")
local icons = require("icons")
local settings = require("settings")

local wifi = sbar.add("item", "top.widgets.wifi", {
  position = "right",
  update_freq = 60,
  icon = {
    string = icons.wifi.connected,
    color = colors.blue,
    padding_left = 8,
    font = {
      style = "Regular",
      size = 16.0,
    },
  },
  label = {
    string = "Wifi",
    font = {
      style = settings.font.style_map["Bold"],
      size = 14.0,
    },
    padding_right = 8,
    color = colors.white,
  },
})

wifi:subscribe({"routine", "system_woke", "wifi_change"}, function()
  sbar.exec("ipconfig getsummary en0 | awk -F ' SSID : '  '/ SSID : / {print $2}'", function(ssid)
    if ssid ~= "" then
      wifi:set({ label = { string = ssid } })
    else
      wifi:set({ label = { string = "Disconnected" } })
    end
  end)
end)

wifi:subscribe("mouse.clicked", function()
  sbar.exec("open 'x-apple.systempreferences:com.apple.preference.network?id=wifi'")
end)
