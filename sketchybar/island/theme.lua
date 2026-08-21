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

local function apply_system(is_dark)
  colors.set_dark(is_dark)
  settings.refresh_theme()
  repaint()
end

-- Always probe macOS appearance. Do not use the env-palette loader here.
local gen = 0
local function probe()
  gen = gen + 1
  local token = gen
  sbar.exec("defaults read -g AppleInterfaceStyle 2>/dev/null || echo Light", function(result)
    if token ~= gen then
      return
    end
    apply_system(result:lower():match "dark" ~= nil)
  end)
end

-- Same delay as theme_handler: notification can beat AppleInterfaceStyle.
handler:subscribe("theme_change", function()
  sbar.delay(0.3, probe)
end)
handler:subscribe("theme_relay", probe)

probe()
