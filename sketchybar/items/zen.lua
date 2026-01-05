local colors = require("colors")
local icons = require("icons")

local zen = sbar.add("item", "widgets.zen", {
  position = "right",
  icon = {
    string = icons.zen,
    color = colors.grey,
    padding_left = 8,
    padding_right = 8,
    font = {
      style = "Regular",
      size = 16.0,
    },
  },
  label = { drawing = false },
})

local is_zen = false

zen:subscribe("mouse.clicked", function()
  is_zen = not is_zen
  local gap = is_zen and 0 or 10
  local padding = is_zen and 0 or 20
  
  local color = is_zen and colors.red or colors.grey
  
  sbar.exec("yabai -m config window_gap " .. gap)
  sbar.exec("yabai -m config top_padding " .. padding)
  sbar.exec("yabai -m config bottom_padding " .. padding)
  sbar.exec("yabai -m config left_padding " .. padding)
  sbar.exec("yabai -m config right_padding " .. padding)
  sbar.exec("sketchybar --bar hidden=" .. (is_zen and "on" or "off"))
  
  zen:set({
    icon = { color = color }
  })
end)
