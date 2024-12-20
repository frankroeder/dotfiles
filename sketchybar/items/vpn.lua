local settings = require "settings"
local colors = require "colors"
local icons = require "icons"

local vpn_item = sbar.add("item", { "vpn" }, {
  position = "center",
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
  background = {
    color = colors.lightblack,
    padding_left = 2,
    padding_right = 2,
  },
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
      vpn_item:set {
        drawing = false,
      }
    end
  end)
end

vpn_item:subscribe({ "routine", "system_woke", "forced" }, function(_)
  update()
end)
update()
