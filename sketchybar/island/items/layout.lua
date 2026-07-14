local icons = require "icons"
local island = require "island_core"
local island_style = require "island_style"
local settings = require "settings"

if not settings.island.layout then
  return
end

local listener = sbar.add("item", "listener.layout", {
  drawing = false,
  updates = true,
  update_freq = 0,
  icon = { drawing = false },
  label = { drawing = false },
  background = { drawing = false },
})

-- Fired from skhd on `yabai -m space --layout <l>` (fn-e/w/s).
listener:subscribe("island_layout", function(env)
  local layout = env.layout or ""
  local glyph = icons.yabai[layout]
  if not glyph then
    return
  end

  island.expand {
    kind = "layout",
    priority = island.priority.layout,
    width = settings.island.widths.layout,
    height = island.IDLE_H,
    duration = settings.island.layout_duration,
    left = {
      text = layout:sub(1, 1):upper() .. layout:sub(2) .. " layout",
      font = { size = 15, style = "Semibold" },
      color = island_style.text(),
      padding_left = 16,
      padding_right = 4,
    },
    right = {
      text = glyph,
      font = { size = 18, style = "Regular" },
      color = island_style.accent(),
      padding_left = 4,
      padding_right = 16,
    },
  }
end)
