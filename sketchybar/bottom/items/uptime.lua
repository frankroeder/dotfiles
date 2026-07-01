local settings = require "settings"
local colors = require "colors"
local icons = require "icons"
local ui = require "ui"

local uptime = ui.add_capsule("widgets.uptime", {
  position = "left",
  icon = {
    string = icons.uptime,
    color = settings.theme.accent,
    padding_left = 4,
    padding_right = 2,
  },
  label = {
    font = { size = 15.0 },
    string = "...",
  },
  update_freq = 600,
})

local function format_uptime(seconds)
  local days = math.floor(seconds / 86400)
  local hours = math.floor((seconds % 86400) / 3600)
  local mins = math.floor((seconds % 3600) / 60)

  if days > 0 then
    return string.format("%dd %dh", days, hours)
  elseif hours > 0 then
    return string.format("%dh %dm", hours, mins)
  end
  return string.format("%dm", mins)
end

local function refresh_uptime()
  sbar.exec("sysctl -n kern.boottime | sed -E 's/.* sec = ([0-9]+).*/\\1/'", function(boottime)
    local num = (boottime or ""):gsub("%D", "")
    local boot = tonumber(num)
    if not boot or boot == 0 then
      uptime:set { label = { string = "???" } }
      return
    end
    uptime:set { label = { string = format_uptime(os.time() - boot) } }
  end)
end

uptime:subscribe({ "routine", "deferred_wake", "forced" }, refresh_uptime)

uptime:subscribe("theme_colors_updated", function()
  uptime:set {
    background = ui.capsule(),
    icon = { color = settings.theme.accent },
    label = { color = settings.theme.text_muted },
  }
end)

-- ensure label is populated immediately on sketchybar (re)load
refresh_uptime()
