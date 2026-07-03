local settings = require "settings"
local ui = require "ui"

sbar.default {
  -- No display pin: pill items must draw on whichever display the bar
  -- currently targets (island_core moves the bar to the focused display).
  updates = "when_shown",
  blur_radius = settings.ui.item_blur_radius,
  icon = {
    font = {
      family = settings.font.family,
      style = settings.font.style_map["Bold"],
      size = settings.ui.icon_size,
    },
    color = settings.theme.accent,
    padding_left = settings.ui.icon_padding_left,
    padding_right = settings.ui.icon_padding_right,
  },
  label = {
    font = {
      family = settings.font.family,
      style = settings.font.style_map["Bold"],
      size = settings.ui.label_size,
    },
    color = settings.theme.text_muted,
    padding_left = settings.ui.label_padding_left,
    padding_right = settings.ui.label_padding_right,
  },
  background = ui.capsule(),
  padding_left = settings.layout.spacing.widget,
  padding_right = settings.layout.spacing.widget,
  -- scroll_texts = true,
}