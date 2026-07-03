local colors = require "colors"
local island = require "island_core"
local settings = require "settings"

local siri_frames = settings.island.siri_frames or settings.motion.slow

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
      frames = siri_frames,
      from_idle = true,
      color = SIRI_FILL,
      border_color = SIRI_FILL,
      left = {
        text = "􀫛",
        font = { size = 32, style = "Regular" },
        color = SIRI_GLYPH,
        width = 100,
        padding_left = 2,
        padding_right = 16,
      },
    }
  else
    island.restore_idle { frames = siri_frames }
  end
end)
