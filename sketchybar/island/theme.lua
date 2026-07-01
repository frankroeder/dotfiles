local colors = require "colors"
local display = require "display"
local island_style = require "island_style"
local settings = require "settings"

local handler = sbar.add("item", "island.theme", { drawing = false, updates = true })

local function repaint()
  local margin = math.max(0, math.floor((display.screen_width - display.notch_width) / 2))
  local style = island_style.bar()
  sbar.bar {
    color = style.color,
    border_color = style.border_color,
    border_width = style.border_width,
    corner_radius = style.corner_radius,
    margin = margin,
  }
  local core = package.loaded["island_core"]
  if core and core.refresh_theme then
    core.refresh_theme()
  end
end

handler:subscribe("theme_change", function()
  sbar.exec("defaults read -g AppleInterfaceStyle 2>/dev/null || echo Light", function(result)
    local is_dark = result:lower():match "dark" ~= nil
    if is_dark == colors.is_dark then
      return
    end
    colors.set_dark(is_dark)
    settings.refresh_theme()
    repaint()
  end)
end)

handler:subscribe("theme_relay", function()
  colors.update_theme_colors()
  settings.refresh_theme()
  repaint()
end)