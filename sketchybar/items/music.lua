local whitelist = { ["Spotify"] = true, ["Music"] = true }
local colors = require "colors"
local settings = require "settings"

sbar.exec("aerospace list-monitors --count", function(num_spaces)
  local media = sbar.add("item", {
    drawing = false,
    display = num_spaces,
    icon = {
      font = "sketchybar-app-font:Regular:16.0",
      string = ":music:",
      padding_left = 8,
    },
    label = {
      padding_right = 8,
      max_chars = 40 * num_spaces,
      scroll_duration = 1400,
      font = {
        size = 14.0,
      },
    },
    position = "center",
    updates = true,
    background = {
      color = colors.lightblack,
      padding_left = 2,
      padding_right = 2,
    },
  })

  media:subscribe("media_change", function(env)
    if whitelist[env.INFO.app] then
      local display_text = env.INFO.artist .. " - " .. env.INFO.title
      sbar.animate("tanh", settings.animation_duration * 2, function()
        media:set {
          drawing = (env.INFO.state == "playing"),
          label = {
            string = display_text,
          },
        }
      end)
    end
  end)
end)
