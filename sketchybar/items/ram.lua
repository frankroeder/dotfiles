local colors = require "colors"
local icons = require "icons"

sbar.exec "killall memory_load >/dev/null; $CONFIG_DIR/helpers/event_providers/memory_load/bin/memory_load memory_update 2.0"

local ram_g = sbar.add("graph", "widgets.ram", 80, {
  position = "right",
  icon = {
    string = icons.ram,
    padding_left = 4,
    y_offset = 2,
  },
  label = {
    string = "RAM ??%",
    font = {
      size = 10.0,
    },
    align = "right",
    width = 0,
    padding_right = 18,
    y_offset = 8,
  },
  background = {
    color = colors.transparent,
  },
})

ram_g:subscribe("memory_update", function(env)
  local usedram = tonumber(env.memory_load:match "(%d+)")
  -- update graph with normalized usage
  ram_g:push { usedram / 100 }

  -- color-code memory usage levels
  local color = colors.white
  if usedram >= 80 then
    color = colors.red
  elseif usedram >= 60 then
    color = colors.orange
  elseif usedram >= 30 then
    color = colors.yellow
  end
  -- display percentage with consistent label
  ram_g:set {
    graph = { color = color, line_width = 1 },
    label = "RAM " .. env.memory_load,
  }
end)
