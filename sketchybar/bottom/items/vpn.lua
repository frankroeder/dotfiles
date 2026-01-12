local settings = require "settings"
local colors = require "colors"
local icons = require "icons"

sbar.add("event", "network_change", "com.apple.networkConnect")

local vpn_item = sbar.add("item", "bottom.widgets.vpn", {
  position = "left",
  update_freq = 180,
  icon = {
    string = icons.vpn,
    padding_left = 8,
    font = {
      style = "Regular",
      size = 16.0,
    },
  },
  label = {
    padding_right = 8,
    string = "",
    font = {
      style = settings.font.style_map["Bold"],
      size = 14.0,
    },
  },
  drawing = false,
  background = {},
  click_script = "open 'x-apple.systempreferences:com.apple.preference.vpn'",
})

local function update()
  local cmd = [[
    scutil --nc list | grep Connected | sed -E 's/.*"(.*)".*/\1/'
  ]]
  sbar.exec(cmd, function(output)
    local vpn_name = output:match "^%s*(.-)%s*$"
    if vpn_name and vpn_name:len() > 0 then
      sbar.animate("sin", settings.animation_duration, function()
        vpn_item:set { label = vpn_name, drawing = true }
      end)
    else
      vpn_item:set { drawing = false }
    end
  end)
end

vpn_item:subscribe({ "network_change", "routine", "system_woke" }, function(_)
  update()
end)

vpn_item:set { update_freq = 60 }
update()
