local settings = require "settings"
local colors = require "colors"

sbar.default {
  updates = "when_shown",
  icon = {
    font = {
      family = settings.font.text,
      style = settings.font.style_map["Bold"],
      size = 17.0,
    },
    color = colors.white,
    padding_left = settings.paddings,
    padding_right = settings.paddings,
    background = { image = { corner_radius = 9 } },
  },
  label = {
    font = {
      family = settings.font.text,
      style = settings.font.style_map["Regular"],
      size = 14.0,
    },
    color = colors.white,
    padding_left = settings.paddings,
    padding_right = settings.paddings,
  },
  background = {
    height = 26,
    corner_radius = 9,
    border_width = 1,
    border_color = colors.bg2,
    color = colors.pill_bg,
    drawing = true,
  },
  popup = {
    background = {
      border_width = 2,
      corner_radius = 9,
      border_color = colors.popup.border,
      color = colors.popup.bg,
      shadow = { drawing = true },
    },
    blur_radius = 50,
  },
  padding_left = 5,
  padding_right = 5,
  scroll_texts = true,
}
