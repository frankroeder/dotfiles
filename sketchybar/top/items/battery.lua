local colors = require "colors"
local settings = require "settings"
local logic = require "logic"

local last = { charge = nil, charging = false }

local battery = sbar.add("item", "widgets.battery", {
  position = "right",
  background = { drawing = false },
  icon = {
    font = {
      style = settings.font.style_map["Bold"],
      size = 14.0,
    },
    padding_left = 8,
    padding_right = 4,
  },
  label = {
    font = {
      family = settings.font.family,
      style = settings.font.style_map["Bold"],
      size = 12.0,
    },
    color = colors.text,
    padding_right = 10,
  },
  update_freq = 30,
  popup = { align = "center" },
})

local remaining_time = sbar.add("item", "widgets.battery.remaining", {
  position = "popup." .. battery.name,
  icon = {
    string = "Time remaining:",
    width = 110,
    align = "left",
    padding_left = 15,
  },
  label = {
    string = "??:??h",
    width = 110,
    align = "right",
    padding_right = 15,
  },
})

local function apply_batt(info)
  local charge = nil
  local found, _, pct = tostring(info or ""):find "(%d+)%%"
  if found then
    charge = tonumber(pct)
  end
  local charging = tostring(info or ""):find "AC Power" ~= nil
  last.charge = charge
  last.charging = charging
  local vis = logic.battery_visual(charge, charging)
  battery:set {
    icon = { string = vis.icon, color = vis.color },
    label = { string = vis.label, color = colors.text },
  }
end

battery:subscribe({ "routine", "power_source_change", "system_woke", "deferred_wake", "forced" }, function()
  sbar.exec("pmset -g batt", apply_batt)
end)

battery:subscribe("mouse.clicked", function()
  local drawing = battery:query().popup.drawing
  battery:set { popup = { drawing = "toggle" } }
  if drawing == "off" then
    sbar.exec("pmset -g batt", function(batt_info)
      local found, _, remaining = tostring(batt_info or ""):find " (%d+:%d+) remaining"
      remaining_time:set { label = found and remaining .. "h" or "No estimate" }
    end)
  end
end)

battery:subscribe("theme_colors_updated", function()
  local vis = logic.battery_visual(last.charge, last.charging)
  battery:set {
    icon = { string = vis.icon, color = vis.color },
    label = { string = vis.label, color = colors.text },
  }
end)

sbar.exec("pmset -g batt", apply_batt)
