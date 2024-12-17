local whitelist = { ["Spotify"] = true, ["Music"] = true }
local colors = require "colors"

local media = sbar.add("item", {
  icon = {
    font = "sketchybar-app-font:Regular:16.0",
    string = ":music:",
    padding_left = 8,
  },
  label = {
    padding_right = 8,
    font = {
      size = 14.0,
    },
  },
  position = "center",
  updates = true,
  background = {
    color = colors.lightblack,
  },
})

media:subscribe("media_change", function(env)
  if whitelist[env.INFO.app] then
    media:set {
      drawing = (env.INFO.state == "playing"),
      label = {
        string = env.INFO.artist .. " - " .. env.INFO.title,
      },
    }
  end
end)
