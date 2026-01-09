local colors = require "colors"
local icons = require "icons"
local settings = require "settings"

local bluetooth = sbar.add("item", "top.widgets.bluetooth", {
  position = "right",
  update_freq = 30,
  icon = {
    string = icons.bluetooth.on,
    color = colors.blue,
    padding_left = 8,
    padding_right = 8,
    font = {
      style = "Regular",
      size = 16.0,
    },
  },
  label = {
    drawing = false,
  },
  popup = {
    align = "right",
  },
})

local popup_items = {}

local function clear_popup()
  for _, item in ipairs(popup_items) do
    sbar.remove(item.name)
  end
  popup_items = {}
end

local function get_device_icon(minor_type)
  if not minor_type then
    return "•"
  end
  local type = minor_type:lower()

  if type:find "head" or type:find "airpods" then
    return icons.device.headphone
  elseif type:find "speaker" then
    return icons.device.speaker
  elseif type:find "keyboard" then
    return icons.device.keyboard
  elseif type:find "mouse" or type:find "trackpad" then
    return icons.device.mouse
  end

  return "•"
end

local function update()
  sbar.exec("system_profiler SPBluetoothDataType -json", function(data)
    clear_popup()
    local count = 0

    if data and data.SPBluetoothDataType then
      for _, controller in pairs(data.SPBluetoothDataType) do
        if controller.device_connected then
          for _, device_entry in pairs(controller.device_connected) do
            for name, info in pairs(device_entry) do
              count = count + 1

              local battery_main = info.device_batteryLevelMain
              local battery_left = info.device_batteryLevelLeft
              local battery_right = info.device_batteryLevelRight
              local rssi = info.device_rssi
              local minor_type = info.device_minorType or "Unknown"
              local address = info.device_address or "??"
              local firmware = info.device_firmwareVersion

              -- Start with Name
              local display_label = name

              -- Battery Logic
              local battery_info = ""
              if battery_left and battery_right then
                battery_info = string.format(" (L %s, R %s)", battery_left, battery_right)
              elseif battery_main then
                battery_info = string.format(" (%s)", battery_main)
              elseif battery_left then
                battery_info = string.format(" (L %s)", battery_left)
              end
              display_label = display_label .. battery_info

              -- RSSI
              if rssi then
                display_label = display_label .. " (" .. rssi .. " dBm)"
              end

              -- Type and Address
              display_label = display_label .. string.format(" - %s @%s", minor_type, address)

              -- Firmware
              if firmware then
                display_label = display_label .. ' Version: "' .. firmware .. '"'
              end

              local icon = get_device_icon(info.device_minorType)

              local item = sbar.add("item", {
                position = "popup." .. bluetooth.name,
                label = {
                  string = display_label,
                  font = {
                    family = settings.font.text,
                    style = settings.font.style_map["Regular"],
                    size = 12.0,
                  },
                  padding_left = 8,
                  padding_right = 10,
                },
                icon = {
                  string = icon,
                  padding_left = 10,
                  padding_right = 4,
                  color = colors.white,
                  font = { size = 14.0 }, -- Larger for SF Symbols
                },
                background = {
                  height = 24,
                },
              })
              table.insert(popup_items, item)
            end
          end
        end
      end
    end

    if count == 0 then
      bluetooth:set { icon = { color = colors.grey } }
      local item = sbar.add("item", {
        position = "popup." .. bluetooth.name,
        label = {
          string = "No Devices Connected",
          padding_left = 10,
          padding_right = 10,
        },
        icon = { drawing = false },
      })
      table.insert(popup_items, item)
    else
      bluetooth:set { icon = { color = colors.blue } }
    end
  end)
end

bluetooth:subscribe({ "routine", "system_woke" }, update)

bluetooth:subscribe("mouse.clicked", function()
  bluetooth:set { popup = { drawing = "toggle" } }
end)

bluetooth:subscribe("mouse.exited.global", function()
  bluetooth:set { popup = { drawing = false } }
end)

update()
