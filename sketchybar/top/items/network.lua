local icons = require "icons"
local settings = require "settings"
local utils = require "utils"
local ui = require "ui"

local function start_provider(interface)
  if not interface or interface == "" then
    return
  end
  local cmd = "killall network_load >/dev/null 2>&1; "
    .. settings.network.provider_path
    .. " "
    .. interface
    .. " network_update 2.0 >/dev/null 2>&1 &"
  sbar.exec(cmd)
end

local interface = utils.get_primary_interface()
start_provider(interface)

local last_rates = { upload = "000 Bps", download = "000 Bps" }

local function rate_inactive(rate)
  return not rate or rate:match "^0+%s" ~= nil
end

-- Provider emits zero-padded '%03d KBps'; render "12 KB/s" not "012 KBps".
local function pretty_rate(rate)
  local n, unit = tostring(rate or ""):match "^(%d+)%s+(%a+)"
  if not n then
    return rate
  end
  return tostring(tonumber(n)) .. " " .. unit:gsub("ps$", "/s")
end

local network_up = ui.stacked_rate("widgets.network_up", {
  padding_left = 8,
  padding_right = 0,
  icon_padding = 2,
  icon = icons.wifi.upload,
  color = settings.theme.critical,
  text = "0 KB/s",
  stack = settings.layout.spacing.stack,
})

local network_down = ui.stacked_rate("widgets.network_down", {
  width = settings.layout.columns.rate_row,
  padding_left = 8,
  padding_right = 0,
  icon_padding = 2,
  icon = icons.wifi.download,
  color = settings.theme.accent,
  text = "0 KB/s",
  stack = -settings.layout.spacing.stack,
})

ui.bracket_spacer("widgets.network_gap", 8)

local function apply_rate_colors()
  local up_color = rate_inactive(last_rates.upload) and settings.theme.text_muted
    or settings.theme.critical
  local down_color = rate_inactive(last_rates.download) and settings.theme.text_muted
    or settings.theme.accent
  network_up:set {
    icon = { color = up_color },
    label = { string = pretty_rate(last_rates.upload), color = up_color },
  }
  network_down:set {
    icon = { color = down_color },
    label = { string = pretty_rate(last_rates.download), color = down_color },
  }
end

network_up:subscribe("network_update", function(env)
  last_rates.upload = env.upload or last_rates.upload
  last_rates.download = env.download or last_rates.download
  apply_rate_colors()
end)

network_up:subscribe("theme_colors_updated", apply_rate_colors)

network_up:subscribe({ "deferred_wake", "wifi_change" }, function()
  interface = utils.get_primary_interface()
  start_provider(interface)
end)

return {
  up = network_up,
  down = network_down,
}
