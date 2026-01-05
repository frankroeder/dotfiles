local colors = require("colors")
local icons = require("icons")

local mode = sbar.add("item", "widgets.mode", {
  position = "right",
  icon = {
    string = icons.mode.dark,
    color = colors.yellow,
    padding_left = 8,
    padding_right = 8,
    font = {
      style = "Regular",
      size = 16.0,
    },
  },
  label = { drawing = false },
})

mode:subscribe({"routine", "system_woke", "forced"}, function()
  sbar.exec("defaults read -g AppleInterfaceStyle", function(style)
    local is_dark = style == "Dark\n" or style == "Dark"
    mode:set({
      icon = {
        string = is_dark and icons.mode.dark or icons.mode.light,
        color = is_dark and colors.yellow or colors.blue,
      }
    })
  end)
end)

mode:subscribe("mouse.clicked", function()
  sbar.exec("osascript -e 'tell application \"System Events\" to tell appearance preferences to set dark mode to not dark mode'")
  sbar.delay(0.1, function() sbar.trigger("forced") end)
end)
