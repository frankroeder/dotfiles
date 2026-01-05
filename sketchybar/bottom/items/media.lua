local colors = require "colors"
local settings = require "settings"
local app_icons = require "helpers.app_icons"

sbar.add("event", "music_change", "com.apple.Music.playerInfo")

local media = sbar.add("item", "widgets.media", {
  drawing = false,
  icon = {
    font = "sketchybar-app-font:Regular:16.0",
    string = "",
    padding_left = 8,
  },
  label = {
    padding_right = 8,
    max_chars = 40,
    scroll_duration = 1400,
    font = {
      size = 14.0,
    },
  },
  position = "center",
  updates = true,
  background = {
    color = colors.bg1,
    border_color = colors.bg2,
    border_width = 1,
    drawing = true,
  },
})

media:subscribe("music_change", function(env)
  if env.INFO then
    local artist = env.INFO.Artist or ""
    local title = env.INFO.Name or ""
    local display_text = artist .. " - " .. title
    sbar.animate("tanh", settings.animation_duration * 2, function()
      media:set {
        drawing = (artist .. title ~= ""),
        label = {
          string = display_text,
        },
        icon = {
          string = app_icons["Music"] or app_icons["Default"],
        },
      }
    end)
  end
end)
