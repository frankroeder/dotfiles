local colors = require "colors"
local island = require "island_core"
local settings = require "settings"

-- Vibrant Siri highlight: solid mauve pill, matching the bar's Siri tint.
local SIRI_FILL = colors.mauve
local SIRI_GLYPH = 0xffffffff

local listener = sbar.add("item", "listener.siri", {
  drawing = false,
  updates = true,
  update_freq = 0,
  icon = { drawing = false },
  label = { drawing = false },
  background = { drawing = false },
})

listener:subscribe("island_siri", function(env)
  if env.action == "appear" then
    island.expand {
      width = settings.island.widths.siri,
      height = island.IDLE_H,
      duration = 0,
      color = SIRI_FILL,
      border_color = SIRI_FILL,
      left = {
        text = "􀫛",
        font = { size = 32, style = "Regular" },
        color = SIRI_GLYPH,
        width = 80,
        padding_left = 2,
        padding_right = 16,
      },
    }
  else
    island.restore_idle()
  end
end)
