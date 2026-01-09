local colors = require "colors"
local settings = require "settings"
local icons = require "icons"

sbar.add("event", "keyboard_change", "AppleSelectedInputSourcesChangedNotification")

local keyboard = sbar.add("item", "widgets.keyboard", {
  position = "left",
  icon = {
    string = icons.keyboard,
    padding_left = 8,
  },
  label = {
    font = {
      style = settings.font.style_map["Semibold"],
      size = 14.0,
    },
    padding_right = 8,
    padding_left = 8,
  },
})

local function update_keyboard()
  sbar.exec(
    [[defaults read ~/Library/Preferences/com.apple.HIToolbox.plist AppleSelectedInputSources | grep "KeyboardLayout Name" | cut -c 33- | rev | cut -c 2- | rev]],
    function(layout)
      keyboard:set { label = { string = layout:gsub("\n", "") } }
    end
  )
end

keyboard:subscribe("keyboard_change", update_keyboard)
keyboard:subscribe("system_woke", update_keyboard)

update_keyboard()
