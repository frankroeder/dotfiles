local icons = require "icons"
local island = require "island_core"
local island_style = require "island_style"
local settings = require "settings"

if not settings.island.power then
  return
end

local listener = sbar.add("item", "listener.power", {
  drawing = false,
  updates = true,
  update_freq = 0,
  icon = { drawing = false },
  label = { drawing = false },
  background = { drawing = false },
})

listener:subscribe("island_power", function(env)
  local charging = env.state == "charging"
  local pct = tonumber(env.percent)
  local text = charging and "Charging" or "On Battery"
  if pct then
    text = text .. string.format(" · %d%%", pct)
  end

  island.expand {
    width = settings.island.widths.power,
    height = island.IDLE_H,
    duration = settings.island.power_duration,
    left = {
      text = text,
      font = { size = 15, style = "Semibold" },
      align = "left",
      color = island_style.text(),
      padding_left = 16,
      padding_right = 4,
    },
    right = {
      text = charging and icons.battery.charging or icons.battery["50"],
      font = { size = 20, style = "Regular" },
      align = "center",
      width = 32,
      color = charging and island_style.success() or island_style.muted(),
      padding_left = 4,
      padding_right = 16,
    },
  }
end)
