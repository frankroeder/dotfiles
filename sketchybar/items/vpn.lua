local vpn_item = sbar.add("item", { "vpn" }, {
  position = "center",
  update_freq = 2,
  icon = {
    string = "",
    font = {
      style = "Regular",
      size = 14.0,
    },
  },
  label = {
    string = "",
    font = {
      style = "Bold",
      size = 12.0,
    },
  },
  drawing = false, -- hidden by default
})

local function update()
  local cmd = [[
    scutil --nc list | grep Connected | sed -E 's/.*"(.*)".*/\1/'
  ]]
  sbar.exec(cmd, function(output)
    local vpn_name = output:match "^%s*(.-)%s*$"
    if vpn_name and vpn_name:len() > 0 then
      sbar.animate("sin", 10, function()
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
