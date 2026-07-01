local settings = require "settings"
local icons = require "icons"
local ui = require "ui"

sbar.add("event", "network_change", "com.apple.networkConnect")

local vpn_item = ui.add_capsule("widgets.vpn", {
  position = "left",
  update_freq = 60,
  icon = {
    string = icons.vpn,
    padding_left = 4,
    padding_right = 2,
    font = {
      style = settings.font.style_map["Regular"],
      size = 16.0,
    },
  },
  label = {
    string = "",
    font = {
      style = settings.font.style_map["Bold"],
      size = 14.0,
    },
  },
  drawing = false,
  click_script = "open 'x-apple.systempreferences:com.apple.preference.vpn'",
})

local function update()
  sbar.exec(
    [[scutil --nc list | grep Connected | sed -E 's/.*"(.*)".*/\1/' | head -1]],
    function(output)
      local vpn_name = (output or ""):gsub("%s+$", ""):match "^%s*(.-)%s*$"
      if vpn_name and vpn_name ~= "" then
        sbar.animate("sin", settings.animation_duration, function()
          vpn_item:set {
            drawing = true,
            label = { string = vpn_name },
          }
        end)
      else
        vpn_item:set { drawing = false, label = { string = "" } }
      end
    end
  )
end

vpn_item:subscribe({ "network_change", "routine", "system_woke" }, update)

vpn_item:subscribe("theme_colors_updated", function()
  vpn_item:set {
    background = ui.capsule(),
    icon = { color = settings.theme.accent },
    label = { color = settings.theme.text_muted },
  }
  update()
end)

update()
