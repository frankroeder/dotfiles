local colors = require "colors"
local icons = require "icons"
local settings = require "settings"
local ui = require "ui"
local bridge = require "island_bridge"
local popup_row_height = settings.ui.popup_row_height

sbar.add("event", "bt_device", "com.apple.bluetooth.status")

-- Connected device names from last poll — new names toast on the island.
local last_connected = {}
local bt_primed = false
-- Skip popup rebuild when the device list has not changed (avoids open flicker).
local popup_fp = nil
local popup_items = {}
local empty_item = nil

local bluetooth = ui.add_capsule("widgets.bluetooth", {
  padding_left = 4,
  padding_right = 4,
  icon = {
    string = icons.bluetooth.on,
    color = colors.blue,
    width = 22,
    align = "center",
    padding_left = 8,
    padding_right = 8,
    font = {
      style = settings.font.style_map["Bold"],
      size = 18.0,
    },
  },
  label = { drawing = false },
  popup = { align = "right" },
})

local function ready()
  return bluetooth:query() ~= nil
end

local function clear_popup()
  for _, item in ipairs(popup_items) do
    sbar.remove(item.name)
  end
  popup_items = {}
  popup_fp = nil
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

local function set_bar(powered, count)
  if not powered then
    bluetooth:set { icon = { string = icons.bluetooth.off, color = colors.overlay0 } }
  elseif count > 0 then
    bluetooth:set { icon = { string = icons.bluetooth.on, color = colors.blue } }
  else
    bluetooth:set { icon = { string = icons.bluetooth.on, color = colors.subtext1 } }
  end
end

local function show_empty(text)
  if not empty_item then
    empty_item = ui.popup_button("widgets.bluetooth.empty", bluetooth, { label = text })
  end
  empty_item:set { drawing = true, label = { string = text } }
end

local function hide_empty()
  if empty_item then
    empty_item:set { drawing = false }
  end
end

-- Stable fingerprint so rebuild is skipped when nothing changed.
local function fingerprint(devices, powered)
  local parts = { powered and "1" or "0" }
  for _, d in ipairs(devices) do
    table.insert(parts, d.name .. "\0" .. (d.battery_short or "") .. "\0" .. (d.minor_type or ""))
  end
  return table.concat(parts, "\n")
end

local function rebuild_popup(devices, powered)
  local fp = fingerprint(devices, powered)
  -- Same list already drawn → keep existing items (no clear = no flicker).
  if fp == popup_fp then
    return
  end

  clear_popup()

  if not powered then
    show_empty "Bluetooth Off"
    popup_fp = fp
    return
  end
  if #devices == 0 then
    show_empty "No Devices Connected"
    popup_fp = fp
    return
  end

  hide_empty()
  for i, d in ipairs(devices) do
    local item = ui.popup_list_row("widgets.bluetooth.device." .. i, bluetooth, {
      label = d.display_label,
      font = {
        family = settings.font.family,
        style = settings.font.style_map["Regular"],
        size = 12.0,
      },
      icon = d.icon,
      icon_color = colors.subtext1,
      icon_font = { size = 16.0 },
      background = { height = popup_row_height },
    })
    table.insert(popup_items, item)
  end
  popup_fp = fp
end

-- Returns nil on system_profiler glitch (missing payload) vs {} for truly none.
local function parse_devices(data)
  local powered = true
  local devices = {}
  if type(data) ~= "table" or not data.SPBluetoothDataType then
    return nil, powered
  end

  for _, controller in pairs(data.SPBluetoothDataType) do
    local props = controller.controller_properties
    if props and props.controller_state == "attrib_off" then
      powered = false
    end
    if controller.device_connected then
      for _, device_entry in pairs(controller.device_connected) do
        for name, info in pairs(device_entry) do
          local battery_main = info.device_batteryLevelMain
          local battery_left = info.device_batteryLevelLeft
          local battery_right = info.device_batteryLevelRight
          local rssi = info.device_rssi
          local minor_type = info.device_minorType or "Unknown"
          local address = info.device_address or "??"
          local firmware = info.device_firmwareVersion

          local display_label = name
          local battery_short = nil
          local battery_info = ""
          if battery_left and battery_right then
            battery_info = string.format(" (L %s, R %s)", battery_left, battery_right)
            battery_short = string.format("%s/%s", battery_left, battery_right)
          elseif battery_main then
            battery_info = string.format(" (%s)", battery_main)
            battery_short = tostring(battery_main):gsub("%%", ""):gsub("%s", "") .. "%"
          elseif battery_left then
            battery_info = string.format(" (L %s)", battery_left)
            battery_short = tostring(battery_left)
          end
          display_label = display_label .. battery_info

          if rssi then
            display_label = display_label .. " (" .. rssi .. " dBm)"
          end
          display_label = display_label .. string.format(" - %s @%s", minor_type, address)
          if firmware then
            display_label = display_label .. ' Version: "' .. firmware .. '"'
          end

          table.insert(devices, {
            name = name,
            minor_type = minor_type,
            battery_short = battery_short,
            display_label = display_label,
            icon = get_device_icon(info.device_minorType),
          })
        end
      end
    end
  end
  return devices, powered
end

-- opts.toast_new: only true for bt_device events (not popup open / routine).
local function update(opts)
  opts = opts or {}
  sbar.exec("system_profiler SPBluetoothDataType -json", function(data)
    if not ready() then
      return
    end

    local devices, powered = parse_devices(data)
    if not devices then
      -- Transient system_profiler glitch: keep previous state (UI + membership)
      -- so we do not re-toast everyone on the next good poll.
      return
    end
    local connected_now = {}
    for _, d in ipairs(devices) do
      connected_now[d.name] = true
    end

    -- Island toast only on real connect events, never on popup open rebuild.
    if opts.toast_new and settings.island.bluetooth and bt_primed then
      for _, d in ipairs(devices) do
        if not last_connected[d.name] then
          bridge.trigger("island_bluetooth", {
            name = d.name,
            type = d.minor_type,
            battery = d.battery_short or "",
          })
        end
      end
    end

    last_connected = connected_now
    bt_primed = true

    set_bar(powered, #devices)
    rebuild_popup(devices, powered)
  end)
end

bluetooth:subscribe("bt_device", function()
  update { toast_new = true }
end)

-- Popup open: refresh data but do not toast; skip rebuild when fingerprint matches.
ui.bind_popup(bluetooth, {
  on_open = function()
    update { toast_new = false }
  end,
})

bluetooth:subscribe({ "forced", "routine", "deferred_wake" }, function()
  update { toast_new = false }
end)

bluetooth:subscribe("theme_colors_updated", function()
  if not ready() then
    return
  end
  bluetooth:set { background = ui.widget_background() }
  update { toast_new = false }
end)

-- Seed initial state on load (no toast).
update { toast_new = false }
