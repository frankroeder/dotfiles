-- Taken from: https://github.com/realprogrammersusevim/dotfiles/blob/main/sketchybar/items/animator.lua
local settings = require "settings"
local colors = require "colors"

-- Add custom events
sbar.add("event", "lock", "com.apple.screenIsLocked")
sbar.add("event", "unlock", "com.apple.screenIsUnlocked")

-- Create the animator item (hidden, just for logic)
local animator = sbar.add("item", "animator", {
  drawing = false,
  updates = true,
})

-- Lock animation: hide the bar
animator:subscribe("lock", function()
  sbar.bar {
    y_offset = -32,
    margin = -200,
    notch_width = 0,
    blur_radius = 0,
    color = 0x00000000, -- Fully transparent
  }
end)

-- Unlock animation: restore the bar
animator:subscribe("unlock", function()
  sbar.animate("sin", 25, function()
    sbar.bar {
      y_offset = 0,
      margin = settings.bar_margin,
      color = settings.bar_color,
    }
  end)
end)
