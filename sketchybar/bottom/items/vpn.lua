local settings = require "settings"

sbar.add("event", "network_change", "com.apple.networkConnect")

-- Native Control Center extra; name sits immediately to its right.
sbar.add("alias", "Control Center,com.apple.menuextra.vpn(7)", {
  position = "left",
  padding_left = -20,
  padding_right = -30,
})

local vpn_name = sbar.add("item", "widgets.vpn", {
  position = "left",
  drawing = false,
  icon = { drawing = false },
  label = {
    string = "",
    font = {
      family = settings.font.family,
      style = settings.font.style_map["Bold"],
      size = 15.0,
    },
    padding_left = 4,
    padding_right = 8,
    color = settings.theme.text_muted,
  },
  background = { drawing = false },
  click_script = "open 'x-apple.systempreferences:com.apple.preference.vpn'",
  updates = true,
})

local function update()
  sbar.exec(
    [[scutil --nc list | grep Connected | sed -E 's/.*"(.*)".*/\1/' | awk 'NR==1{print; exit}']],
    function(output)
      local name = (output or ""):gsub("%s+$", ""):match "^%s*(.-)%s*$"
      if name and name ~= "" then
        vpn_name:set {
          drawing = true,
          label = { string = name, color = settings.theme.text_muted },
        }
      else
        vpn_name:set { drawing = false, label = { string = "" } }
      end
    end
  )
end

vpn_name:subscribe({ "network_change", "routine", "deferred_wake", "theme_colors_updated" }, update)
update()
