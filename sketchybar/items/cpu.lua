local icons = require "icons"
local colors = require "colors"
local settings = require "settings"

-- Execute the event provider binary which provides the event "cpu_update" for
-- the cpu load data, which is fired every 2.0 seconds.
sbar.exec "killall cpu_load >/dev/null; $CONFIG_DIR/helpers/event_providers/cpu_load/bin/cpu_load cpu_update 2.0"

local cpu = sbar.add("graph", "widgets.cpu", 80, {
  position = "right",
  graph = { color = colors.green },
  background = {
    height = 22,
    color = { alpha = 0 },
    border_color = { alpha = 0 },
    drawing = true,
  },
  icon = { string = icons.cpu },
  label = {
    string = "CPU ??%",
    font = {
      family = settings.font.text,
      style = settings.font.style_map["Bold"],
      size = 12.0,
    },
    align = "right",
    padding_right = 10,
    width = 0,
    y_offset = 4,
  },
  padding_right = settings.paddings + 6,
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
    graph = { color = color },
    label = "CPU " .. env.total_load .. "%",
  }
end)

cpu:subscribe("mouse.clicked", function(env)
  sbar.exec "open -a 'Activity Monitor'"
end)

-- Background around the cpu item
sbar.add("item", "widgets.cpu.padding", {
  position = "right",
  width = settings.group_paddings,
})
