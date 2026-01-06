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
})

local bluetooth_popup = sbar.add("item", {
  position = "popup." .. bluetooth.name,
  label = {
    string = "Checking...",
    font = {
      family = settings.font.numbers,
      style = settings.font.style_map["Bold"],
      size = 12.0,
    },
    padding_left = 10,
    padding_right = 10,
  },
  background = {
    drawing = true,
    corner_radius = 5,
    border_width = 1,
    border_color = colors.bg2,
  }
})

local popup_info = "No Devices"

local function format_device_stats(stats)
  local parts = {}
  if stats.left then table.insert(parts, "L:" .. stats.left .. "%") end
  if stats.right then table.insert(parts, "R:" .. stats.right .. "%") end
  if stats.case then table.insert(parts, "C:" .. stats.case .. "%") end
  if stats.main then table.insert(parts, stats.main .. "%") end
  return table.concat(parts, " ")
end

local function update()
  sbar.exec("system_profiler SPBluetoothDataType", function(info)
    -- 1. Update Icon State
    local powered_on = info:match("State: On") or info:match("Bluetooth Power: On")
    
    local icon = icons.bluetooth.off
    local color = colors.grey
    
    if powered_on then
      icon = icons.bluetooth.on
      color = colors.blue
    end

    bluetooth:set {
      icon = { string = icon, color = color },
    }

    -- 2. Parse Connected Devices
    local connected_start = info:find("%sConnected:\n")
    local not_connected_start = info:find("%sNot Connected:\n")
    
    local connected_block = nil
    if connected_start then
        if not_connected_start and not_connected_start > connected_start then
            connected_block = info:sub(connected_start, not_connected_start - 1)
        else
            -- "Not Connected" section might be missing or before (unlikely)
            connected_block = info:sub(connected_start)
        end
    end

    local device_lines = {}
    
    if connected_block then
      local current_device = nil
      local current_stats = {}

      for line in connected_block:gmatch("[^\r\n]+") do
        -- Skip the "Connected:" header line itself
        if not line:match("^%s*Connected:$") and line:match("%S") then
            -- Identify device name
            local device_name = line:match("^%s+([^:]+):$")

            if device_name then
                -- Save previous device
                if current_device then
                    local stats_str = format_device_stats(current_stats)
                    if stats_str ~= "" then
                        table.insert(device_lines, current_device .. " " .. stats_str)
                    else
                        table.insert(device_lines, current_device)
                    end
                end
                
                current_device = device_name
                current_stats = {}
            else
                -- It's a property line
                if current_device then
                    local l = line:match("Left Battery Level:%s*(%d+)")
                    if l then current_stats.left = l end
                    
                    local r = line:match("Right Battery Level:%s*(%d+)")
                    if r then current_stats.right = r end
                    
                    local c = line:match("Case Battery Level:%s*(%d+)")
                    if c then current_stats.case = c end
                    
                    local m = line:match("Battery Level:%s*(%d+)")
                    if m then current_stats.main = m end
                end
            end
        end
      end
      
      -- Push last device
      if current_device then
        local stats_str = format_device_stats(current_stats)
        if stats_str ~= "" then
          table.insert(device_lines, current_device .. " " .. stats_str)
        else
          table.insert(device_lines, current_device)
        end
      end
    end

    if #device_lines > 0 then
      popup_info = table.concat(device_lines, "\n")
    else
      popup_info = "No Devices Connected"
    end
    
    bluetooth_popup:set { label = { string = popup_info } }
  end)
end

bluetooth:subscribe({ "routine", "system_woke" }, update)

bluetooth:subscribe("mouse.clicked", function()
  bluetooth_popup:set { label = { string = popup_info } }
  bluetooth:set { popup = { drawing = "toggle" } }
end)

bluetooth:subscribe("mouse.exited.global", function()
  bluetooth:set { popup = { drawing = false } }
end)

update()
