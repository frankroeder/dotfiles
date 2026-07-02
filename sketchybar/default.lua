local settings = require "settings"
local ui = require "ui"
require "siri"
require "lock"

local M = {}

function M.apply()
  local default_bg = ui.capsule {
    color = settings.theme.surface,
    border_color = settings.theme.border,
    height = settings.ui.item_height,
    corner_radius = settings.ui.item_corner_radius,
  }

  sbar.default {
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
    background = default_bg,
    popup = {
      background = ui.popup(settings.theme.popup_border),
      blur_radius = settings.ui.item_blur_radius,
      y_offset = settings.ui.popup_y_offset,
      align = "center",
    },
    padding_left = settings.layout.spacing.widget,
    padding_right = settings.layout.spacing.widget,
  }
end

M.apply()

return M
