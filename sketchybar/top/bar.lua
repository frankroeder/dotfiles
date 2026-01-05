local colors = require("colors")

sbar.bar {
  height = 32,
  position = "top",
  padding_right = 10,
  padding_left = 10,
  color = colors.bar.bg,
  border_color = colors.bar.border,
  margin = 10,
  corner_radius = 12,
  topmost = "window",
}
