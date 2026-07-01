#!/usr/bin/env lua
local home = os.getenv "HOME"
local config_dir = home .. "/.config/sketchybar-island"
local shared_dir = home .. "/.dotfiles/sketchybar"

package.cpath = package.cpath .. ";" .. home .. "/.local/share/sketchybar_lua/?.so"
package.path = package.path .. ";" .. config_dir .. "/?.lua"
package.path = package.path .. ";" .. config_dir .. "/?/init.lua"
package.path = package.path .. ";" .. shared_dir .. "/?.lua"
package.path = package.path .. ";" .. shared_dir .. "/?/init.lua"

require "helpers"

sbar = require "sketchybar"

sbar.set_bar_name "sketchybar-island"

sbar.add("item", "reload_guard", { position = "right", drawing = false })
sbar.remove "/.*/"

sbar.begin_config()
sbar.add("event", "theme_change", "AppleInterfaceThemeChangedNotification")
sbar.add("event", "theme_relay")
sbar.add("event", "island_tap")
sbar.add("event", "island_battery")
sbar.add("event", "island_siri")
sbar.add("event", "island_appswitch")
sbar.add("event", "island_cpuload")
sbar.add("event", "island_power")
require "bar"
require "default"
require "display_watch"
require "theme"
require "lock"
require "island_core"
require "items.init"
sbar.end_config()

sbar.event_loop()