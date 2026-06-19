local colors = require "colors"
local icons = require "icons"
local settings = require "settings"
local ui = require "ui"

local timer_state = "stopped"
local remaining_time = 0
local remaining_rings = 0
local ring_cooldown = 0
local sounds_path = settings.sounds.path

local timer = ui.add_capsule("widgets.timer", {
  position = "left",
  update_freq = 1,
  icon = {
    string = icons.timer,
    color = colors.yellow,
    padding_left = 4,
    padding_right = 2,
  },
  label = { string = "-" },
  popup = { align = "center" },
})

local function stop_timer()
  timer_state = "stopped"
  remaining_time = 0
  remaining_rings = 0
  ring_cooldown = 0
  timer:set { label = { string = "No Timer" }, icon = { color = colors.yellow } }
  sbar.exec("afplay " .. sounds_path .. "TrackingOff.aiff")
end

local function start_timer(duration)
  timer_state = "running"
  remaining_time = duration
  remaining_rings = 0
  ring_cooldown = 0
  timer:set { icon = { color = colors.green } }
  sbar.exec("afplay " .. sounds_path .. "TrackingOn.aiff")
end

timer:subscribe("routine", function()
  if timer_state == "running" then
    if remaining_time > 0 then
      local minutes = math.floor(remaining_time / 60)
      local seconds = remaining_time % 60
      timer:set { label = { string = string.format("%02d:%02d", minutes, seconds) } }
      remaining_time = remaining_time - 1
    else
      timer_state = "finished"
      remaining_rings = 5
      ring_cooldown = 0
      timer:set { label = { string = "Done!" }, icon = { color = colors.red } }
      sbar.exec 'osascript -e "display notification "Timer Finished" with title "Sketchybar Timer""'
    end
  elseif timer_state == "finished" and remaining_rings > 0 then
    ring_cooldown = ring_cooldown + 1
    if ring_cooldown >= 3 then
      ring_cooldown = 0
      remaining_rings = remaining_rings - 1
      sbar.exec("afplay " .. sounds_path .. "GuideSuccess.aiff")
    end
  end
end)

local function create_timer_option(minutes)
  local duration = minutes * 60
  local option = ui.popup_button("widgets.timer." .. minutes, timer, {
    label = minutes .. " Minutes",
  })

  option:subscribe("mouse.clicked", function()
    start_timer(duration)
    timer:set { popup = { drawing = false } }
  end)
end

ui.bind_popup(timer, { on_right = stop_timer })

create_timer_option(5)
create_timer_option(10)
create_timer_option(25)
create_timer_option(50)
