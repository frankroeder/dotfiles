local colors = require "colors"
local display = require "display"
local settings = require "settings"

local M = {}

-- The pill blends with the physical notch: always pure black, regardless of theme.
local NOTCH_BLACK = 0xff000000

local function on_notched_builtin(idx)
  return idx == display.builtin_index and display.notch_width > 0
end

-- Notch-black fill; border and foregrounds follow the active theme.
function M.bar(_display_index)
  local theme = settings.theme
  local ui = settings.ui
  return {
    color = NOTCH_BLACK,
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

-- Foregrounds on the notch-black pill: always the dark palette's hues at full
-- alpha (bright), independent of light/dark mode — light palette is too dark on black.
local fg = colors.mocha

function M.text()
  return 0xffffffff
end

function M.muted()
  return fg.text
end

function M.accent()
  return fg.blue
end

function M.accent_alt()
  return fg.sky
end

function M.warn()
  return fg.peach
end

function M.critical()
  return fg.red
end

function M.success()
  return fg.green
end

return M
