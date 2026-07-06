local icons = require "icons"
local island = require "island_core"
local island_style = require "island_style"
local settings = require "settings"

if not settings.island.wifi then
  return
end

local listener = sbar.add("item", "listener.wifi", {
  drawing = false,
  updates = true,
  update_freq = 0,
  icon = { drawing = false },
  label = { drawing = false },
  background = { drawing = false },
})

-- Same SSID lookup as the top-bar wifi popup (survives the macOS SSID redaction).
local SSID_CMD = [[
  en="$(networksetup -listallhardwareports | awk '/Wi-Fi|AirPort/{getline; print $NF}')";
  ipconfig getsummary "$en" | grep -Fxq "  Active : FALSE" || \
      networksetup -listpreferredwirelessnetworks "$en" | sed -n '2s/^\t//p'
]]

local last_state = nil

-- Prime at load so the first real change is announced (wifi_change has no
-- subscribe-time announcement to rely on, unlike volume_change).
sbar.exec(SSID_CMD, function(out)
  local ssid = (out or ""):gsub("%s+$", "")
  last_state = ssid ~= "" and ssid or "off"
end)

listener:subscribe("wifi_change", function()
  sbar.exec(SSID_CMD, function(out)
    local ssid = (out or ""):gsub("%s+$", "")
    local state = ssid ~= "" and ssid or "off"
    if last_state == nil or state == last_state then
      last_state = state
      return
    end
    last_state = state

    local connected = state ~= "off"
    local text = connected and (#ssid > 16 and (ssid:sub(1, 15) .. "…") or ssid) or "Wi-Fi off"

    island.expand {
      width = settings.island.widths.wifi,
      height = island.IDLE_H,
      duration = settings.island.wifi_duration,
      left = {
        text = text,
        font = { size = 15, style = "Semibold" },
        align = "left",
        color = connected and island_style.text() or island_style.warn(),
        padding_left = 16,
        padding_right = 4,
      },
      right = {
        text = connected and icons.wifi.connected or icons.wifi.disconnected,
        font = { size = 18, style = "Regular" },
        align = "center",
        width = 32,
        color = connected and island_style.success() or island_style.warn(),
        padding_left = 4,
        padding_right = 16,
      },
    }
  end)
end)
