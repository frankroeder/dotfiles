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
      kind = "siri",
      priority = island.priority.siri,
      sticky = true,
      width = settings.island.widths.siri,
      height = island.IDLE_H,
      duration = 0,
      frames = siri_frames,
      color = SIRI_FILL,
      border_color = SIRI_FILL,
      left = {
        text = "Siri",
        font = { size = 16, style = "Semibold" },
        color = SIRI_GLYPH,
        padding_left = 16,
        padding_right = 4,
      },
      right = {
        text = "􀫛",
        font = { size = 26, style = "Regular" },
        color = SIRI_GLYPH,
        padding_left = 4,
        padding_right = 16,
      },
    }
  else
    island.restore_idle { frames = siri_frames }
  end
end)
