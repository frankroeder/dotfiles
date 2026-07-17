local icons = require "icons"
local island = require "island_core"
local island_style = require "island_style"
local settings = require "settings"

local listener = sbar.add("item", "listener.window", {
  drawing = false,
  updates = true,
  update_freq = 0,
  icon = { drawing = false },
  label = { drawing = false },
  background = { drawing = false },
})

-- Toggled from skhd (fn+shift-w float, fn+shift-s sticky); re-query yabai for state.
local PROPS = {
  float = {
    key = "is-floating",
    on = { text = "Floating", glyph = icons.yabai.float, color = island_style.accent() },
    off = { text = "Tiled", glyph = icons.yabai.bsp, color = island_style.text() },
  },
  sticky = {
    key = "is-sticky",
    on = { text = "Sticky", glyph = icons.pin, color = island_style.accent() },
    off = { text = "Not sticky", glyph = icons.pin, color = island_style.muted() },
  },
}

listener:subscribe("island_window", function(env)
  local spec = PROPS[env.prop]
  if not spec then
    return
  end
  sbar.exec("yabai -m query --windows --window 2>/dev/null", function(win)
    if type(win) ~= "table" then
      return
    end
    local s = win[spec.key] == true and spec.on or spec.off
    island.expand {
      kind = "window",
      priority = island.priority.window,
      width = settings.island.widths.window,
      height = island.IDLE_H,
      duration = settings.island.window_duration,
      left = {
        text = s.text,
        font = { size = 15, style = "Semibold" },
        color = s.color,
        padding_left = 16,
        padding_right = 4,
      },
      right = {
        text = s.glyph,
        font = { size = 18, style = "Regular" },
        color = s.color,
        padding_left = 4,
        padding_right = 16,
      },
    }
  end)
end)
