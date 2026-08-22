local colors = require "colors"
local icons = require "icons"
local settings = require "settings"
local ui = require "ui"
local utils = require "utils"
local bridge = require "island_bridge"
local popup_row_height = settings.ui.popup_row_height
local bt_helper = os.getenv "HOME" .. "/.dotfiles/sketchybar/helpers/bt"
local popup_width = 280
local row_width = popup_width / 2
local BU = "/opt/homebrew/bin/blueutil"

sbar.add("event", "bt_device", "com.apple.bluetooth.status")
sbar.add("event", "bt_refresh")
sbar.add("event", "bt_power_toggle")

-- Connected keys from last poll — new ones toast on the island.
local last_connected = {}
local bt_primed = false
local popup_fp = nil
local popup_items = {}
local power_btn = nil
local idle_item = nil
local inflight = false
local pending_opts = nil
local update

local bluetooth = ui.add_capsule("widgets.bluetooth", {
  padding_left = 2,
  padding_right = 2,
  icon = {
    string = icons.bluetooth.on,
    color = colors.blue,
    width = 22,
    align = "center",
    padding_left = 4,
    padding_right = 4,
    font = {
      style = settings.font.style_map["Bold"],
      size = 16.0,
    },
  },
  label = {
    drawing = false,
    string = "",
    font = {
      style = settings.font.style_map["Semibold"],
      size = 12.0,
    },
    color = colors.blue,
    padding_right = 6,
  },
  popup = { align = "right", background = ui.popup() },
})

local function ready()
  return bluetooth:query() ~= nil
end

local function clear_rows()
  for _, item in ipairs(popup_items) do
    sbar.remove(item.name)
  end
  popup_items = {}
end

local function norm_addr(addr)
  return (addr or ""):lower():gsub("[:-]", "")
end

local function device_kind(minor_type, name)
  local t = (minor_type or ""):lower()
  if t:find "head" or t:find "airpods" then
    return "headphone"
  elseif t:find "speaker" then
    return "speaker"
  elseif t:find "keyboard" then
    return "keyboard"
  elseif t:find "mouse" or t:find "trackpad" then
    return "mouse"
  end

  local n = (name or ""):lower()
  if
    n:find "airpods"
    or n:find "headphone"
    or n:find "headset"
    or n:find "wh%-"
    or n:find "xm%d"
    or n:find "momentum"
    or n:find "buds"
    or n:find "beats"
  then
    return "headphone"
  elseif
    n:find "speaker"
    or n:find "soundlink"
    or n:find "homepod"
    or n:find "jbl"
    or n:find "flip"
    or n:find "receiver"
  then
    return "speaker"
  elseif n:find "keyboard" or n:find "keychron" then
    return "keyboard"
  elseif n:find "mouse" or n:find "trackpad" or n:find "magic track" then
    return "mouse"
  end
  return nil
end

local function get_device_icon(kind)
  if kind == "headphone" then
    return icons.device.headphone
  elseif kind == "speaker" then
    return icons.device.speaker
  elseif kind == "keyboard" then
    return icons.device.keyboard
  elseif kind == "mouse" then
    return icons.device.mouse
  end
  return icons.bluetooth.on
end

-- Human signal label from RSSI (dBm). Golden range ≈ 0; unreadable ≈ -129/127.
local function signal_label(rssi)
  if rssi == nil then
    return nil
  end
  local n = tonumber(rssi)
  if not n or n == 127 or n <= -129 then
    return nil
  end
  local qual
  if n >= -50 then
    qual = "Excellent"
  elseif n >= -60 then
    qual = "Good"
  elseif n >= -70 then
    qual = "Fair"
  else
    qual = "Weak"
  end
  return string.format("%s (%d dBm)", qual, n)
end

