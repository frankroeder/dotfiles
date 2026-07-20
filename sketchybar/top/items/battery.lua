local icons = require "icons"
local colors = require "colors"
local settings = require "settings"
local ui = require "ui"

local profiler_cache = { data = nil, timestamp = 0 }
local CACHE_TTL = 300
local last = { charge = nil, charging = false, icon = icons.battery["100"], label = "?" }

local battery = ui.add_capsule("widgets.battery", {
  padding_left = 4,
  padding_right = 4,
  icon = {
    font = {
      style = settings.font.style_map["Regular"],
      size = 19.0,
    },
    color = colors.bat,
  },
  label = {
    font = { family = settings.font.family },
    color = colors.bat,
  },
  update_freq = 120,
  popup = { align = "center" },
})

local remaining_time = ui.popup_field("widgets.battery.remaining", battery, {
  icon = icons.clock,
  label = "??:??h",
})

local battery_health = ui.popup_field("widgets.battery.health", battery, {
  icon = icons.battery.health,
  label = "Health: ???%",
})

local battery_cycles = ui.popup_field("widgets.battery.cycles", battery, {
  icon = icons.battery.cycles,
  label = "Cycles: ???",
})

local power_wattage = ui.popup_field("widgets.battery.watts", battery, {
  icon = icons.battery.wattage,
  label = "Watts: ???W",
  drawing = false,
})

local temperature = ui.popup_field("widgets.battery.temperature", battery, {
  icon = icons.temperature,
  label = "Temperature: --°C",
  drawing = false,
})

local function bat_color(charge, charging)
  if charging then
    return colors.green
  end
  if not charge then
    return colors.bat
  end
  if charge <= 15 then
    return colors.red
  end
  if charge <= 30 then
    return colors.yellow
  end
  return colors.bat
end

local function battery_icon(charge, charging)
  if charging then
    return icons.battery.charging
  end
  if not charge then
    return "!"
  end
  if charge >= 90 then
    return icons.battery["100"]
  end
  if charge >= 60 then
    return icons.battery["75"]
  end
  if charge >= 40 then
    return icons.battery["50"]
  end
  if charge >= 20 then
    return icons.battery["25"]
  end
  return icons.battery["0"]
end

battery:subscribe({ "routine", "power_source_change", "deferred_wake" }, function()
  sbar.exec("pmset -g batt", function(batt_info)
    local charge = nil
    local found, _, pct = batt_info:find "(%d+)%%"
    if found then
      charge = tonumber(pct)
    end
    local charging = batt_info:find "AC Power" ~= nil
    local icon = battery_icon(charge, charging)
    local label = charge and (charge .. "%") or "?"
    local color = bat_color(charge, charging)

    last.charge = charge
    last.charging = charging
    last.icon = icon
    last.label = label

    sbar.animate("tanh", settings.animation_duration, function()
      battery:set {
        icon = { string = icon, color = color },
        label = { string = label, color = color },
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
    remaining_time:set { label = found and remaining .. "h" or "No estimate" }
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

ui.bind_popup(battery, { on_open = update_details })

battery:subscribe("theme_colors_updated", function()
  local color = bat_color(last.charge, last.charging)
  battery:set {
    background = ui.widget_background(),
    icon = { string = last.icon, color = color },
    label = { string = last.label, color = color },
  }
end)
