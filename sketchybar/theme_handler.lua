-- Theme updates only from AppleInterfaceThemeChangedNotification (theme_change).

local colors = require "colors"
local settings = require "settings"

sbar.add("event", "theme_colors_updated")
sbar.add("event", "theme_relay")

local handler = sbar.add("item", "theme_handler", { drawing = false, updates = true })

local bar_name = os.getenv "BAR_NAME" or "sketchybar"
local this = bar_name == "sketchybar-top" and "top" or "bottom"
local peer = this == "top" and "/opt/homebrew/bin/sketchybar" or "/opt/homebrew/bin/sketchybar-top"
local island = require("island_bridge").bin

-- macOS appearance always wins over CATPPUCCIN_TERM_MODE (colors.lua load).
-- Always repaint: skipping when is_dark already matches left items stale if
-- the process started from the env palette while System Settings said otherwise.
local function apply(is_dark)
  local changed = is_dark ~= colors.is_dark
  colors.set_dark(is_dark)
  settings.refresh_theme()
  -- Keep sbar.default popup/icon/label colors in sync for newly created rows.
  require("default").apply()
  local bar_config = require "bar_config"
  bar_config.set_rest_color(settings.theme.bar)
  bar_config.bar { color = settings.theme.bar }
  -- Lua trigger misses items with updates=when_shown; CLI notify reaches them.
  sbar.trigger "theme_colors_updated"
  local bin = this == "top" and "/opt/homebrew/bin/sketchybar-top" or "/opt/homebrew/bin/sketchybar"
  sbar.exec(bin .. " --trigger theme_colors_updated 2>/dev/null")
  if changed and this == "bottom" then
    sbar.exec "pkill -x borders 2>/dev/null; $HOME/.config/borders/bordersrc >/dev/null 2>&1 &"
  end
  return changed
end

-- Drop stale defaults reads (notification can beat AppleInterfaceStyle).
local gen = 0

local function repaint(relay)
  gen = gen + 1
  local token = gen
  sbar.exec("defaults read -g AppleInterfaceStyle 2>/dev/null || echo Light", function(result)
    if token ~= gen then
      return
    end
    local is_dark = result:lower():match "dark" ~= nil
    apply(is_dark)
    if relay then
      sbar.exec(peer .. " --trigger theme_relay 2>/dev/null")
      sbar.exec(island .. " --trigger theme_relay 2>/dev/null")
    end
  end)
end

-- Wait until AppleInterfaceStyle matches the notification, then relay once.
handler:subscribe("theme_change", function()
  sbar.delay(0.3, function()
    repaint(true)
  end)
end)

handler:subscribe("theme_relay", function()
  repaint(false)
end)

return { apply = apply }