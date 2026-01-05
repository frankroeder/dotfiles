local colors = require("colors")
local icons = require("icons")

local mic = sbar.add("item", "widgets.mic", {
  position = "right",
  icon = {
    string = icons.mic.on,
    color = colors.white,
  },
  label = { drawing = false },
  update_freq = 10,
})

local function update_mic()
  sbar.exec("osascript -e 'input volume of (get volume settings)'", function(vol)
    local volume = tonumber(vol) or 0
    local is_muted = volume == 0
    mic:set({
      icon = {
        string = is_muted and icons.mic.off or icons.mic.on,
        color = is_muted and colors.red or colors.white,
      }
    })
  end)
end

mic:subscribe({"routine", "system_woke"}, update_mic)

mic:subscribe("mouse.clicked", function()
  sbar.exec("osascript -e 'set volume input volume (if input volume of (get volume settings) is 0 then 75 else 0)'", function()
    sbar.delay(0.1, update_mic)
  end)
end)

update_mic()
