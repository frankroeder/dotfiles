local colors = require "colors"
local icons = require "icons"
local settings = require "settings"
local ui = require "ui"

local coffee = ui.add_capsule("widgets.coffee", {
  position = "left",
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
    if pid ~= "" then
      coffee:set {
        background = ui.capsule(),
        icon = { string = icons.coffee.on, color = colors.yellow },
      }
    else
      coffee:set {
        background = ui.capsule(),
        icon = { string = icons.coffee.off, color = colors.grey },
      }
    end
  end)
end

coffee:subscribe({ "routine", "deferred_wake", "theme_colors_updated" }, update_coffee)

coffee:subscribe("mouse.clicked", function()
  sbar.exec("pgrep -x caffeinate", function(pid)
    if pid ~= "" then
      sbar.exec "killall caffeinate"
    else
      sbar.exec "caffeinate -d -i &"
    end
    sbar.delay(0.5, update_coffee)
  end)
end)

coffee:subscribe("exit", function()
  sbar.exec "killall caffeinate 2>/dev/null"
end)

update_coffee()
