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

-- position=left: packs after the space capsules / layout pill.
require "items.shortcuts"

-- position=right: later requires sit further left.
require "items.calendar"
require "items.battery"
require "items.brew"
require "items.coffee"
require "items.bluetooth"
require "items.network"
require "items.wifi"
require "items.volume"
require "items.mic"
require "items.ccu"
