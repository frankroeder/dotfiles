local bar_config = require "bar_config"
local motion = require "motion"

local SLIDE_FRAMES = 20
local WAKE_DELAY = SLIDE_FRAMES / 60

local hidden = { y_offset = -20, margin = -30 }

sbar.add("event", "deferred_wake")

local lock_event = sbar.add("event", "lock", "com.apple.screenIsLocked")
local unlock_event = sbar.add("event", "unlock", "com.apple.screenIsUnlocked")

local is_hidden = false
local wake_handled = false
local wake_scheduled = false

local function slide(props)
  motion.animate_bar(props, SLIDE_FRAMES)
end

-- Belt for the CVDisplayLink wedge: sketchybar animations (and sbar.delay,
-- which rides the same tick) freeze system-wide when CoreVideo's display
-- state is wedged by a lock/unlock — the slide-in then never runs and the bar
-- stays parked off-screen ("bars disappeared"). Verify via an exec callback
-- (process-exit driven, independent of the display link) and snap un-animated
-- if the bar is still below rest.
local function ensure_rest_after(delay)
  sbar.exec("sleep " .. delay, function()
    if is_hidden then
      return
    end
    local info = sbar.query "bar"
    local y = info and tonumber(info.y_offset)
    local rest_y = bar_config.rest_geometry().y_offset or 0
    if y and y < rest_y - 5 then
      bar_config.bar(bar_config.rest_geometry())
    end
  end)
end

local function defer_widgets()
  if wake_scheduled then
    return
  end
  wake_scheduled = true
  sbar.delay(WAKE_DELAY, function()
    wake_scheduled = false
    sbar.trigger "deferred_wake"
  end)
end

-- Recover after reload if the C bar is still slid off-screen. Must not
-- `--query` during begin_config (deadlocks the mach transaction).
sbar.delay(0.25, function()
  local info = sbar.query "bar"
  local y = info and tonumber(info.y_offset)
  if y and y < -10 then
    is_hidden = true
    slide(bar_config.rest_geometry())
    is_hidden = false
  end
end)

local animator = sbar.add("item", "animator", { drawing = false })

animator:subscribe(lock_event.name, function()
  is_hidden = true
  wake_handled = false
  slide(hidden)
end)

-- system_woke arrives before unlock; slide in early and defer widget refreshes.
animator:subscribe("system_woke", function()
  defer_widgets()
  if not is_hidden then
    return
  end
  is_hidden = false
  wake_handled = true
  slide(bar_config.rest_geometry())
  ensure_rest_after(1)
end)

animator:subscribe(unlock_event.name, function()
  defer_widgets()
  if wake_handled then
    wake_handled = false
    return
  end
  if not is_hidden then
    bar_config.bar(hidden)
  end
  is_hidden = false
  slide(bar_config.rest_geometry())
  ensure_rest_after(1)
end)