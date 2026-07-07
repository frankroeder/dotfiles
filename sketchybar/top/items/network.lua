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

local network_up = ui.stacked_rate("widgets.network_up", {
  padding_right = settings.paddings,
  icon = icons.wifi.upload,
  color = settings.theme.critical,
  text = "000 Bps",
  stack = settings.layout.spacing.stack,
})

local network_down = ui.stacked_rate("widgets.network_down", {
  width = settings.layout.columns.rate_row,
  padding_right = settings.paddings,
  icon = icons.wifi.download,
  color = settings.theme.accent,
  text = "000 Bps",
  stack = -settings.layout.spacing.stack,
})

ui.bracket_spacer("widgets.network_gap", settings.layout.spacing.edge)

local function apply_rate_colors()
  local up_color = rate_inactive(last_rates.upload) and settings.theme.text_muted
    or settings.theme.critical
  local down_color = rate_inactive(last_rates.download) and settings.theme.text_muted
    or settings.theme.accent
  network_up:set {
    icon = { color = up_color },
    label = { string = last_rates.upload, color = up_color },
  }
  network_down:set {
    icon = { color = down_color },
    label = { string = last_rates.download, color = down_color },
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
