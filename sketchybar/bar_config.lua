local settings = require "settings"
local display = require "display"

local M = {}

local bar_position = "top"
local display_watch = nil

-- Real notch only on a lone built-in screen. Dual-monitor and notchless stay 0
-- (island covers the notch; a fake cutout artifacts on externals).
function M.resolve_notch(position, info)
  info = info or display
  if position ~= "top" or info.external_index ~= nil then
    return 0
  end
  local width = info.notch_width or 0
  if width < 1 then
    return 0
  end
  return width
end

function M.bar_props(position, extra)
  extra = extra or {}
  -- Top bar on every display. Dual-monitor: notch_width = 0 (no external cutout).
  local props = {
    notch_width = M.resolve_notch(position, display),
    notch_display_height = 0,
  }
  for key, value in pairs(extra) do
    props[key] = value
  end
  return props
end

function M.bar(extra)
  sbar.bar(M.bar_props(bar_position, extra))
end

function M.refresh_geometry()
  if display.refresh then
    display.refresh()
  end
  M.bar()
end

function M.apply(position)
  bar_position = position
  local props = {
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
  if settings.bar_shadow then
    props.shadow = { drawing = true }
  end
  M.bar(props)

  -- Hotplug / arrangement change: re-probe notch + reapply bar geometry.
  if not display_watch then
    sbar.add("event", "display_change")
    display_watch = sbar.add("item", "bar.display_watch", { drawing = false, updates = true })
    display_watch:subscribe("display_change", function()
      M.refresh_geometry()
    end)
  end
end

return M
