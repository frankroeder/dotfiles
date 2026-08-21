-- Static composition dump from shipped groups.lua + items/init.lua.
local src = debug.getinfo(1, "S").source:gsub("^@", "")
if not src:match "^/" then
  src = (os.getenv "PWD" or ".") .. "/" .. src
end
local root = src:gsub("sketchybar/top/tests/dump_composition.lua$", "")
if root == src then
  root = (os.getenv "DOTFILES" or (os.getenv "HOME" .. "/.dotfiles")) .. "/"
end

package.path = root
  .. "sketchybar/?.lua;"
  .. root
  .. "sketchybar/top/?.lua;"
  .. package.path

local groups = require "groups"
local init_f = assert(io.open(root .. "sketchybar/top/items/init.lua", "r"))
local init_src = init_f:read "*a"
init_f:close()

local function has(pat)
  return init_src:find(pat, 1, true) ~= nil
end

print("bar: solid floating strip")
print("left: " .. table.concat(groups.left, " "))
print("center: " .. table.concat(groups.center or {}, " "))
print("right: " .. table.concat(groups.right, " "))
print("yabai_spaces=" .. tostring(has "items.yabai_spaces"))
print("media=" .. tostring(has 'require "items.media"'))
print("nowplaying_cli=" .. tostring(init_src:find("nowplaying%-cli") ~= nil))
print("weather=" .. tostring(has 'require "items.weather"'))
print("calendar=" .. tostring(has 'require "items.calendar"'))
print("brew=" .. tostring(has 'require "items.brew"'))
print("coffee=" .. tostring(has 'require "items.coffee"'))
print("mic=" .. tostring(has 'require "items.mic"'))
print("ccu=" .. tostring(has 'require "items.ccu"'))
print("vpn=" .. tostring(has 'require "items.vpn"'))
