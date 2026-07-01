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
    background = ui.capsule(),
    icon = {
      string = is_dark and icons.mode.light or icons.mode.dark,
      color = is_dark and colors.blue or colors.yellow,
    },
  }
end

mode:subscribe("theme_colors_updated", function()
  apply_mode(colors.is_dark)
end)

apply_mode(colors.is_dark)

mode:subscribe("mouse.clicked", function()
  sbar.exec "osascript -e 'tell application \"System Events\" to tell appearance preferences to set dark mode to not dark mode'"
end)
