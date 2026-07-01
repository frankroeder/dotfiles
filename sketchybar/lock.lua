local settings = require "settings"

local unlocked = {
  y_offset = 0,
  margin = settings.bar_margin,
}

local hidden = {
  y_offset = -20,
  margin = -30,
}

local lock_event = sbar.add("event", "lock", "com.apple.screenIsLocked")
local unlock_event = sbar.add("event", "unlock", "com.apple.screenIsUnlocked")

local animator = sbar.add("item", "animator", { drawing = false })
animator:subscribe({ lock_event.name, unlock_event.name }, function(env)
  local properties
  if env.SENDER == lock_event.name then
    properties = hidden
  elseif env.SENDER == unlock_event.name then
    -- screenIsLocked is often missed; snap hidden so unlock always slides in
    sbar.bar(hidden)
    properties = unlocked
  end

  sbar.animate("sin", 15, function()
    sbar.bar(properties)
  end)
end)