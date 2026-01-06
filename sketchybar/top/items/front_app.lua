local colors = require "colors"
local settings = require "settings"

local front_app = sbar.add("item", "top.front_app", {
  display = "active",
  position = "center",
  icon = {
    background = {
      drawing = true,
      image = {
        corner_radius = 5,
        padding_left = 4,
        scale = 0.8,
      },
    },
    font = "sketchybar-app-font:Regular:22.0",
  },
  label = {
    padding_left = 10,
    padding_right = 10,
    font = {
      style = settings.font.style_map["Bold"],
      size = 16.0,
    },
  },
  background = {
    color = colors.bg1,
    border_color = colors.purple,
    border_width = 0,
  },
  click_script = "open -a 'Mission Control'",
  updates = true,
})

front_app:subscribe("front_app_switched", function(env)
  sbar.animate("tanh", 20, function()
    front_app:set {
      label = { string = env.INFO },
      icon = { background = { image = { string = "app." .. env.INFO } } },
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