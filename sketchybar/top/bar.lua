local settings = require "settings"

sbar.bar {
  height = settings.bar_height,
  position = "top",
  padding_right = settings.bar_padding,
  padding_left = settings.bar_padding,
  color = settings.theme.bar,
  border_color = settings.theme.bar_border,
  border_width = settings.bar_border_width,
  blur_radius = settings.bar_blur_radius,
  margin = settings.bar_margin,
  corner_radius = settings.bar_corner_radius,
  topmost = "off",
}
