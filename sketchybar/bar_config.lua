local settings = require "settings"
local display = require "display"

local M = {}

function M.resolve_notch(position, info)
  info = info or display
  if position == "top" and info.external_index == nil then
    local width = info.notch_width
    if width < 1 then
      return 200
    end
    return width
  end
  return 0
end

function M.apply(position)
  -- notch cutouts only belong on a lone built-in screen (island covers the notch
  -- in dual-monitor setups). On the bottom bar or on external displays they leave
  -- a visible artifact at the screen edge.
  local notch = M.resolve_notch(position, display)

  sbar.bar {
    height = settings.bar_height,
    position = position,
    padding_right = settings.bar_padding,
    padding_left = settings.bar_padding,
    color = settings.theme.bar,
    border_color = settings.theme.bar_border,
    border_width = settings.bar_border_width,
    blur_radius = settings.bar_blur_radius,
    margin = settings.bar_margin,
    corner_radius = settings.bar_corner_radius,
    notch_width = notch,
    notch_display_height = 0,
    topmost = "off",
  }
end

return M
