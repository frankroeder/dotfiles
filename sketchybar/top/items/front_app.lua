local colors = require "colors"
local settings = require "settings"
local app_icons = require "helpers.app_icons"

local front_app = sbar.add("item", "top.front_app", {
  display = "active",
  position = "center",
  icon = {
    background = {
      image = {
        corner_radius = 5,
        scale = 0.5,
      },
    },
    font = "sketchybar-app-font:Regular:22.0",
  },
  label = {
    padding_left = 4,
    font = {
      style = settings.font.style_map["Bold"],
      size = 18.0,
    },
  },
  background = {
    color = colors.bg1,
    border_color = colors.bg2,
    border_width = 1,
  },
  updates = true,
})

front_app:subscribe("front_app_switched", function(env)
  local lookup = app_icons[env.INFO]
  local icon = ((lookup == nil) and app_icons["Default"] or lookup)
  sbar.animate("tanh", 20, function()
    front_app:set {
      label = { string = env.INFO },
      icon = { string = icon },
    }
  end)
end)

local window_title = sbar.add("item", "top.window_title", {
  display = "active",
  position = "left",
  background = {
    color = colors.bg1,
    border_color = colors.bg2,
    border_width = 1,
  },
  label = {
    font = {
      size = 14.0,
    },
    max_chars = 50,
    scroll_duration = 100,
  },
})

window_title:subscribe("window_focus", function(env)
  sbar.exec("yabai -m query --windows --window | jq -r '.title'", function(title)
    if title == "null" or title == "" then
      title = ""
    end
    window_title:set { label = { string = title } }
  end)
end)
