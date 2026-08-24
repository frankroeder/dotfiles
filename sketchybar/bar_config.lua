local settings = require "settings"
local display = require "display"

local M = {}

local bar_position = "top"
local display_watch = nil
local last_notch = nil
local rest = { y_offset = 0, margin = settings.bar_margin, color = settings.theme.bar }

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

-- Top bar on every display. Dual-monitor: notch_width = 0 (no external cutout).
-- notch_width joins the props only when its resolved value CHANGES: M.bar runs
-- inside sbar.animate batches (lock slide) and constant-valued props in a
-- batch jitter/flicker.
local function attach_notch(props)
  local notch = M.resolve_notch(bar_position, display)
  if notch ~= last_notch then
    props.notch_width = notch
    props.notch_display_height = 0
    last_notch = notch
  end
  return props
end

function M.rest_geometry()
  return { y_offset = rest.y_offset, margin = rest.margin }
end

function M.rest_color()
  return rest.color or settings.theme.bar
end

function M.set_rest_color(color)
  rest.color = color
end

-- Send ONLY the props passed in. This used to accumulate every prop ever
-- passed (M.apply seeded the store with the FULL bar config: position, height,
-- margin, paddings, topmost, ...) and replay the whole set on every call —
-- inside sbar.animate batches (siri tint, lock slide) that meant a bar-wide
-- batch of constant-valued props per event: bars stretched/flickered wildly
-- whenever Siri opened. sketchybar keeps unspecified props as-is, so minimal
-- sends are always correct.
function M.bar(extra)
  local props = {}
  for key, value in pairs(extra or {}) do
    props[key] = value
  end
  attach_notch(props)
  if next(props) then
    sbar.bar(props)
  end
end

function M.refresh_geometry()
  if display.refresh then
    display.refresh()
  end
  M.bar()
end

function M.apply(position, extra)
  bar_position = position
  extra = extra or {}
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
    y_offset = settings.bar_y_offset or 0,
    topmost = "off",
  }
  if settings.bar_shadow then
    props.shadow = { drawing = true }
  end
  for key, value in pairs(extra) do
    props[key] = value
  end
  rest.y_offset = props.y_offset or 0
  rest.margin = props.margin or settings.bar_margin
  rest.color = props.color or settings.theme.bar
  last_notch = nil -- force a fresh notch_width on the full (un-animated) apply
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
