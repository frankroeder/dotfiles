local icons = require "icons"
local colors = require "colors"
local settings = require "settings"
local utils = require "utils"
local ui = require "ui"
local popup_row_height = settings.ui.popup_row_height

-- Cache for expensive system_profiler calls
local profiler_cache = { data = nil, timestamp = 0 }
local CACHE_TTL = 300 -- 5 minutes

local battery = sbar.add("item", "widgets.battery", {
  position = "right",
  padding_left = settings.paddings,
  padding_right = settings.paddings,
  icon = {
    font = {
      style = settings.font.style_map["Regular"],
      size = 19.0,
    },
    color = colors.bat,
  },
  label = {
    font = { family = settings.font.numbers },
    color = colors.bat,
  },
  update_freq = 120,
  popup = { align = "center" },
  background = ui.capsule {},
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
  background = ui.popup_row(popup_row_height),
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
  background = ui.popup_row(popup_row_height),
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
  background = ui.popup_row(popup_row_height),
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
  background = ui.popup_row(popup_row_height),
  drawing = false,
})

local temperature = sbar.add("item", {
  position = "popup." .. battery.name,
  icon = {
    string = icons.temperature,
    padding_left = 5,
    padding_right = 5,
  },
  label = {
    string = "Temperature: --°C",
    padding_right = 11,
  },
  background = ui.popup_row(popup_row_height),
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

    local charging, _, _ = batt_info:find "AC Power"

    if charging then
      icon = icons.battery.charging
    else
      if found and charge >= 90 then
        icon = icons.battery["100"]
      elseif found and charge >= 60 then
        icon = icons.battery["75"]
      elseif found and charge >= 40 then
        icon = icons.battery["50"]
      elseif found and charge >= 20 then
        icon = icons.battery["25"]
      else
        icon = icons.battery["0"]
      end
    end

    sbar.animate("tanh", settings.animation_duration, function()
      battery:set {
        icon = { string = icon, color = colors.bat },
        label = { string = label },
      }
    end)
  end)
end)

local function update_ioreg_data()
  sbar.exec("ioreg -r -c AppleSmartBattery -d 1", function(output)
    if not output or output == "" then
      return
    end

    local ac_connected = output:match '"ExternalConnected"%s*=%s*Yes' ~= nil
    local battery_temp = tonumber(
      output:match '"VirtualTemperature"%s*=%s*(%d+)'
        or output:match '\n%s+"Temperature"%s*=%s*(%d+)'
    )
    local charger_temp = tonumber(
      output:match '"ConnectorTemperature"%s*=%s*(%d+)'
        or output:match '"PortTemperature"%s*=%s*(%d+)'
        or output:match '"ChargerTemperature"%s*=%s*(%d+)'
        or output:match '"AdapterTemperature"%s*=%s*(%d+)'
    )

    if ac_connected and charger_temp then
      temperature:set {
        drawing = true,
        label = string.format("AC connector: %.1f°C", charger_temp / 100),
      }
    elseif battery_temp then
      temperature:set {
        drawing = true,
        label = string.format("Battery: %.1f°C", battery_temp / 100),
      }
    else
      temperature:set { drawing = false }
    end
  end)
end

local function apply_profiler_data(data)
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
end

local function update_details()
  update_ioreg_data()

  sbar.exec("pmset -g batt", function(batt_info)
    local found, _, remaining = batt_info:find " (%d+:%d+) remaining"
    local label = found and remaining .. "h" or "No estimate"
    remaining_time:set { label = label }
  end)

  local now = os.time()
  if profiler_cache.data and (now - profiler_cache.timestamp) < CACHE_TTL then
    apply_profiler_data(profiler_cache.data)
    return
  end

  sbar.exec("system_profiler SPPowerDataType -json", function(data)
    profiler_cache.data = data
    profiler_cache.timestamp = os.time()
    apply_profiler_data(data)
  end)
end

battery:subscribe("mouse.clicked", function()
  utils.popup_toggle(battery, update_details)
end)

battery:subscribe("mouse.exited.global", function()
  utils.popup_hide(battery)
end)
