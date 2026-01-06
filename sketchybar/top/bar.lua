local colors = require "colors"
local settings = require "settings"

sbar.bar {
  height = settings.bar_height,
  position = "top",
  padding_right = settings.bar_padding,
  padding_left = settings.bar_padding,
  color = settings.bar_color,
  border_color = settings.bar_border_color,
  margin = settings.bar_margin,
  corner_radius = settings.bar_corner_radius,
  topmost = "off",
}
