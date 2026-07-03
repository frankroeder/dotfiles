local display = require "display"
local settings = require "settings"

local M = {}

local function on_notched_builtin(idx)
  return idx == display.builtin_index and display.notch_width > 0
end

-- Pill follows the active theme; only the y-offset differs per display (notch tuck).
function M.bar(_display_index)
  local theme = settings.theme
  local ui = settings.ui
  return {
    color = theme.surface,
    border_color = theme.border,
    border_width = theme.border_width,
    corner_radius = settings.island.corner_radius or ui.item_corner_radius,
  }
end

function M.on_notched_builtin(idx)
  return on_notched_builtin(idx)
end

function M.y_offset_idle(display_index)
  if on_notched_builtin(display_index) then
    return settings.island.y_offset_idle
  end
  return settings.island.y_offset_external or 0
end

function M.y_offset_expand(display_index)
  if on_notched_builtin(display_index) then
    return settings.island.y_offset_expand
  end
  return settings.island.y_offset_external or 0
end

function M.text()
  return settings.theme.text_primary
end

function M.muted()
  return settings.theme.text_muted
end

function M.accent()
  return settings.theme.accent
end

function M.accent_alt()
  return settings.theme.accent_alt
end

function M.warn()
  return settings.theme.warn
end

function M.critical()
  return settings.theme.critical
end

function M.success()
  return settings.theme.success
end

return M