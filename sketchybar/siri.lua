local bar_config = require "bar_config"
local bridge = require "island_bridge"
local colors = require "colors"
local settings = require "settings"

sbar.add("event", "siri_appear", "com.apple.Siri.SiriDidAppear")
sbar.add("event", "siri_disappear", "com.apple.Siri.SiriDidDisappear")

local siri = sbar.add("item", "siri", { drawing = false })
local tint = colors.with_alpha(colors.mauve, 0.28)

siri:subscribe({ "siri_appear", "siri_disappear" }, function(env)
  if env.SENDER == "siri_appear" then
    bridge.trigger("island_siri", { action = "appear" })
    sbar.animate("tanh", 20, function()
      bar_config.bar { color = tint }
    end)
  else
    bridge.trigger("island_siri", { action = "disappear" })
    sbar.animate("tanh", 20, function()
      bar_config.bar { color = settings.theme.bar }
    end)
  end
end)