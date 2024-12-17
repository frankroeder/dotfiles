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

local function truncate_and_rotate(text, max_length)
  if #text <= max_length then
    return text
  end
  return text:sub(1, max_length) .. "..."
end

media:subscribe("media_change", function(env)
  if whitelist[env.INFO.app] then
    local display_text = env.INFO.artist .. " - " .. env.INFO.title
    media:set {
      drawing = (env.INFO.state == "playing"),
      label = {
        string = truncate_and_rotate(display_text, 60),
      },
    }
  end
end)
