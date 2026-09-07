-- Shared bootstrap for the top-bar test scripts. Load it as the first line:
--
--   local here = debug.getinfo(1, "S").source:gsub("^@", "")
--   if not here:match "^/" then here = (os.getenv "PWD" or ".") .. "/" .. here end
--   local T = dofile(here:gsub("[^/]+%.lua$", "") .. "prelude.lua")
--
-- Sets package.path for the sketchybar modules and returns the ok/eq/fail
-- counters. Call T.done() at the end to print the summary and set the exit code.

local here = debug.getinfo(1, "S").source:gsub("^@", "")
if not here:match "^/" then
  here = (os.getenv "PWD" or ".") .. "/" .. here
end

local root = here:gsub("sketchybar/top/tests/prelude%.lua$", "")
if root == here then
  root = os.getenv "DOTFILES" or (os.getenv "HOME" .. "/.dotfiles")
  if root:sub(-1) ~= "/" then
    root = root .. "/"
  end
end

package.path = root
  .. "sketchybar/?.lua;"
  .. root
  .. "sketchybar/?/init.lua;"
  .. root
  .. "sketchybar/top/?.lua;"
  .. package.path

local T = { root = root, failures = 0 }

function T.fail(msg)
  T.failures = T.failures + 1
  io.stderr:write("FAIL " .. msg .. "\n")
end

function T.ok(cond, msg)
  if cond then
    print("ok  " .. msg)
  else
    T.fail(msg)
  end
end

function T.eq(got, expected, msg)
  if got == expected then
    print("ok  " .. msg)
  else
    T.fail(msg .. " got=" .. tostring(got) .. " expected=" .. tostring(expected))
  end
end

function T.done()
  if T.failures > 0 then
    print(T.failures .. " failed")
    os.exit(1)
  end
  print "all passed"
end

return T
