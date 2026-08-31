local icons = require "icons"
local settings = require "settings"
local utils = require "utils"
local ui = require "ui"

local RATE_W = settings.layout.columns.rate_row
-- Hover bridge only. Wifi already has padding_right 4; 8+8 here made a hole.
local GAP_W = 4
local frames = settings.motion.normal

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
local hot = false
local anim_gen = 0

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
  drawing = false,
  padding_left = 0,
  padding_right = 0,
  icon_padding = 2,
  icon = icons.wifi.upload,
  color = settings.theme.critical,
  text = "0 KB/s",
  stack = settings.layout.spacing.stack,
})

local network_down = ui.stacked_rate("widgets.network_down", {
  drawing = false,
  width = 0,
  padding_left = 0,
  padding_right = 0,
  icon_padding = 2,
  icon = icons.wifi.download,
  color = settings.theme.accent,
  text = "0 KB/s",
  stack = -settings.layout.spacing.stack,
})

local network_gap = ui.bracket_spacer("widgets.network_gap", 0)
network_gap:set { drawing = false }

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

local function set_hot(on)
  if on == hot then
    if on then
      apply_rate_colors()
    end
    return
  end
  hot = on
  anim_gen = anim_gen + 1
  local token = anim_gen
  if on then
    apply_rate_colors()
    network_up:set { drawing = true }
    network_down:set { drawing = true }
    network_gap:set { drawing = true }
    sbar.animate("tanh", frames, function()
      network_down:set { width = RATE_W }
      network_gap:set { width = GAP_W }
    end)
  else
    sbar.animate("tanh", frames, function()
      network_down:set { width = 0 }
      network_gap:set { width = 0 }
    end)
    sbar.delay(frames / 60, function()
      if token ~= anim_gen then
        return
      end
      network_up:set { drawing = false }
      network_down:set { drawing = false, width = 0 }
      network_gap:set { drawing = false, width = 0 }
    end)
  end
end

network_up:subscribe("network_update", function(env)
  last_rates.upload = env.upload or last_rates.upload
  last_rates.download = env.download or last_rates.download
  if hot then
    apply_rate_colors()
  end
end)

network_up:subscribe("theme_colors_updated", function()
  if hot then
    apply_rate_colors()
  end
end)

network_up:subscribe({ "deferred_wake", "wifi_change" }, function()
  interface = utils.get_primary_interface()
  start_provider(interface)
end)

return {
  up = network_up,
  down = network_down,
  gap = network_gap,
  set_hot = set_hot,
}
