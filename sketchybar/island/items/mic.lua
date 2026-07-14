local icons = require "icons"
local island = require "island_core"
local island_style = require "island_style"
local settings = require "settings"

if not settings.island.mic then
  return
end

local listener = sbar.add("item", "listener.mic", {
  drawing = false,
  updates = true,
  update_freq = 0,
  icon = { drawing = false },
  label = { drawing = false },
  background = { drawing = false },
})

local last_muted = nil

listener:subscribe("island_mic", function(env)
  local muted
  if env.muted ~= nil then
    muted = tostring(env.muted):lower():match "true" ~= nil or tostring(env.muted) == "1"
  else
    local vol = tonumber(env.percent or env.volume)
    if vol == nil then
      return
    end
    muted = vol <= 0
  end

  if last_muted ~= nil and muted == last_muted then
    return
  end
  last_muted = muted

  island.expand {
    kind = "mic",
    priority = island.priority.mic,
    width = settings.island.widths.mic,
    height = island.IDLE_H,
    duration = settings.island.mic_duration,
    left = {
      text = muted and "Mic muted" or "Mic on",
      font = { size = 15, style = "Semibold" },
      color = muted and island_style.warn() or island_style.text(),
      padding_left = 16,
      padding_right = 4,
    },
    right = {
      text = muted and icons.mic.off or icons.mic.on,
      font = { size = 18, style = "Regular" },
      color = muted and island_style.warn() or island_style.success(),
      padding_left = 4,
      padding_right = 16,
    },
  }
end)
