local display = require "display"
local island_style = require "island_style"
local settings = require "settings"

local bar_margin = math.max(0, math.floor((display.screen_width - display.notch_width) / 2))
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
  y_offset = settings.island.y_offset_idle,
  margin = bar_margin,
  notch_width = 0,
  display = display.builtin_index,
}