local colors = require "colors"
local display = require "display"
local settings = require "settings"

local M = {}

local function on_notched_builtin(idx)
  return idx == display.builtin_index and display.notch_width > 0
end

-- Same fill as the top bar so the idle seed is the bar strip; expand grows out of it.
function M.bar()
  local theme = settings.theme
  return {
    color = theme.bar,
    border_color = colors.transparent,
    border_width = 0,
    corner_radius = settings.bar_corner_radius or settings.island.corner_radius or 8,
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
  return colors.text
end

function M.muted()
  return colors.subtext1
end

function M.accent()
  return colors.blue
end

function M.warn()
  return colors.peach
end

function M.success()
  return colors.green
end

return M
