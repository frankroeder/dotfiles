local colors = require "colors"
local icons = require "icons"
local settings = require "settings"
local ui = require "ui"

-- Only kill caffeinate on bar exit if this widget started it.
local started_by_us = false
local was_running = false

local coffee = ui.add_capsule("widgets.coffee", {
  position = "left",
  update_freq = 60,
  -- Fixed centered icon box (zero paddings) so the glyph sits dead-centre.
  icon = {
    string = icons.coffee.off,
    color = colors.grey,
    width = 30,
    align = "center",
    padding_left = 0,
    padding_right = 0,
    font = {
      style = settings.font.style_map["Regular"],
      size = 16.0,
    },
  },
  label = { drawing = false },
})

local function update_coffee()
  sbar.exec("pgrep -x caffeinate", function(pid)
    local running = pid ~= ""
    if running then
      coffee:set {
        background = ui.capsule(),
        icon = { string = icons.coffee.on, color = colors.yellow },
      }
    else
      -- Clear ownership only after a seen-running → stopped transition (avoids
      -- click-start race where pgrep is still empty while started_by_us is true).
      if was_running then
        started_by_us = false
      end
      coffee:set {
        background = ui.capsule(),
        icon = { string = icons.coffee.off, color = colors.grey },
      }
    end
    was_running = running
  end)
end

coffee:subscribe({ "routine", "deferred_wake", "theme_colors_updated" }, update_coffee)

coffee:subscribe("mouse.clicked", function()
  sbar.exec("pgrep -x caffeinate", function(pid)
    if pid ~= "" then
      started_by_us = false
      sbar.exec "killall caffeinate"
    else
      started_by_us = true
      sbar.exec "caffeinate -d -i &"
    end
    sbar.delay(0.5, update_coffee)
  end)
end)

coffee:subscribe("exit", function()
  if started_by_us then
    sbar.exec "killall caffeinate 2>/dev/null"
  end
end)

update_coffee()