-- Extract A2DP/HFP/… tokens from system_profiler services string.
local function services_short(raw)
  if not raw or raw == "" then
    return nil
  end
  local tags = {}
  for _, key in ipairs { "A2DP", "HFP", "AVRCP", "HID", "GATT", "LEA", "ACL" } do
    if raw:find(key, 1, true) then
      table.insert(tags, key)
    end
  end
  if #tags == 0 then
    return nil
  end
  return table.concat(tags, " · ")
end

local function set_bar(powered, count)
  if not powered then
    bluetooth:set {
      icon = { string = icons.bluetooth.off, color = colors.overlay0 },
      label = { drawing = false },
    }
  elseif count > 0 then
    bluetooth:set {
      icon = { string = icons.bluetooth.on, color = colors.blue },
      label = {
        drawing = true,
        string = tostring(count),
        color = colors.blue,
      },
    }
  else
    bluetooth:set {
      icon = { string = icons.bluetooth.on, color = colors.subtext1 },
      label = { drawing = false },
    }
  end
end

local function ensure_chrome()
  if not power_btn then
    power_btn = sbar.add("item", "widgets.bluetooth.power", {
      position = "popup." .. bluetooth.name,
      width = popup_width,
      icon = {
        string = icons.bluetooth.on,
        color = colors.blue,
        font = { size = 15.0 },
        padding_left = 10,
        padding_right = 6,
      },
      label = {
        string = "Bluetooth · …",
        font = {
          family = settings.font.family,
          style = settings.font.style_map["Semibold"],
          size = 12.0,
        },
        color = colors.text,
        padding_right = 10,
      },
      background = ui.button { height = popup_row_height + 4 },
      click_script = utils.shell_quote(bt_helper) .. " toggle",
    })
  end
  if not idle_item then
    idle_item = sbar.add("item", "widgets.bluetooth.idle", {
      position = "popup." .. bluetooth.name,
      width = popup_width,
      drawing = false,
      icon = { drawing = false },
      label = {
        string = "No devices",
        font = {
          family = settings.font.family,
          style = settings.font.style_map["Regular"],
          size = 12.0,
        },
        color = colors.subtext1,
        padding_left = 12,
        padding_right = 12,
      },
      background = { drawing = false },
    })
  end
end

local function set_power_row(powered)
  ensure_chrome()
  power_btn:set {
    drawing = true,
    icon = {
      string = powered and icons.bluetooth.on or icons.bluetooth.off,
      color = powered and colors.blue or colors.overlay0,
    },
    label = {
      string = powered and "Bluetooth · On" or "Bluetooth · Off",
      color = powered and colors.text or colors.subtext1,
    },
  }
end

local function add_detail(name, title, value)
  local item = ui.popup_field(name, bluetooth, {
    icon = title,
    icon_width = row_width,
    icon_color = settings.theme.text_muted,
    label = value,
    label_color = settings.theme.text_primary,
    label_width = row_width,
    label_align = "right",
    max_chars = 22,
    height = popup_row_height,
  })
  table.insert(popup_items, item)
  return item
end

local function fingerprint(devices, powered)
  local parts = { powered and "1" or "0" }
  for _, d in ipairs(devices) do
    table.insert(
      parts,
      table.concat({
        d.address or "",
        d.name or "",
        d.battery_short or "",
        d.rssi or "",
        d.minor_type or "",
        d.firmware or "",
        d.services or "",
      }, "\0")
    )
  end
  return table.concat(parts, "\n")
end

