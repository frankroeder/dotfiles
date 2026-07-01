local island = require "island_core"
local island_style = require "island_style"
local settings = require "settings"

if not settings.island.cpu_alert then
  return
end

local config = {
  width = settings.island.widths.cpu,
  height = island.EXPAND_H,
  duration = 0,
  main = {
    font = { size = 18, style = "Semibold" },
    align = "center",
    padding_left = 16,
    padding_right = 16,
  },
  subtitle = {
    font = { size = 14, style = "Regular" },
    align = "center",
  },
}

local function load_color(pct)
  if pct >= 80 then
    return island_style.critical()
  end
  if pct >= 50 then
    return island_style.warn()
  end
  return island_style.text()
end

local listener = sbar.add("item", "listener.cpuload", {
  drawing = false,
  updates = true,
  update_freq = 0,
  icon = { drawing = false },
  label = { drawing = false },
  background = { drawing = false },
})

listener:subscribe("island_cpuload", function(env)
  local pct = math.max(0, math.min(100, tonumber(env.percent) or 0))
  local app = env.app or "System"
  local color = load_color(pct)
  local short = #app > 22 and (app:sub(1, 20) .. "…") or app

  island.expand {
    topmost = true,
    width = config.width,
    height = config.height,
    duration = config.duration,
    right = {
      text = short .. "  ·  " .. string.format("%.0f%%", pct),
      font = config.main.font,
      align = config.main.align,
      color = color,
      padding_left = config.main.padding_left,
      padding_right = config.main.padding_right,
    },
    subtitle = {
      text = "High CPU usage — may drain battery quickly.",
      color = color,
      font = config.subtitle.font,
      align = config.subtitle.align,
    },
  }
end)