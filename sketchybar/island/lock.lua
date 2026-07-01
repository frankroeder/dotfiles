local motion = require "motion"
local settings = require "settings"

local SLIDE_FRAMES = 20
local visible = { y_offset = settings.island.y_offset_idle }
local hidden = { y_offset = -60 }

local lock_event = sbar.add("event", "lock", "com.apple.screenIsLocked")
local unlock_event = sbar.add("event", "unlock", "com.apple.screenIsUnlocked")

local is_hidden = false

local function slide(props)
  motion.animate_bar(props, SLIDE_FRAMES)
end

local animator = sbar.add("item", "island.lock", { drawing = false })

animator:subscribe(lock_event.name, function()
  is_hidden = true
  slide(hidden)
end)

animator:subscribe(unlock_event.name, function()
  is_hidden = false
  slide(visible)
end)