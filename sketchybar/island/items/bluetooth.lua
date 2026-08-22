local icons = require "icons"
local island = require "island_core"
local island_style = require "island_style"
local settings = require "settings"
local utils = require "utils"

local listener = sbar.add("item", "listener.bluetooth", {
  drawing = false,
  updates = true,
  update_freq = 0,
  icon = { drawing = false },
  label = { drawing = false },
  background = { drawing = false },
})

-- blueutil has no device class — same name heuristics as top bar.
local function device_kind(name, dtype)
  local t = (dtype or ""):lower()
  if t:find "head" or t:find "airpods" or t == "headphone" then
    return "headphone"
  elseif t:find "keyboard" or t == "keyboard" then
    return "keyboard"
  elseif t:find "mouse" or t:find "trackpad" or t == "mouse" then
    return "mouse"
  elseif t:find "speaker" or t == "speaker" then
    return "speaker"
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

local function glyph_for(kind)
  if kind == "headphone" then
    return icons.device.headphone
  elseif kind == "keyboard" then
    return icons.device.keyboard
  elseif kind == "mouse" then
    return icons.device.mouse
  elseif kind == "speaker" then
    return icons.device.speaker
  end
  return icons.bluetooth.on
end

listener:subscribe("island_bluetooth", function(env)
  local name = env.name or env.INFO or ""
  if name == "" then
    return
  end
  -- Keep name + detail inside the left lobe (hugs the notch's left edge).
  local short = utils.ellipsize(name, 9)
  local battery = env.battery
  local rssi = env.rssi
  local text = short
  if battery and battery ~= "" then
    text = short .. " · " .. battery
  elseif rssi and rssi ~= "" then
    text = short .. " · " .. rssi .. " dBm"
  end

  local kind = device_kind(name, env.type)
  local glyph = glyph_for(kind)

  island.expand {
    kind = "bluetooth",
    priority = island.priority.bluetooth,
    width = settings.island.widths.bluetooth,
    height = island.IDLE_H,
    duration = settings.island.bluetooth_duration,
    left = {
      text = text,
      font = { size = 15, style = "Semibold" },
      color = island_style.text(),
      padding_left = 16,
      padding_right = 4,
    },
    right = {
      text = glyph,
      font = { size = 18, style = "Regular" },
      color = island_style.success(),
      padding_left = 4,
      padding_right = 16,
    },
  }
end)
