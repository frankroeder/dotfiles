local icons = require "icons"
local island = require "island_core"
local island_style = require "island_style"
local settings = require "settings"

local listener = sbar.add("item", "listener.battery", {
  drawing = false,
  updates = true,
  update_freq = 0,
  icon = { drawing = false },
  label = { drawing = false },
  background = { drawing = false },
})

listener:subscribe("island_battery", function(env)
  local pct = math.max(0, math.min(100, tonumber(env.percent) or 100))

  if pct < 15 then
    -- Critical: tall two-line pill, centred below the notch.
    island.expand {
      width = settings.island.widths.battery_critical,
      height = island.EXPAND_H,
      duration = 0,
      right = {
        text = string.format("%.0f%%", pct),
        font = { size = 20, style = "Semibold" },
        align = "center",
        color = island_style.critical(),
      },
      subtitle = {
        text = "Battery critical — connect your charger.",
        font = { size = 12, style = "Regular" },
        align = "center",
        color = island_style.critical(),
      },
    }
  elseif pct < 30 then
    -- Warning: text in the left lobe, battery glyph in the right lobe.
    island.expand {
      width = settings.island.widths.battery,
      height = island.IDLE_H,
      duration = 8,
      left = {
        text = string.format("%.0f%% left", pct),
        font = { size = 15, style = "Semibold" },
        align = "left",
        color = island_style.warn(),
        padding_left = 16,
        padding_right = 4,
      },
      right = {
        text = icons.battery["25"],
        font = { size = 20, style = "Regular" },
        align = "center",
        width = 32,
        color = island_style.warn(),
        padding_left = 4,
        padding_right = 16,
      },
    }
  end
end)
