local colors = require("colors")
local icons = require("icons")
local settings = require("settings")

local timer_active = false
local remaining_time = 0
local default_duration = 25 * 60
local sounds_path = "/System/Library/PrivateFrameworks/ScreenReader.framework/Versions/A/Resources/Sounds/"

local timer = sbar.add("item", "widgets.timer", {
  position = "right",
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
  }
})

local function stop_timer()
  timer_active = false
  remaining_time = 0
  timer:set({ label = { string = "No Timer" } })
  sbar.exec("afplay " .. sounds_path .. "TrackingOff.aiff")
end

local function start_timer(duration)
  timer_active = true
  remaining_time = duration
  sbar.exec("afplay " .. sounds_path .. "TrackingOn.aiff")
end

timer:subscribe("routine", function()
  if timer_active then
    if remaining_time > 0 then
      local minutes = math.floor(remaining_time / 60)
      local seconds = remaining_time % 60
      timer:set({
        label = { string = string.format("%02d:%02d", minutes, seconds) }
      })
      remaining_time = remaining_time - 1
    else
      timer_active = false
      timer:set({ label = { string = "Done" } })
      sbar.exec("afplay " .. sounds_path .. "GuideSuccess.aiff")
      sbar.exec("osascript -e 'display notification \"Timer Finished\" with title \"Sketchybar Timer\"'")
    end
  end
end)

timer:subscribe("mouse.clicked", function(env)
  if env.BUTTON == "left" then
    if timer_active then
      stop_timer()
    else
      start_timer(default_duration)
    end
  elseif env.BUTTON == "right" then
    stop_timer()
  end
end)

timer:subscribe("mouse.entered", function()
  timer:set({ popup = { drawing = true } })
end)

timer:subscribe("mouse.exited", function()
  timer:set({ popup = { drawing = false } })
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
    timer:set({ popup = { drawing = false } })
  end)
end

create_timer_option(5)
create_timer_option(10)
create_timer_option(25)
create_timer_option(50)