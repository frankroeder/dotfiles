local colors = require("colors")
local icons = require("icons")
local settings = require("settings")

local volume = sbar.add("item", "top.widgets.volume", {
  position = "right",
  icon = {
    string = icons.volume[100],
    color = colors.blue,
    padding_left = 8,
    padding_right = 8,
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
  background = {
    color = colors.lightblack,
    padding_left = 2,
    padding_right = 2,
  },
})

volume:subscribe({"routine", "volume_change", "system_woke"}, function()
  sbar.exec("osascript -e 'get volume settings'", function(settings)
    local volume_level = tonumber(settings:match("output volume:(%d+)"))
    local is_muted = settings:match("output muted:(%a+)") == "true"
    
    local icon = icons.volume[0]
    local color = colors.grey

    if is_muted then
      icon = icons.volume[0]
      color = colors.red
    elseif volume_level > 66 then
      icon = icons.volume[100]
      color = colors.white
    elseif volume_level > 33 then
      icon = icons.volume[66]
      color = colors.white
    elseif volume_level > 10 then
      icon = icons.volume[33]
      color = colors.white
    elseif volume_level > 0 then
      icon = icons.volume[10]
      color = colors.white
    end

    volume:set({
      icon = { string = icon, color = color },
      label = { string = is_muted and "Muted" or volume_level .. "%" }
    })
  end)
end)

volume:subscribe("mouse.clicked", function()
  sbar.exec("osascript -e 'set volume output muted not (output muted of (get volume settings))'", function()
    sbar.trigger("volume_change")
  end)
end)
-- volume:subscribe("mouse.scrolled", function(env)
--   local delta = env.SCROLL_DELTA
--   sbar.exec('osascript -e "set volume output volume (output volume of (get volume settings) + ' .. delta .. ')"')
-- end)
