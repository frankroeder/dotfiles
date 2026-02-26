local colors = require "colors"
local settings = require "settings"
local app_icons = require "helpers.app_icons"
local ui = require "ui"

local LARGE_SCREEN_WIDTH = settings.large_screen_width

local front_app = sbar.add("item", "widgets.front_app", {
  display = "active",
  position = "left",
  icon = {
    color = settings.theme.text_primary,
    padding_left = 10,
    padding_right = 2,
  },
  label = {
    padding_left = 8,
    padding_right = 10,
    font = {
      style = settings.font.style_map["Semibold"],
      size = 15.0,
    },
  },
  background = ui.capsule {
    color = settings.theme.surface_alt,
    border_color = colors.with_alpha(settings.theme.accent, 0.42),
  },
  click_script = "open -a 'Mission Control'",
  updates = true,
})

-- State to track if the built-in display is the primary (Main) display
local function update_position()
  sbar.exec("yabai -m query --displays --display", function(display)
    if not display then
      return
    end
    local w = display.frame and display.frame.w
    if w then
      if w > LARGE_SCREEN_WIDTH then
        front_app:set { position = "center" }
      else
        front_app:set { position = "left" }
      end
    end
  end)
end

front_app:subscribe("front_app_switched", function(env)
  update_position()

  local lookup = app_icons[env.INFO]
  local icon = lookup or app_icons["Default"] or "󰣆"

  sbar.animate("tanh", 30, function()
    front_app:set {
      label = { string = env.INFO },
      icon = {
        string = icon,
        color = settings.theme.text_primary,
        font = "sketchybar-app-font:Regular:22.0",
      },
    }
  end)
end)
