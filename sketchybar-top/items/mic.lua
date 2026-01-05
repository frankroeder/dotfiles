local colors = require("colors")
local icons = require("icons")
local settings = require("settings")

local mic = sbar.add("item", "top.widgets.mic", {
  position = "right",
  icon = {
    string = icons.mic.on,
    color = colors.white,
    padding_left = 8,
    font = {
      style = "Regular",
      size = 16.0,
    },
  },
  label = {
    string = "??%",
    font = {
      style = settings.font.style_map["Bold"],
      size = 14.0,
    },
    padding_right = 8,
    color = colors.white,
  },
})

local function update_mic()
  sbar.exec("osascript -e 'input volume of (get volume settings)'", function(vol)
    local volume_level = tonumber(vol)
    local icon = icons.mic.on
    local color = colors.white
    
    if volume_level == 0 then
        icon = icons.mic.off
        color = colors.red
    end

    mic:set({
      icon = { string = icon, color = color },
      label = { string = volume_level .. "%" }
    })
  end)
end

mic:subscribe({"routine", "volume_change", "system_woke"}, update_mic)
update_mic()

mic:subscribe("mouse.clicked", function()
  sbar.exec("osascript -e 'set volume input volume 0'", function() update_mic() end)
end)
