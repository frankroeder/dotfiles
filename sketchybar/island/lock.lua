local display = require "display"
local island_style = require "island_style"

local lock_event = sbar.add("event", "lock", "com.apple.screenIsLocked")
local unlock_event = sbar.add("event", "unlock", "com.apple.screenIsUnlocked")

local animator = sbar.add("item", "island.lock", { drawing = false })

animator:subscribe(lock_event.name, function()
  local core = package.loaded["island_core"]
  if core and core.force_hide then
    core.force_hide()
    return
  end
  -- Fallback before island_core loads.
  sbar.bar {
    hidden = true,
    y_offset = island_style.y_offset_idle(display.focused_index()),
  }
end)

animator:subscribe(unlock_event.name, function()
  local core = package.loaded["island_core"]
  if core and core.on_unlock then
    core.on_unlock()
    return
  end
  sbar.bar {
    hidden = true,
    y_offset = island_style.y_offset_idle(display.focused_index()),
  }
end)
