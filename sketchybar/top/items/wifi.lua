local icons = require "icons"
local colors = require "colors"
local settings = require "settings"
local utils = require "utils"
local logic = require "logic"
local ui = require "ui"

sbar.add("event", "network_change", "com.apple.networkConnect")

local wifi = sbar.add("item", "widgets.wifi", {
  position = "right",
  background = { drawing = false },
  icon = {
    string = icons.wifi.disconnected,
    font = {
      style = settings.font.style_map["Bold"],
      size = 14.0,
    },
    color = colors.overlay0,
    padding_left = 8,
    padding_right = 4,
  },
  label = { drawing = false },
  updates = true,
  popup = { align = "left", background = ui.popup() },
})

local ssid = ui.popup_header("widgets.wifi.ssid", wifi, {
  icon = icons.wifi.router,
  label = "????????????",
  max_chars = 24,
})

local function update_wifi()
  local interface = utils.get_wifi_interface()
  sbar.exec("ifconfig " .. interface .. " 2>/dev/null | awk '/status:/ {print $2}'", function(status)
    local connected = logic.wifi_connected(status)
    wifi:set {
      icon = {
        string = connected and icons.wifi.connected or icons.wifi.disconnected,
        color = connected and colors.pink or colors.overlay0,
      },
    }
  end)
end

wifi:subscribe({ "forced", "wifi_change", "network_change", "deferred_wake", "routine", "system_woke" }, update_wifi)
update_wifi()

local function update_details()
  local interface = utils.get_wifi_interface()
  sbar.exec(
    [[
      en="$(networksetup -listallhardwareports | awk '/Wi-Fi|AirPort/{getline; print $NF}')";
      ipconfig getsummary "$en" | grep -Fxq "  Active : FALSE" || \
          networksetup -listpreferredwirelessnetworks "$en" | sed -n '2s/^\t//p'
    ]],
    function(result)
      ssid:set { label = result }
    end
  )
  sbar.exec("ipconfig getifaddr " .. interface .. " | tr -d '\\n'", function(result)
    ssid:set { icon = { string = (result ~= "" and result ~= nil) and icons.wifi.router or icons.wifi.disconnected } }
  end)
end

ui.bind_popup(wifi, { on_open = update_details })

wifi:subscribe("theme_colors_updated", function()
  update_wifi()
  ui.set_popup_bg(wifi)
end)
