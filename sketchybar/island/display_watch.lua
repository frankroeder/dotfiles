local display = require "display"

sbar.add("event", "display_change")

local watcher = sbar.add("item", "island.display", { drawing = false, updates = true })

watcher:subscribe("display_change", function()
  sbar.bar { display = display.builtin_index }
end)