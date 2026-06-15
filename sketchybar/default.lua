local settings = require "settings"
local ui = require "ui"
require "siri"
require "lock"

sbar.default {
  updates = "when_shown",
  blur_radius = settings.ui.item_blur_radius,
  icon = {
    font = {
      family = settings.font.text,
      style = settings.font.style_map["Bold"],
      size = settings.ui.icon_size,
    },
    color = settings.theme.accent,
    padding_left = settings.ui.icon_padding_left,
    padding_right = settings.ui.icon_padding_right,
  },
  label = {
    font = {
      family = settings.font.text,
      style = settings.font.style_map["Bold"],
      size = settings.ui.label_size,
    },
    color = settings.theme.text_muted,
    padding_left = settings.ui.label_padding_left,
    padding_right = settings.ui.label_padding_right,
  },
  background = ui.capsule {
    color = settings.theme.surface,
    border_color = settings.theme.border,
    height = settings.ui.item_height,
    corner_radius = settings.ui.item_corner_radius,
  },
  popup = {
    background = ui.popup(settings.theme.popup_border),
    blur_radius = settings.ui.item_blur_radius,
    y_offset = settings.ui.popup_y_offset,
  },
  padding_left = settings.paddings,
  padding_right = settings.paddings,
  scroll_texts = true,
}
