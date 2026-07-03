local colors = require "colors"
local settings = require "settings"

local handler = sbar.add("item", "island.theme", { drawing = false, updates = true })

local function repaint()
  -- island_core owns the pill geometry (focused display, margin, y-offset);
  -- it re-derives the themed style on refresh.
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