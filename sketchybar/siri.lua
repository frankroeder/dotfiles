local bar_config = require "bar_config"
local bridge = require "island_bridge"
local colors = require "colors"

sbar.add("event", "siri_appear", "com.apple.Siri.SiriDidAppear")
sbar.add("event", "siri_disappear", "com.apple.Siri.SiriDidDisappear")

local siri = sbar.add("item", "siri", { drawing = false })
local tint = colors.with_alpha(colors.mauve, 0.28)

-- Both bars tint, but only ONE instance relays to the island: with the relay
-- in both (siri.lua loads via shared default.lua on top AND bottom), the
-- island received every siri event twice — duplicate expands fighting
-- mid-animation flickered the pill.
local relay = (BAR_NAME or os.getenv "BAR_NAME") == "sketchybar-top"

siri:subscribe({ "siri_appear", "siri_disappear" }, function(env)
  local appear = env.SENDER == "siri_appear"
  if relay then
    bridge.trigger("island_siri", { action = appear and "appear" or "disappear" })
  end
  -- Tint is snapped, NOT animated: a bar color change in an animate batch is
  -- either color-only (sketchybar mangles those — full-display stretch) or
  -- padded with constant props (jitter). The 0.28-alpha wash reads fine as a
  -- snap.
  bar_config.bar { color = appear and tint or bar_config.rest_color() }
end)