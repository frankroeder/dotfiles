local bar_config = require "bar_config"
local settings = require "settings"
local motion = require "motion"

local SLIDE_FRAMES = 20
local WAKE_DELAY = SLIDE_FRAMES / 60

local unlocked = { y_offset = 0, margin = settings.bar_margin }
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

-- Reload loses lua state; recover if the bar is still off-screen.
do
  local bin = os.getenv "BAR_NAME" == "sketchybar-top" and "/opt/homebrew/bin/sketchybar-top"
    or "/opt/homebrew/bin/sketchybar"
  local f = io.popen(bin .. " -m --query bar 2>/dev/null")
  if f then
    local out = f:read "*a" or ""
    f:close()
    if (tonumber(out:match '"y_offset":%s*(-?%d+)') or 0) < -10 then
      is_hidden = true
    end
  end
end

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
  slide(unlocked)
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
  slide(unlocked)
end)