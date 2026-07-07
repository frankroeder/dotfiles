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

-- Order matters: items are position="right", so requiring an item later places
-- it further left. This keeps each pill's members visually adjacent.
require "items.calendar"
require "items.battery"
require "items.brew"
require "items.bluetooth" -- standalone, sits just right of the wifi pill
require "items.network"
require "items.wifi"

-- Spacer so the audio pill and the wifi pill don't touch.
ui.bracket_spacer("top.group.gap", settings.layout.spacing.group)

require "items.volume"
require "items.mic"

-- Volume + mic in one pill; wifi + network rates in another. Bluetooth is its own
-- standalone capsule and sits between the two pills.
ui.bracket_group("top.group.audio", {
  "widgets.volume",
  "widgets.mic",
}, { padding = 3 })

ui.bracket_group("top.group.connectivity", {
  "widgets.wifi",
  "widgets.network_gap",
  "widgets.network_up",
  "widgets.network_down",
}, { padding = 3 })

local group_theme = sbar.add("item", "top.group.theme", { drawing = false, updates = true })
group_theme:subscribe("theme_colors_updated", function()
  local bg = ui.capsule {
    color = settings.theme.surface_alt,
    border_color = settings.theme.border,
  }
  sbar.set("top.group.audio", { background = bg })
  sbar.set("top.group.connectivity", { background = bg })
end)
