local settings = require "settings"
local display = require "display"

local M = {}

local bar_position = "top"

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

function M.resolve_display(position, info)
  info = info or display
  -- Dual-monitor top bar: pin to built-in only so notch geometry never renders
  -- on external screens (island + front_app cover the other displays).
  if position == "top" and info.external_index ~= nil then
    return info.builtin_index
  end
  return nil
end

function M.bar_props(position, extra)
  extra = extra or {}
  local props = {
    notch_width = M.resolve_notch(position, display),
    notch_display_height = 0,
  }
  local disp = M.resolve_display(position, display)
  if disp then
    props.display = disp
  end
  for key, value in pairs(extra) do
    props[key] = value
  end
  return props
end

function M.bar(extra)
  sbar.bar(M.bar_props(bar_position, extra))
end

function M.apply(position)
  bar_position = position
  -- notch cutouts only belong on a lone built-in screen (island covers the notch
  -- in dual-monitor setups). On the bottom bar or on external displays they leave
  -- a visible artifact at the screen edge.
  M.bar {
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
    topmost = "off",
  }
end

return M