local icons = require "icons"
local colors = require "colors"
local settings = require "settings"

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
  popup = { align = "center" },
})

local remaining_time = sbar.add("item", {
  position = "popup." .. battery.name,
  icon = {
    string = icons.clock,
    padding_left = 5,
    padding_right = 5,
  },
  label = {
    string = "??:??h",
    padding_right = 11,
  },
})

local battery_health = sbar.add("item", {
  position = "popup." .. battery.name,
  icon = {
    string = icons.battery.health,
    padding_left = 5,
    padding_right = 5,
  },
  label = {
    string = "Health: ???%",
    padding_right = 11,
  },
})

local battery_cycles = sbar.add("item", {
  position = "popup." .. battery.name,
  icon = {
    string = icons.battery.cycles,
    padding_left = 5,
    padding_right = 5,
  },
  label = {
    string = "Cycles: ???",
    padding_right = 11,
  },
})

local power_wattage = sbar.add("item", {
  position = "popup." .. battery.name,
  icon = {
    string = icons.battery.wattage,
    padding_left = 5,
    padding_right = 5,
  },
  label = {
    string = "Watts: ???W",
    padding_right = 11,
  },
  drawing = false,
})

battery:subscribe({ "routine", "power_source_change", "system_woke" }, function()
  sbar.exec("pmset -g batt", function(batt_info)
    local icon = "!"
    local label = "?"

    local found, _, charge = batt_info:find "(%d+)%%"
    if found then
      charge = tonumber(charge)
      label = charge .. "%"
    end

    local color = colors.white
    local charging, _, _ = batt_info:find "AC Power"

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

    battery:set {
      icon = {
        string = icon,
        color = color,
      },
      label = { string = label },
    }
  end)
end)

local function update_details()
  sbar.exec("pmset -g batt", function(batt_info)
    local found, _, remaining = batt_info:find " (%d+:%d+) remaining"
    local label = found and remaining .. "h" or "No estimate"
    remaining_time:set { label = label }
  end)

  sbar.exec("system_profiler SPPowerDataType -json", function(data)
    if not data or not data.SPPowerDataType then
      return
    end

    power_wattage:set { drawing = false }

    for _, info in pairs(data.SPPowerDataType) do
      if info.sppower_battery_health_info then
        local health = info.sppower_battery_health_info
        local max_cap = health.sppower_battery_health_maximum_capacity or "??"
        local cycles = health.sppower_battery_cycle_count or "??"
        local condition = health.sppower_battery_health or "Good"

        battery_health:set { label = "Health: " .. max_cap .. " (" .. condition .. ")" }
        battery_cycles:set { label = "Cycles: " .. cycles }
      end

      if info.sppower_ac_charger_watts then
        power_wattage:set {
          drawing = true,
          label = "Input: " .. info.sppower_ac_charger_watts .. "W",
        }
      end
    end
  end)
end

battery:subscribe("mouse.clicked", function()
  local drawing = battery:query().popup.drawing
  battery:set { popup = { drawing = "toggle" } }

  if drawing == "off" then
    update_details()
  end
end)

battery:subscribe("mouse.exited.global", function()
  battery:set { popup = { drawing = false } }
end)
