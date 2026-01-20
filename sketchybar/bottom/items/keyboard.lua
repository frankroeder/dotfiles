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
    "plutil -convert json -o - "
      .. os.getenv "HOME"
      .. "/Library/Preferences/com.apple.HIToolbox.plist",
    function(data)
      if not data or not data.AppleSelectedInputSources then
        return
      end
      for _, source in ipairs(data.AppleSelectedInputSources) do
        if source["KeyboardLayout Name"] then
          keyboard:set { label = { string = source["KeyboardLayout Name"] } }
          return
        end
      end
    end
  )
end

keyboard:subscribe("keyboard_change", update_keyboard)
keyboard:subscribe("system_woke", update_keyboard)

update_keyboard()
