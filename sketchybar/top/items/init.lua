local settings = require "settings"

local function flashspace_running()
  local handle = io.popen "command -v flashspace >/dev/null 2>&1 && pgrep -qx FlashSpace >/dev/null 2>&1 && echo yes"
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
local network = require "items.network"
require "items.wifi"
network.add_download()
require "items.brew"
require "items.volume"
require "items.mic"
require "items.bluetooth"
require "items.wallpaper"

sbar.add("bracket", "top.group.network", {
  "widgets.wifi",
  "widgets.network_down",
  "widgets.network_up",
}, {
  background = {
    drawing = true,
    color = settings.theme.surface,
    border_color = settings.theme.border_hover,
    border_width = 1,
    height = settings.ui.group_height,
    corner_radius = settings.ui.group_corner_radius,
    padding_left = 4,
    padding_right = 4,
  },
})
