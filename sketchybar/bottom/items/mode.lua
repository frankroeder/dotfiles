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

local function apply_mode(is_dark)
  -- In light mode show moon (to switch to dark); in dark mode show sun (to switch to light)
  mode:set {
    icon = {
      string = is_dark and icons.mode.light or icons.mode.dark,
      color = is_dark and colors.blue or colors.yellow,
    },
  }
end

local function refresh_mode()
  sbar.exec(
    [[osascript -e 'tell application "System Events" to tell appearance preferences to return dark mode' 2>/dev/null || echo false]],
    function(result)
      local is_dark = (result or ""):lower():match "true" ~= nil
      apply_mode(is_dark)
    end
  )
end

mode:subscribe({ "system_woke", "forced" }, refresh_mode)

mode:subscribe("theme_change", function()
  -- on system theme change, reload bars to pick up fresh colors from colors.lua (like manual toggle)
  sbar.delay(0.1, function()
    sbar.exec "sketchybar --reload && sketchybar-top --reload >/dev/null 2>&1 &"
    sbar.exec "pkill -x borders 2>/dev/null; sleep 0.1; $HOME/.config/borders/bordersrc >/dev/null 2>&1 &"
  end)
end)

-- immediate query so correct icon shows at bar start (routine may lag; colors.is_dark can be stale)
refresh_mode()

mode:subscribe("mouse.clicked", function()
  sbar.exec "osascript -e 'tell application \"System Events\" to tell appearance preferences to set dark mode to not dark mode'"
  sbar.delay(0.12, function()
    sbar.trigger "forced"
  end)
  sbar.delay(0.55, function()
    sbar.exec "sleep 0.3; sketchybar --reload && sketchybar-top --reload >/dev/null 2>&1 &"
    sbar.exec "pkill -x borders 2>/dev/null; sleep 0.1; $HOME/.config/borders/bordersrc >/dev/null 2>&1 &"
  end)
end)
