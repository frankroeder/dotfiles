local colors = require "colors"
local settings = require "settings"

local front_app = sbar.add("item", "top.front_app", {
  display = "active",
  position = "left", -- Default to left
  icon = {
    background = {
      drawing = true,
      image = {
        corner_radius = 5,
        padding_left = 4,
        scale = 1.0,
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
    drawing = false
  },
  click_script = "open -a 'Mission Control'",
  updates = true,
})

-- State to track if the built-in display is the primary (Main) display
local function update_position()
  sbar.exec("yabai -m query --displays --display", function(display)
    if not display then return end
    -- display is a table, accessing frame.w directly
    local w = display.frame and display.frame.w
    if w then
      if w > 2000 then
        front_app:set { position = "center" }
      else
        front_app:set { position = "left" }
      end
    end
  end)
end

front_app:subscribe("front_app_switched", function(env)
  update_position() -- Check position whenever app switches (often implies display focus change)
  sbar.animate("tanh", 20, function()
    front_app:set {
      label = { string = env.INFO },
      icon = { background = { image = { string = "app." .. env.INFO } } },
    }
  end)
end)

front_app:subscribe({ "display_change" }, function()
  update_position()
end)

front_app:subscribe({ "window_focus" }, function()
  update_position()
end)

update_position()
