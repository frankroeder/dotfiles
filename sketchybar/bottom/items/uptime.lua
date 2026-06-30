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
  sbar.exec(
    "sysctl -n kern.boottime 2>/dev/null | awk '{print $4}' | sed 's/,//'",
    function(boottime)
      local boot = boottime and tonumber(boottime)
      if not boot then
        return
      end
      uptime:set { label = { string = format_uptime(os.time() - boot) } }
    end
  )
end

uptime:subscribe({ "routine", "system_woke", "forced" }, refresh_uptime)

-- ensure label is populated immediately on sketchybar (re)load
refresh_uptime()
