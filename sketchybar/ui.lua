local colors = require "colors"
local settings = require "settings"

local ui = {}

local theme = settings.theme
local metrics = settings.ui

function ui.capsule(opts)
  opts = opts or {}
  return {
    drawing = opts.drawing ~= false,
    color = opts.color or theme.surface,
    border_width = opts.border_width or metrics.item_border_width,
    border_color = opts.border_color or theme.border,
    corner_radius = opts.corner_radius or metrics.item_corner_radius,
    height = opts.height or metrics.item_height,
  }
end

function ui.group(accent, opts)
  opts = opts or {}
  return {
    drawing = true,
    color = opts.color or colors.with_alpha(theme.surface_alt, 0.22),
    border_width = opts.border_width or metrics.group_border_width,
    border_color = opts.border_color or colors.with_alpha(accent or theme.border, 0.34),
    corner_radius = opts.corner_radius or metrics.group_corner_radius,
    height = opts.height or metrics.group_height,
  }
end

function ui.popup(accent)
  return {
    border_width = 0,
    corner_radius = metrics.popup_corner_radius,
    border_color = colors.with_alpha(accent or theme.popup_border, 0.58),
    color = theme.popup_bg,
    shadow = { drawing = true },
  }
end

function ui.popup_row(height)
  return {
    height = height or metrics.popup_row_height,
  }
end

return ui
