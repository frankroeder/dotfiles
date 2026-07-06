local icons = require "icons"
local island = require "island_core"
local island_style = require "island_style"
local settings = require "settings"

if not settings.island.volume then
  return
end

local listener = sbar.add("item", "listener.volume", {
  drawing = false,
  updates = true,
  update_freq = 0,
  icon = { drawing = false },
  label = { drawing = false },
  background = { drawing = false },
})

local function icon_for(vol)
  if vol >= 66 then
    return icons.volume[100]
  elseif vol >= 33 then
    return icons.volume[66]
  elseif vol >= 10 then
    return icons.volume[33]
  elseif vol > 0 then
    return icons.volume[10]
  end
  return icons.volume[0]
end

local last_vol = nil

listener:subscribe("volume_change", function(env)
  local vol = tonumber(env.INFO)
  if not vol or vol == last_vol then
    return
  end
  local first = last_vol == nil
  last_vol = vol
  -- sketchybar announces the current volume once on subscribe; don't pill that.
  if first then
    return
  end

  island.expand {
    width = settings.island.widths.volume,
    height = island.IDLE_H,
    duration = settings.island.volume_duration,
    left = {
      text = string.format("%d%%", vol),
      font = { size = 15, style = "Semibold" },
      align = "left",
      color = island_style.text(),
      padding_left = 16,
      padding_right = 4,
    },
    right = {
      text = icon_for(vol),
      font = { size = 18, style = "Regular" },
      align = "center",
      width = 32,
      color = island_style.accent(),
      padding_left = 4,
      padding_right = 16,
    },
  }
end)
