local settings = require "settings"
local ui = require "ui"

require "theme_handler"

local function flashspace_running()
  local handle =
    io.popen "command -v flashspace >/dev/null 2>&1 && pgrep -qx FlashSpace >/dev/null 2>&1 && echo yes"
  local result = handle and handle:read "*a" or ""
  if handle then
    handle:close()
  end
  return result:match "yes" ~= nil
end

if flashspace_running() then
  require "items.flashspaces"
else
  require "items.yabai_spaces"
end

require "items.calendar"
require "items.battery"
require "items.network"
require "items.wifi"
require "items.brew"
require "items.volume"
require "items.mic"
require "items.bluetooth"

ui.bracket_group("top.group.network", {
  "widgets.wifi",
  "widgets.network_gap",
  "widgets.network_up",
  "widgets.network_down",
}, { padding = settings.paddings })

local network_bracket_theme =
  sbar.add("item", "top.group.network.theme", { drawing = false, updates = true })
network_bracket_theme:subscribe("theme_colors_updated", function()
  sbar.set("top.group.network", {
    background = ui.capsule {
      color = settings.theme.surface_alt,
      border_color = settings.theme.border,
    },
  })
end)
