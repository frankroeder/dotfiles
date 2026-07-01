-- Theme updates only from AppleInterfaceThemeChangedNotification (theme_change).

local colors = require "colors"
local settings = require "settings"

sbar.add("event", "theme_colors_updated")
sbar.add("event", "theme_relay")

local handler = sbar.add("item", "theme_handler", { drawing = false, updates = true })

local bar_name = os.getenv "BAR_NAME" or "sketchybar"
local this = bar_name == "sketchybar-top" and "top" or "bottom"
local peer = this == "top" and "/opt/homebrew/bin/sketchybar" or "/opt/homebrew/bin/sketchybar-top"
local island = "/opt/homebrew/bin/sketchybar-island"

local function apply(is_dark)
  if is_dark == colors.is_dark then
    return false
  end
  colors.set_dark(is_dark)
  settings.refresh_theme()
  sbar.trigger "theme_colors_updated"
  if this == "bottom" then
    sbar.exec "pkill -x borders 2>/dev/null; $HOME/.config/borders/bordersrc >/dev/null 2>&1 &"
  end
  return true
end

local function repaint(relay)
  sbar.exec("defaults read -g AppleInterfaceStyle 2>/dev/null || echo Light", function(result)
    local is_dark = result:lower():match "dark" ~= nil
    if not apply(is_dark) then
      return
    end
    if relay then
      sbar.exec(peer .. " --trigger theme_relay 2>/dev/null")
      sbar.exec(island .. " --trigger theme_relay 2>/dev/null")
    end
  end)
end

handler:subscribe("theme_change", function()
  repaint(true)
end)

handler:subscribe("theme_relay", function()
  repaint(false)
end)

return { apply = apply }