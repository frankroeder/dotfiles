local colors = require("colors")
local icons = require("icons")
local settings = require("settings")

local downloads = sbar.add("item", "widgets.downloads", {
  position = "right",
  update_freq = 60,
  icon = {
    string = icons.downloads,
    color = colors.blue,
    padding_left = 8,
    font = {
      style = "Regular",
      size = 16.0,
    },
  },
  label = {
    string = "0",
    font = {
      style = settings.font.style_map["Bold"],
      size = 14.0,
    },
    padding_right = 8,
    color = colors.white,
  },
})

downloads:subscribe({"routine", "system_woke"}, function()
  sbar.exec("ls -1 ~/Downloads | wc -l | tr -d ' '", function(count)
    local down_count = tonumber(count) or 0
    if down_count > 0 then
      downloads:set({
        label = { string = tostring(down_count) },
        drawing = true,
      })
    else
      downloads:set({ drawing = false })
    end
  end)
end)

downloads:subscribe("mouse.clicked", function()
  sbar.exec("open ~/Downloads")
end)
