local colors = require("colors")
local icons = require("icons")
local settings = require("settings")

local reminders = sbar.add("item", "widgets.reminders", {
  position = "right",
  update_freq = 180,
  icon = {
    string = icons.reminder,
    color = colors.blue,
    padding_left = 8,
    font = {
      style = "Regular",
      size = 16.0,
    },
  },
  label = {
    string = "?",
    font = {
      style = settings.font.style_map["Bold"],
      size = 14.0,
    },
    padding_right = 8,
    color = colors.white,
  },
})

reminders:subscribe({"routine", "system_woke"}, function()
  sbar.exec([[osascript -e 'tell application "Reminders"
    set today to current date
    set overdue to count (reminders whose due date is less than today and completed is false)
    return overdue
  end tell']], function(count)
    local reminder_count = tonumber(count) or 0
    if reminder_count > 0 then
      reminders:set({
        label = { string = tostring(reminder_count) },
        drawing = true,
      })
    else
      reminders:set({ drawing = false })
    end
  end)
end)

reminders:subscribe("mouse.clicked", function()
  sbar.exec("open -a Reminders")
end)
