local colors = require "colors"
local icons = require "icons"
local settings = require "settings"
local ui = require "ui"

local mode = ui.add_capsule("widgets.mode", {
  position = "left",
  icon = {
    string = icons.mode.dark,
    color = colors.yellow,
    font = {
      style = settings.font.style_map["Regular"],
      size = 16.0,
    },
  },
  label = { drawing = false },
})

mode:subscribe({ "routine", "system_woke", "forced" }, function()
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
  sbar.delay(0.12, function()
    sbar.trigger "forced"
  end)
  sbar.delay(0.55, function()
    sbar.exec("sleep 0.3; sketchybar --reload && sketchybar-top --reload >/dev/null 2>&1 &")
    sbar.exec("pkill -x borders 2>/dev/null; sleep 0.1; $HOME/.config/borders/bordersrc >/dev/null 2>&1 &")
  end)
end)
