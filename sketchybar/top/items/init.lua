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

-- position=right: later requires sit further left.
require "items.calendar"
require "items.battery"
require "items.brew"
require "items.bluetooth"
require "items.network"
require "items.wifi"
ui.bracket_spacer("top.group.gap", settings.layout.spacing.group)
require "items.volume"
require "items.mic"
