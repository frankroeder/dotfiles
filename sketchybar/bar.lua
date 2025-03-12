local colors = require "colors"

sbar.bar {
  height = 28,
  position = "bottom",
  padding_right = 10,
  padding_left = 10,
  color = colors.bar.bg,
  border_color = colors.bar.border,
  topmost = "window",
}
