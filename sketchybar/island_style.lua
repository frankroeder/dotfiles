local settings = require "settings"

local M = {}

function M.bar()
  local theme = settings.theme
  local ui = settings.ui
  return {
    color = theme.surface,
    border_color = theme.border,
    border_width = theme.border_width,
    corner_radius = settings.island.corner_radius or ui.item_corner_radius,
  }
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