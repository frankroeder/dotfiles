#!/usr/bin/env lua
-- Set up package paths
package.cpath = package.cpath .. ";/Users/" .. os.getenv("USER") .. "/.local/share/sketchybar_lua/?.so"
package.path = package.path .. ";" .. os.getenv("CONFIG_DIR") .. "/?.lua"
package.path = package.path .. ";" .. os.getenv("CONFIG_DIR") .. "/?/init.lua"

-- Require the sketchybar module
sbar = require "sketchybar"

sbar.set_bar_name("sketchybar-top")

-- Bundle the entire initial configuration into a single message to sketchybar
sbar.begin_config()
require "bar"
require "items.yabai_spaces"
require "items.front_app"
require "items.vpn"
require "items.mic"
require "items.volume"
require "items.wifi"
require "items.weather"
require "items.battery"
require "items.calendar"
sbar.end_config()

-- Run the event loop of the sketchybar module
sbar.event_loop()