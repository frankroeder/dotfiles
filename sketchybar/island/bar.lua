local display = require "display"
local island_style = require "island_style"
local settings = require "settings"

-- Pill baseline: the physical notch when the focused screen is the notched
-- built-in, else a 200px pill. The island only ever lives on the focused
-- display (island_core retargets it on focus changes).
local focused = display.focused_index()

local focused_width = display.main_width
for _, row in ipairs(display.displays) do
  if row.index == focused and row.width then
    focused_width = row.width
    break
  end
end

local on_notched = focused == display.builtin_index and display.notch_width > 0
local pill_width = on_notched and display.notch_width or 200
local bar_margin = math.max(0, math.floor((focused_width - pill_width) / 2))
local style = island_style.bar()

sbar.bar {
  position = "top",
  height = settings.island.bar_height,
  color = style.color,
  border_color = style.border_color,
  border_width = style.border_width,
  corner_radius = style.corner_radius,
  padding_right = 0,
  padding_left = 0,
  blur_radius = 0,
  shadow = false,
  topmost = "off",
  y_offset = island_style.y_offset_idle(focused),
  margin = bar_margin,
  notch_width = 0,
  display = focused,
  -- Idle island is invisible; island_core unhides the bar only while expanded.
  hidden = true,
}
