local settings = require "settings"
local colors = require "colors"
local icons = require "icons"

local uptime = sbar.add("item", "widgets.uptime", {
  position = "left",
  icon = {
    string = icons.uptime,
    color = colors.white,
    padding_left = 8,
  },
  label = {
    font = {
      size = 15.0,
    },
    string = "...",
    padding_right = 8,
  },
  update_freq = 600,
  background = {
    drawing = true,
  },
})

local function format_uptime(seconds)
  local days = math.floor(seconds / 86400)
  local hours = math.floor((seconds % 86400) / 3600)
  local mins = math.floor((seconds % 3600) / 60)

  if days > 0 then
    return string.format("%dd %dh", days, hours)
  elseif hours > 0 then
    return string.format("%dh %dm", hours, mins)
  else
    return string.format("%dm", mins)
  end
end

uptime:subscribe({ "routine", "forced", "system_woke" }, function(_)
  sbar.exec("sysctl -n kern.boottime | awk '{print $4}' | sed 's/,//'", function(boottime)
    if boottime then
      local boot = tonumber(boottime)
      if boot then
        local now = os.time()
        local uptime_seconds = now - boot
        local uptime_str = format_uptime(uptime_seconds)

        uptime:set {
          label = {
            string = uptime_str,
          },
        }
      end
    end
  end)
end)
