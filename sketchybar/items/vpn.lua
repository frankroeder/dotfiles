local settings = require "settings"
local colors = require "colors"
local icons = require "icons"

local vpn_item = sbar.add("item", { "vpn" }, {
  position = "center",
  update_freq = 2,
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
  },
})

local function update()
  local cmd = [[
    scutil --nc list | grep Connected | sed -E 's/.*"(.*)".*/\1/'
  ]]
  sbar.exec(cmd, function(output)
    local vpn_name = output:match "^%s*(.-)%s*$"
    if vpn_name and vpn_name:len() > 0 then
      sbar.animate("sin", 20, function()
        vpn_item:set { label = vpn_name, drawing = true }
      end)
    else
      vpn_item:set {
        drawing = false,
      }
    end
  end)
end

vpn_item:subscribe("routine", "system_woke", function(_)
  update()
end)
update()
