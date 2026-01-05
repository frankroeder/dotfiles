local icons = require("icons")
local colors = require("colors")
local settings = require("settings")

local battery = sbar.add("item", "top.widgets.battery", {
  position = "right",
  icon = {
    font = {
      style = settings.font.style_map["Regular"],
      size = 19.0,
    },
  },
  label = { font = { family = settings.font.numbers } },
  update_freq = 120,
})

local remaining_time = sbar.add("item", {
  position = "popup." .. battery.name,
  icon = {
    string = "⏳",
    padding_left = 5,
    padding_right = 5,
  },
  label = {
    string = "??:??h",
    padding_right = 11,
  },
})

battery:subscribe({"routine", "power_source_change", "system_woke"}, function()
  sbar.exec("pmset -g batt", function(batt_info)
    local icon = "!"
    local label = "?"

    local found, _, charge = batt_info:find("(%d+)%%")
    if found then
      charge = tonumber(charge)
      label = charge .. "%"
    end

    local color = colors.white
    local charging, _, _ = batt_info:find("AC Power")

    if charging then
      icon = icons.battery.charging
      color = colors.green
    else
      if found and charge > 80 then
        icon = icons.battery["100"]
      elseif found and charge > 60 then
        icon = icons.battery["75"]
      elseif found and charge > 40 then
        icon = icons.battery["50"]
      elseif found and charge > 20 then
        icon = icons.battery["25"]
        color = colors.orange
      else
        icon = icons.battery["0"]
        color = colors.red
      end
    end

    battery:set({
      icon = {
        string = icon,
        color = color
      },
      label = { string = label },
    })
  end)
end)

battery:subscribe("mouse.clicked", function()
  local drawing = battery:query().popup.drawing
  battery:set( { popup = { drawing = "toggle" } })

  if drawing == "off" then
    sbar.exec("pmset -g batt", function(batt_info)
      local found, _, remaining = batt_info:find(" (%d+:%d+) remaining")
      local label = found and remaining .. "h" or "No estimate"
      remaining_time:set( { label = label })
    end)
  end
end)
