local colors = require "colors"
local settings = require "settings"
local app_icons = require "helpers.app_icons"

local LARGE_SCREEN_WIDTH = 2000

local front_app = sbar.add("item", "widgets.front_app", {
  display = "active",
  position = "left",
  padding_left = 60,
  icon = {
    background = {
      drawing = true,
      image = {
        -- corner_radius = 5,
        -- padding_left = 4,
        scale = 1.1,
      },
    },
    -- font = "sketchybar-app-font:Regular:22.0",
  },
  label = {
    -- align = "center",
    padding_left = 10,
    padding_right = 10,
    font = {
      style = settings.font.style_map["Bold"],
      size = 16.0,
    },
  },
  background = {
    drawing = false,
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
        background = { drawing = false },
        font = "sketchybar-app-font:Regular:22.0",
      },
    }
  end)
end)
