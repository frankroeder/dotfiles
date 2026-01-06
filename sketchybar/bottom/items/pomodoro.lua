local colors = require "colors"
local icons = require "icons"
local settings = require "settings"

local timer_state = "stopped" -- stopped, running, finished
local remaining_time = 0
local alert_rings = 0
local max_rings = 5
local sounds_path =
  "/System/Library/PrivateFrameworks/ScreenReader.framework/Versions/A/Resources/Sounds/"

local timer = sbar.add("item", "widgets.timer", {
  position = "left",
  update_freq = 1,
  icon = {
    string = "􀐱",
    color = colors.yellow,
    padding_left = 8,
  },
  label = {
    string = "No Timer",
    padding_right = 8,
  },
  popup = {
    align = "center",
  },
})

local function stop_timer()
  timer_state = "stopped"
  remaining_time = 0
  alert_rings = 0
  timer:set { label = { string = "No Timer" }, icon = { color = colors.yellow } }
  sbar.exec("afplay " .. sounds_path .. "TrackingOff.aiff")
end

local function start_timer(duration)
  timer_state = "running"
  remaining_time = duration
  alert_rings = 0
  timer:set { icon = { color = colors.green } }
  sbar.exec("afplay " .. sounds_path .. "TrackingOn.aiff")
end

timer:subscribe("routine", function()
  if timer_state == "running" then
    if remaining_time > 0 then
      local minutes = math.floor(remaining_time / 60)
      local seconds = remaining_time % 60
      timer:set {
        label = { string = string.format("%02d:%02d", minutes, seconds) },
      }
      remaining_time = remaining_time - 1
    else
      timer_state = "finished"
      timer:set { label = { string = "Done!" }, icon = { color = colors.red } }
      sbar.exec 'osascript -e \'display notification "Timer Finished" with title "Sketchybar Timer"\''
    end
  elseif timer_state == "finished" then
    if alert_rings < max_rings then
      sbar.exec("afplay " .. sounds_path .. "GuideSuccess.aiff")
      alert_rings = alert_rings + 1
      -- We use routine frequency (1s) to ring every couple of seconds
      -- But afplay is blocking or we can just ring every routine tick if we want it annoying
      -- Let's ring every 3 seconds
      if alert_rings < max_rings then
        -- wait 2 more routine ticks before next ring
        timer_state = "alerting"
      end
    end
  elseif timer_state == "alerting" then
    remaining_time = remaining_time + 1
    if remaining_time >= 3 then
      remaining_time = 0
      timer_state = "finished"
    end
  end
end)

timer:subscribe("mouse.clicked", function(env)
  if env.BUTTON == "left" then
    if timer_state ~= "stopped" then
      stop_timer()
    end
    timer:set { popup = { drawing = "toggle" } }
  elseif env.BUTTON == "right" then
    stop_timer()
  end
end)

timer:subscribe("mouse.exited.global", function()
  timer:set { popup = { drawing = false } }
end)

local function create_timer_option(minutes)
  local duration = minutes * 60
  local option = sbar.add("item", "widgets.timer." .. minutes, {
    position = "popup." .. timer.name,
    label = {
      string = minutes .. " Minutes",
      padding_left = 10,
      padding_right = 10,
    },
  })

  option:subscribe("mouse.clicked", function()
    start_timer(duration)
    timer:set { popup = { drawing = false } }
  end)
end

create_timer_option(5)
create_timer_option(10)
create_timer_option(25)
create_timer_option(50)
