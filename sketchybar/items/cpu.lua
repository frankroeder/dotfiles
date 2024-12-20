local icons = require "icons"
local colors = require "colors"

-- Execute the event provider binary which provides the event "cpu_update" for
-- the cpu load data, which is fired every 2.0 seconds.
sbar.exec "pgrep -x cpu_load > /dev/null && killall cpu_load; $CONFIG_DIR/helpers/event_providers/cpu_load/bin/cpu_load cpu_update 2.0"

local cpu = sbar.add("graph", "widgets.cpu", 80, {
  position = "right",
  background = {
    height = 10,
    color = { alpha = 10 },
  },
  icon = {
    string = icons.cpu,
    padding_left = 4,
  },
  label = {
    string = "CPU ??%",
    font = {
      size = 12.0,
    },
    align = "right",
    width = 0,
    padding_right = 18,
    y_offset = 4,
  },
  -- background = {
  --   color= colors.lightblack
  -- }
})

cpu:subscribe("cpu_update", function(env)
  -- Also available: env.user_load, env.sys_load
  local load = tonumber(env.total_load)
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
    label = "CPU " .. env.total_load .. "%",
  }
end)

cpu:subscribe("mouse.clicked", function(_)
  sbar.exec "open -a 'Activity Monitor'"
end)
