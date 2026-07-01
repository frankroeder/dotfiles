#!/usr/bin/env lua

local script_dir = debug.getinfo(1, "S").source:match("@?(.*/)")
local sketchybar_dir = script_dir .. "../"
package.path = sketchybar_dir .. "?.lua;" .. package.path

local failures = 0

local function fail(name, detail)
  failures = failures + 1
  io.write("FAIL ", name)
  if detail then
    io.write(": ", detail)
  end
  io.write("\n")
end

local function pass(name)
  io.write("PASS ", name, "\n")
end

local function assert_eq(name, got, want)
  if got ~= want then
    fail(name, string.format("got %s want %s", tostring(got), tostring(want)))
  else
    pass(name)
  end
end

package.loaded["bar_config"] = nil
local bar_config = require "bar_config"

assert_eq("lone builtin top uses notch", bar_config.resolve_notch("top", {
  notch_width = 220,
  external_index = nil,
}), 220)

assert_eq("dual monitor top disables notch", bar_config.resolve_notch("top", {
  notch_width = 220,
  external_index = 2,
}), 0)

assert_eq("bottom bar disables notch", bar_config.resolve_notch("bottom", {
  notch_width = 220,
  external_index = nil,
}), 0)

assert_eq("bottom bar dual monitor disables notch", bar_config.resolve_notch("bottom", {
  notch_width = 220,
  external_index = 2,
}), 0)

assert_eq("zero notch width falls back to 200", bar_config.resolve_notch("top", {
  notch_width = 0,
  external_index = nil,
}), 200)

local captured = {}
_G.sbar = {
  bar = function(props)
    captured[#captured + 1] = props
  end,
}

package.loaded["display"] = {
  notch_width = 162,
  external_index = 3,
}
package.loaded["bar_config"] = nil
bar_config = require "bar_config"

captured = {}
bar_config.apply("top")
if #captured ~= 1 then
  fail("apply top emits one bar config", string.format("got %d", #captured))
else
  pass("apply top emits one bar config")
  assert_eq("apply top passes notch_width=0", captured[1].notch_width, 0)
  assert_eq("apply top passes notch_display_height=0", captured[1].notch_display_height, 0)
end

package.loaded["display"] = {
  notch_width = 180,
  external_index = nil,
}
package.loaded["bar_config"] = nil
bar_config = require "bar_config"

captured = {}
bar_config.apply("top")
assert_eq("apply lone builtin top passes notch_width", captured[1].notch_width, 180)

captured = {}
bar_config.apply("bottom")
assert_eq("apply bottom passes notch_width=0", captured[1].notch_width, 0)

package.loaded["display"] = nil
local display = require "display"
io.write(string.format(
  "live display: builtin_index=%s external_index=%s notch_width=%s screen_width=%s\n",
  tostring(display.builtin_index),
  tostring(display.external_index),
  tostring(display.notch_width),
  tostring(display.screen_width)
))
io.write(string.format(
  "live top notch decision: %s\n",
  tostring(bar_config.resolve_notch("top", display))
))

if failures > 0 then
  os.exit(1)
end

io.write("all notch tests passed\n")