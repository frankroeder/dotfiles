local colors = require("colors")
local icons = require("icons")
local settings = require("settings")

local pomodoro = sbar.add("item", "widgets.pomodoro", {
  position = "right",
  update_freq = 1,
  icon = {
    string = "🍅",
    color = colors.red,
    padding_left = 8,
    font = {
      style = "Regular",
      size = 16.0,
    },
  },
  label = {
    string = "25:00",
    font = {
      style = settings.font.style_map["Bold"],
      size = 14.0,
    },
    padding_right = 8,
    color = colors.white,
  },
  drawing = false,
})

local timer_active = false
local start_time = 0
local duration = 25 * 60

pomodoro:subscribe("routine", function()
  if timer_active then
    local current_time = os.time()
    local elapsed = current_time - start_time
    local remaining = duration - elapsed
    
    if remaining <= 0 then
      timer_active = false
      pomodoro:set({ drawing = false })
      sbar.exec("osascript -e 'display notification \"Pomodoro Finished!\" with title \"Timer\"'")
    else
      local minutes = math.floor(remaining / 60)
      local seconds = remaining % 60
      pomodoro:set({
        label = { string = string.format("%02d:%02d", minutes, seconds) }
      })
    end
  end
end)

pomodoro:subscribe("mouse.clicked", function()
  if timer_active then
    timer_active = false
    pomodoro:set({ drawing = false })
  else
    timer_active = true
    start_time = os.time()
    pomodoro:set({ drawing = true, label = { string = "25:00" } })
  end
end)

-- A trigger item to start the timer
local pomodoro_start = sbar.add("item", "widgets.pomodoro.start", {
  position = "right",
  icon = {
    string = "🍅",
    color = colors.red,
    padding_left = 8,
    padding_right = 8,
    font = {
      size = 16.0,
    },
  },
  label = { drawing = false },
})

pomodoro_start:subscribe("mouse.clicked", function()
  if not timer_active then
    timer_active = true
    start_time = os.time()
    pomodoro:set({ drawing = true, label = { string = "25:00" } })
  else
    -- Stop if clicked again
    timer_active = false
    pomodoro:set({ drawing = false })
  end
end)
