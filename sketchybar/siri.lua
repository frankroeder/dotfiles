local colors = require "colors"
local settings = require "settings"

sbar.add("event", "siri_appear", "com.apple.Siri.SiriDidAppear")
sbar.add("event", "siri_disappear", "com.apple.Siri.SiriDidDisappear")

local siri = sbar.add("item", "siri", {
  drawing = false,
})

siri:subscribe({ "siri_appear", "siri_disappear" }, function(env)
  if env.SENDER == "siri_appear" then
    sbar.animate("tanh", 20, function()
      sbar.bar {
        color = colors.purple,
      }
    end)
  elseif env.SENDER == "siri_disappear" then
    sbar.animate("tanh", 20, function()
      sbar.bar {
        color = settings.bar_color,
      }
    end)
  end
end)