local function rebuild_popup(devices, powered)
  local fp = fingerprint(devices, powered)
  if fp == popup_fp then
    return
  end

  clear_rows()
  set_power_row(powered)

  if not powered then
    idle_item:set { drawing = false }
    popup_fp = fp
    return
  end

  if #devices == 0 then
    idle_item:set { drawing = true, label = { string = "No devices" } }
    popup_fp = fp
    return
  end

  idle_item:set { drawing = false }

  for i, d in ipairs(devices) do
    local id = (d.address ~= "" and d.address) or d.name
    local prefix = "widgets.bluetooth.d" .. i

    -- Device header: glyph + name · battery. Click disconnects.
    local header_label = d.name
    if d.battery_short then
      header_label = d.name .. " · " .. d.battery_short
    end
    local header = sbar.add("item", prefix .. ".name", {
      position = "popup." .. bluetooth.name,
      width = popup_width,
      icon = {
        string = d.icon,
        color = colors.blue,
        font = { size = 15.0 },
        padding_left = 10,
        padding_right = 6,
      },
      label = {
        string = header_label,
        font = {
          family = settings.font.family,
          style = settings.font.style_map["Semibold"],
          size = 13.0,
        },
        color = colors.text,
        max_chars = 28,
        padding_right = 10,
      },
      background = {
        height = 2,
        color = settings.theme.border,
        y_offset = -12,
        drawing = true,
      },
      click_script = utils.shell_quote(bt_helper) .. " disconnect " .. utils.shell_quote(id),
    })
    table.insert(popup_items, header)

    if d.minor_type and d.minor_type ~= "" then
      add_detail(prefix .. ".type", "Type:", d.minor_type)
    end
    if d.battery_detail then
      add_detail(prefix .. ".batt", "Battery:", d.battery_detail)
    end
    local sig = signal_label(d.rssi)
    if sig then
      add_detail(prefix .. ".rssi", "Signal:", sig)
    end
    if d.services then
      add_detail(prefix .. ".svc", "Services:", d.services)
    end
    if d.firmware and d.firmware ~= "" then
      add_detail(prefix .. ".fw", "Firmware:", d.firmware)
    end
    if d.address and d.address ~= "" then
      add_detail(prefix .. ".addr", "Address:", d.address)
    end
  end
  popup_fp = fp
end

local function parse_device_entry(name, info)
  local battery_main = info.device_batteryLevelMain
  local battery_left = info.device_batteryLevelLeft
  local battery_right = info.device_batteryLevelRight
  local battery_case = info.device_batteryLevelCase
  local minor_type = info.device_minorType
  local address = info.device_address or ""
  local firmware = info.device_firmwareVersion
  local rssi = info.device_rssi

  local battery_short = nil
  local battery_detail = nil
  if battery_left and battery_right then
    battery_short = string.format("%s/%s", battery_left, battery_right)
    battery_detail = string.format("L %s · R %s", battery_left, battery_right)
    if battery_case then
      battery_detail = battery_detail .. " · Case " .. tostring(battery_case)
    end
  elseif battery_main then
    local pct = tostring(battery_main):gsub("%%", ""):gsub("%s", "")
    battery_short = pct .. "%"
    battery_detail = battery_short
  elseif battery_left then
    battery_short = tostring(battery_left)
    battery_detail = "L " .. battery_short
  end

  local kind = device_kind(minor_type, name)
  return {
    name = name,
    address = address,
    kind = kind,
    minor_type = minor_type or "",
    battery_short = battery_short,
    battery_detail = battery_detail,
    firmware = firmware and tostring(firmware) or nil,
    rssi = rssi and tostring(rssi) or nil,
    services = services_short(info.device_services),
    icon = get_device_icon(kind),
  }
end

-- Connected devices from system_profiler. RSSI often missing → filled from blueutil.
local function parse_connected(data)
  local devices = {}
  if type(data) ~= "table" or not data.SPBluetoothDataType then
    return nil
  end
  for _, controller in pairs(data.SPBluetoothDataType) do
    if controller.device_connected then
      for _, device_entry in pairs(controller.device_connected) do
        for name, info in pairs(device_entry) do
          if type(info) == "table" then
            table.insert(devices, parse_device_entry(name, info))
          end
        end
      end
    end
  end
  table.sort(devices, function(a, b)
    return (a.name or "") < (b.name or "")
  end)
  return devices
end

