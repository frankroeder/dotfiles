local icons = require "icons"
local island = require "island_core"
local island_style = require "island_style"
local settings = require "settings"

if not settings.island.bluetooth then
  return
end

local listener = sbar.add("item", "listener.bluetooth", {
  drawing = false,
  updates = true,
  update_freq = 0,
  icon = { drawing = false },
  label = { drawing = false },
  background = { drawing = false },
})

listener:subscribe("island_bluetooth", function(env)
  local name = env.name or env.INFO or ""
  if name == "" then
    return
  end
  -- Keep name + " · battery" inside the left lobe (hugs the notch's left edge).
  local short = #name > 7 and (name:sub(1, 6) .. "…") or name
  local battery = env.battery
  local text = short
  if battery and battery ~= "" then
    text = short .. " · " .. battery
  end

  local glyph = icons.bluetooth.on
  local dtype = (env.type or ""):lower()
  if dtype:find "head" or dtype:find "airpods" then
    glyph = icons.device.headphone
  elseif dtype:find "keyboard" then
    glyph = icons.device.keyboard
  elseif dtype:find "mouse" or dtype:find "trackpad" then
    glyph = icons.device.mouse
  elseif dtype:find "speaker" then
    glyph = icons.device.speaker
  end

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
