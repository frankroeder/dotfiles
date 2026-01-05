local colors = require "colors"
local icons = require "icons"

sbar.exec "killall memory_load >/dev/null; /Users/frankroeder/.dotfiles/sketchybar/helpers/event_providers/memory_load/bin/memory_load memory_update 2.0"

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
    drawing = true,
  },
})

local ram_popup = sbar.add("item", {
  position = "popup." .. ram_g.name,
  label = {
    font = { size = 12.0 },
    string = "Checking memory pressure...",
  },
})

ram_g:subscribe("mouse.clicked", function()
  ram_g:set { popup = { drawing = "toggle" } }
  sbar.exec("memory_pressure | tail -n 3", function(pressure)
    ram_popup:set { label = { string = pressure } }
  end)
end)

ram_g:subscribe("mouse.exited.global", function()
  ram_g:set { popup = { drawing = false } }
end)
