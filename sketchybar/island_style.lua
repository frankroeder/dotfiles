local colors = require "colors"
local display = require "display"
local settings = require "settings"

local M = {}

-- Blends with the physical notch; distinct from the themed solid bars.
M.NOTCH_BLACK = 0xff000000

local function on_notched_builtin(idx)
  return idx == display.builtin_index and display.notch_width > 0
end

function M.bar()
  local theme = settings.theme
  return {
    color = M.NOTCH_BLACK,
    border_color = theme.border,
    border_width = theme.border_width or 1,
    corner_radius = settings.island.corner_radius or settings.bar_corner_radius or 8,
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

-- Expanded fg: static mocha at full alpha (readable on notch-black in both modes).
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

function M.warn()
  return fg.peach
end

function M.success()
  return fg.green
end

return M
