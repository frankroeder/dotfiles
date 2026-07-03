local app_icons = require "helpers.app_icons"
local icons = require "icons"
local island = require "island_core"
local island_style = require "island_style"
local settings = require "settings"
local utils = require "utils"

if not settings.island.appswitch then
  return
end

local config = {
  width = settings.island.widths.app,
  height = island.IDLE_H,
  duration = settings.island.appswitch_duration,
  left = {
    font = { size = 15, style = "Semibold" },
    padding_left = 16,
    padding_right = 4,
  },
  right = {
    font = settings.font.app_icon .. ":Regular:32.0",
    align = "center",
    width = 40,
    padding_left = 4,
    padding_right = 16,
  },
}

local last_app = nil

local listener = sbar.add("item", "listener.appswitch", {
  drawing = false,
  updates = true,
  update_freq = 0,
  icon = { drawing = false },
  label = { drawing = false },
  background = { drawing = false },
})

listener:subscribe("front_app_switched", function(env)
  local name = env.INFO or ""
  if name == "" or name == last_app then
    return
  end
  last_app = name

  -- Keep the name inside the left lobe (left of the notch) so it stays visible.
  local short = #name > 15 and (name:sub(1, 14) .. "…") or name
  local glyph = utils.lookup_app_icon(name, app_icons)

  island.expand {
    width = config.width,
    height = config.height,
    duration = config.duration,
    left = {
      text = short,
      font = config.left.font,
      color = island_style.text(),
      padding_left = config.left.padding_left,
      padding_right = config.left.padding_right,
    },
    right = {
      text = glyph ~= app_icons["Default"] and glyph or icons.apple,
      font = config.right.font,
      align = config.right.align,
      width = config.right.width,
      color = island_style.accent(),
      padding_left = config.right.padding_left,
      padding_right = config.right.padding_right,
    },
  }
end)