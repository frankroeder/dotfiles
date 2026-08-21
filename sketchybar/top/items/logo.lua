local colors = require "colors"
local icons = require "icons"

sbar.add("item", "apple.logo", {
  position = "left",
  icon = {
    string = icons.apple,
    font = { size = 16.0 },
    color = colors.red,
    padding_left = 12,
    padding_right = 8,
  },
  label = { drawing = false },
  background = { drawing = false },
  padding_left = 4,
  padding_right = 4,
  click_script = "open -a 'System Settings'",
})