-- Merge blueutil --connected RSSI (and address fallback) into profiler devices.
local function merge_blueutil(devices, bu)
  if type(bu) ~= "table" then
    return devices
  end
  local by_addr, by_name = {}, {}
  for _, raw in ipairs(bu) do
    if type(raw) == "table" then
      local key = norm_addr(raw.address)
      if key ~= "" then
        by_addr[key] = raw
      end
      if type(raw.name) == "string" and raw.name ~= "" then
        by_name[raw.name] = raw
      end
    end
  end
  for _, d in ipairs(devices) do
    local raw = by_addr[norm_addr(d.address)] or by_name[d.name]
    if raw then
      if (not d.rssi or d.rssi == "") and raw.RSSI ~= nil and raw.RSSI ~= 127 then
        d.rssi = tostring(raw.RSSI)
      end
      if (not d.address or d.address == "") and raw.address then
        d.address = tostring(raw.address):gsub("-", ":"):upper()
      end
    end
  end
  return devices
end

local function finish(powered, devices, opts)
  if not ready() then
    return
  end
  devices = devices or {}

  local connected_now = {}
  for _, d in ipairs(devices) do
    local key = d.address ~= "" and d.address or d.name
    connected_now[key] = d
  end

  if opts.toast_new and bt_primed then
    for key, d in pairs(connected_now) do
      if not last_connected[key] then
        bridge.trigger("island_bluetooth", {
          name = d.name,
          type = d.kind or d.minor_type or "",
          battery = d.battery_short or "",
          rssi = d.rssi or "",
        })
      end
    end
  end

  last_connected = connected_now
  bt_primed = true

  set_bar(powered, #devices)
  rebuild_popup(devices, powered)
end

local function done_inflight()
  inflight = false
  if pending_opts then
    local next_opts = pending_opts
    pending_opts = nil
    update(next_opts)
  end
end

-- Power via blueutil. Devices via system_profiler + blueutil RSSI merge.
update = function(opts)
  opts = opts or {}
  if inflight then
    if pending_opts then
      pending_opts.toast_new = pending_opts.toast_new or opts.toast_new
    else
      pending_opts = opts
    end
    return
  end
  inflight = true

  sbar.exec(BU .. " -p", function(raw)
    local powered = tostring(raw or ""):match "1" ~= nil
    if not powered then
      finish(false, {}, opts)
      done_inflight()
      return
    end
    sbar.exec("system_profiler SPBluetoothDataType -json", function(data)
      local devices = parse_connected(data) or {}
      sbar.exec(BU .. " --connected --format json", function(bu)
        finish(true, merge_blueutil(devices, bu), opts)
        done_inflight()
      end)
    end)
  end)
end

bluetooth:subscribe("bt_device", function()
  update { toast_new = true }
end)

bluetooth:subscribe("bt_refresh", function()
  popup_fp = nil
  update { toast_new = false }
end)

-- Vicinae (and other GUI launchers) have no Bluetooth TCC; blueutil aborts there.
-- Run the helper as sketchybar's child so IOBluetooth is allowed.
bluetooth:subscribe("bt_power_toggle", function()
  sbar.exec(utils.shell_quote(bt_helper) .. " toggle")
end)

ui.bind_popup(bluetooth, {
  on_open = function()
    update { toast_new = false }
  end,
  on_right = 'open "x-apple.systempreferences:com.apple.BluetoothSettings" 2>/dev/null || open /System/Library/PreferencePanes/Bluetooth.prefPane',
})

bluetooth:subscribe({ "forced", "routine", "deferred_wake" }, function()
  update { toast_new = false }
end)

bluetooth:subscribe("theme_colors_updated", function()
  if not ready() then
    return
  end
  bluetooth:set { background = ui.capsule() }
  ui.set_popup_bg(bluetooth)
  if power_btn then
    power_btn:set { background = ui.button { height = popup_row_height + 4 } }
  end
  popup_fp = nil
  update { toast_new = false }
end)

update { toast_new = false }
