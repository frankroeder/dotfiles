local settings = require "settings"
local colors = require "colors"

sbar.default {
  updates = "when_shown",
  icon = {
    font = {
      family = settings.font.text,
      style = settings.font.style_map["Bold"],
      size = 14.0,
    },
    color = colors.white,
    padding_left = settings.paddings,
    padding_right = settings.paddings,
  },
  label = {
    font = {
      family = settings.font.text,
      style = settings.font.style_map["Regular"],
      size = 13.0,
    },
    color = colors.white,
    padding_left = settings.paddings,
    padding_right = settings.paddings,
  },
  background = {
    padding_left = 4,
    padding_right = 4,
    height = 30,
    corner_radius = 10,
    border_width = 1,
    border_color = colors.bg2,
    color = colors.pill_bg,
    drawing = true,
  },
  popup = {
    background = {
      border_width = 1,
      corner_radius = 9,
      border_color = colors.popup.border,
      color = colors.popup.bg,
      shadow = { drawing = true },
    },
    blur_radius = 20,
  },
  padding_left = 2,
  padding_right = 2,
}
