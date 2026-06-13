local colors = require "colors"
local icons = require "icons"
local settings = require "settings"
local ui = require "ui"

local mode = sbar.add("item", "widgets.mode", {
  position = "left",
  icon = {
    string = icons.mode.dark,
    color = colors.yellow,
    padding_left = 6,
    padding_right = 6,
    font = {
      style = settings.font.style_map["Regular"],
      size = 16.0,
    },
  },
  label = { drawing = false },
  background = ui.capsule {},
})

mode:subscribe({ "routine", "system_woke", "forced" }, function()
  -- Use osascript (same as the toggle) for reliable current dark mode state
  sbar.exec([[osascript -e 'tell application "System Events" to tell appearance preferences to return dark mode' 2>/dev/null || echo false]], function(result)
    local is_dark = (result or ""):lower():match("true") ~= nil
    mode:set {
      icon = {
        string = is_dark and icons.mode.dark or icons.mode.light,
        color = is_dark and colors.yellow or colors.blue,
      },
    }
  end)
end)

mode:subscribe("mouse.clicked", function()
  sbar.exec "osascript -e 'tell application \"System Events\" to tell appearance preferences to set dark mode to not dark mode'"
  -- quick update for the mode icon itself (re-reads current state)
  sbar.delay(0.12, function()
    sbar.trigger "forced"
  end)
  -- longer delay + sleep before reloads: gives the system prefs time to settle so colors.lua detection (osascript/defaults) sees the new mode.
  -- This reloads both bars so they re-require colors.lua and get correct Mocha/Latte palette + ws etc.
  sbar.delay(0.55, function()
    -- use the same bare commands as skhdrc / flashspace for controlling the two instances
    sbar.exec("sleep 0.3; sketchybar --reload && sketchybar-top --reload >/dev/null 2>&1 &")
    sbar.exec("pkill -x borders 2>/dev/null; sleep 0.1; $HOME/.config/borders/bordersrc >/dev/null 2>&1 &")
  end)
end)
