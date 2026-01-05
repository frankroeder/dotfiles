local colors = require("colors")
local icons = require("icons")
local settings = require("settings")

local wifi = sbar.add("item", "top.widgets.wifi", {
  position = "right",
  update_freq = 30,
  icon = {
    font = {
      style = "Regular",
      size = 16.0,
    },
  },
  label = {
    font = {
      style = settings.font.style_map["Bold"],
      size = 12.0,
    },
  },
})

local function update_network()
  sbar.exec("ipconfig getsummary en0", function(summary)
    local ssid = summary:match("SSID : ([^\n]+)")
    if ssid then
      wifi:set({
        icon = { string = icons.wifi.connected, color = colors.blue },
        label = { string = ssid, drawing = true }
      })
    else
      sbar.exec("ifconfig -u | grep -E 'inet ' | grep -v '127.0.0.1' | grep -v 'en0'", function(lan)
        if lan ~= "" then
          wifi:set({
            icon = { string = "􁓤", color = colors.green },
            label = { string = "LAN", drawing = true }
          })
        else
          wifi:set({
            icon = { string = icons.wifi.disconnected, color = colors.grey },
            label = { drawing = false }
          })
        end
      end)
    end
  end)
end
wifi:subscribe({"routine", "system_woke", "wifi_change"}, update_network)

wifi:subscribe("mouse.clicked", function()
  sbar.exec("open 'x-apple.systempreferences:com.apple.preference.network?id=wifi'")
end)

update_network()
