local icons = require "icons"
local colors = require "colors"

-- Execute the event provider binary which provides the event "cpu_update" for
-- the cpu load data, which is fired every 2.0 seconds.
sbar.exec "pgrep -x cpu_load > /dev/null && killall cpu_load; /Users/frankroeder/.dotfiles/sketchybar/helpers/event_providers/cpu_load/bin/cpu_load cpu_update 2.0"

local cpu = sbar.add("graph", "widgets.cpu", 80, {
  position = "right",
  icon = {
    string = icons.cpu,
    padding_left = 4,
    y_offset = 2,
  },
  label = {
    string = "CPU ??%",
    font = {
      size = 10.0,
    },
    align = "right",
    width = 0,
    padding_right = 18,
    y_offset = 8,
  },
  background = {
    drawing = true,
  },
})

cpu:subscribe("cpu_update", function(env)
  local load = tonumber(env.total_load)
  local status_load = env.total_load
  if load < 0 then
    status_load = "0"
    load = 0
  end
  if load <= 100 then
    cpu:push { load / 100. }

    local color = colors.blue
    if load > 30 then
      if load < 60 then
        color = colors.yellow
      elseif load < 80 then
        color = colors.orange
      else
        color = colors.red
      end
    end

    cpu:set {
      graph = { color = color, line_width = 1 },
      label = "CPU " .. status_load .. "%",
    }
  end
end)

cpu:subscribe("mouse.clicked", function(_)
  sbar.exec "open -a 'Activity Monitor'"
end)
