local colors = require("colors")
local icons = require("icons")
local settings = require("settings")

local bluetooth = sbar.add("item", "top.widgets.bluetooth", {
  position = "right",
  update_freq = 60,
  icon = {
    string = icons.bluetooth.on,
    color = colors.blue,
    padding_left = 8,
    font = {
      style = "Regular",
      size = 16.0,
    },
  },
  label = {
    string = "...",
    font = {
      style = settings.font.style_map["Bold"],
      size = 14.0,
    },
    padding_right = 8,
    color = colors.white,
  },
})

local bluetooth_popup = sbar.add("item", {
  position = "popup." .. bluetooth.name,
  label = {
    font = { size = 12.0 },
    max_chars = 40,
    string = "Checking..."
  },
})

bluetooth:subscribe({"routine", "system_woke"}, function()
  sbar.exec([[system_profiler SPBluetoothDataType | grep -E "Connected: Yes" -B 10 | grep -E "^[ ]{8}[^:]+" | sed 's/^[ ]*//' | sed 's/:$//' | wc -l | tr -d ' ']], function(count)
    local dev_count = tonumber(count) or 0
    local icon = icons.bluetooth.off
    local color = colors.grey
    local label = ""

    if dev_count > 0 then
      icon = icons.bluetooth.on
      color = colors.blue
      label = tostring(dev_count)
    end

    bluetooth:set({
      icon = { string = icon, color = color },
      label = { string = label, drawing = (dev_count > 0) }
    })
  end)
end)

bluetooth:subscribe("mouse.clicked", function()
  bluetooth:set({ popup = { drawing = "toggle" } })
  sbar.exec([[system_profiler SPBluetoothDataType | grep -E "Connected: Yes" -B 10 | grep -E "^[ ]{8}[^:]+" | sed 's/^[ ]*//' | sed 's/:$//']], function(devices)
    if devices == "" then devices = "No devices connected" end
    bluetooth_popup:set({ label = { string = devices } })
  end)
end)

bluetooth:subscribe("mouse.exited.global", function()
  bluetooth:set({ popup = { drawing = false } })
end)