local settings = require "settings"
local ui = require "ui"
require "siri"
require "lock"

sbar.default {
  updates = "when_shown",
  icon = {
    font = {
      family = settings.font.text,
      style = settings.font.style_map["Bold"],
      size = settings.ui.icon_size,
    },
    color = settings.theme.text_primary,
    padding_left = settings.paddings,
    padding_right = settings.paddings,
  },
  label = {
    font = {
      family = settings.font.text,
      style = settings.font.style_map["Regular"],
      size = settings.ui.label_size,
    },
    color = settings.theme.text_primary,
    padding_left = settings.ui.label_padding,
    padding_right = settings.ui.label_padding,
  },
  background = ui.capsule {
    color = settings.theme.surface,
    border_color = settings.theme.border,
  },
  popup = {
    background = ui.popup(settings.theme.popup_border),
    blur_radius = 20,
  },
  padding_left = 2,
  padding_right = 2,
  scroll_texts = true,
}
