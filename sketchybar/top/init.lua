#!/usr/bin/env lua
-- Set up package paths
local home = os.getenv("HOME")
local user = os.getenv("USER")
local config_dir = home .. "/.config/sketchybar-top"
local shared_dir = home .. "/.dotfiles/sketchybar" -- Base dir for shared files

package.cpath = package.cpath .. ";/Users/" .. user .. "/.local/share/sketchybar_lua/?.so"
package.path = package.path .. ";" .. config_dir .. "/?.lua"
package.path = package.path .. ";" .. config_dir .. "/?/init.lua"
package.path = package.path .. ";" .. shared_dir .. "/?.lua"
package.path = package.path .. ";" .. shared_dir .. "/?/init.lua"

require "helpers"

-- Require the sketchybar module
sbar = require "sketchybar"

sbar.set_bar_name("sketchybar-top")

-- Bundle the entire initial configuration into a single message to sketchybar
sbar.begin_config()
require "bar"
require "items.init"
sbar.end_config()

-- Run the event loop of the sketchybar module
sbar.event_loop()
