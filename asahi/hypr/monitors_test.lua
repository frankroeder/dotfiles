-- monitors.lua hotplug hooks under a stub `hl` and a fake sysfs (run by asahi/bin/asahi_hdmi_test.sh).
local dir = arg[0]:match "^(.*)/[^/]*$" or "."
local status, calls, hooks, off = {}, {}, {}, {}
local fail = 0

local real_open = io.open
io.open = function(path, mode)
  local card, n = path:match "^/sys/class/drm/card(%d+)%-(.+)/status$"
  if not card then return real_open(path, mode) end
  if card ~= "2" or not status[n] then return nil end
  local v = status[n]
  return { read = function() return v end, close = function() end }
end

dotfilesDir = "/D"
hl = {
  monitor = function(r) if r.disabled then off[r.output] = true end end,
  bind = function() end,
  workspace_rule = function() end,
  get_monitors = function() return {} end,
  get_monitor = function() return nil end,
  on = function(ev, fn) hooks[ev] = fn end,
  exec_cmd = function(c) calls[#calls + 1] = c end,
  dsp = { exec_cmd = function(c) return c end },
}

local function load() hooks = {}; dofile(dir .. "/conf.d/monitors.lua") end
local function fire(ev, m) calls = {}; hooks[ev](m) end
local function ran(cmd)
  local n = 0
  for _, c in ipairs(calls) do if c == "/D/asahi/bin/" .. cmd then n = n + 1 end end
  return n
end
local function check(ok, msg)
  print((ok and "ok  " or "FAIL ") .. msg)
  if not ok then fail = 1 end
end

load()
check(off["HDMI-A-1"] and off["DP-1"] and off["DP-3"] and off["DP-6"], "HDMI and every USB-C DP-n start disabled")
fire "monitor.layout_changed"
check(#calls == 0, "nothing plugged: no asahi-hdmi")

status["DP-1"] = "connected"
fire "monitor.layout_changed"
check(ran "asahi-hdmi added DP-1" == 1, "plug: one settle")
fire "monitor.layout_changed"
check(ran "asahi-hdmi added DP-1" == 0, "later layout changes start none")

fire("monitor.removed", { name = "DP-1" })
check(ran "asahi-hdmi removed DP-1" == 1 and ran "asahi-hdmi added DP-1" == 0, "disabled with the cable in: stays off")

status["DP-1"] = "disconnected"
fire("monitor.removed", { name = "DP-1" })
status["DP-1"] = "connected"
fire "monitor.layout_changed"
check(ran "asahi-hdmi added DP-1" == 1, "unplug while disabled, replug: settle again")

fire("monitor.removed", { name = "eDP-1" })
check(ran "asahi-hdmi removed eDP-1" == 0 and ran "asahi-clamshell apply" == 1, "eDP-1 is never asahi-hdmi's")

status["HDMI-A-1"] = "connected"
fire "monitor.layout_changed"
check(ran "asahi-hdmi added HDMI-A-1" == 1 and ran "asahi-hdmi added DP-1" == 0, "HDMI plug: its own settle")

load()  -- reload: fresh Lua state, both still plugged
fire "config.reloaded"
check(ran "asahi-hdmi sync HDMI-A-1" == 1 and ran "asahi-hdmi sync DP-1" == 1 and ran "asahi-hdmi sync DP-2" == 0,
  "reload syncs the connectors this DT has")
fire "monitor.layout_changed"
check(ran "asahi-hdmi added DP-1" == 1 and ran "asahi-hdmi added HDMI-A-1" == 1, "reload: one settle each")

fire("monitor.added", { name = "DP-1" })
check(ran "asahi-hdmi added DP-1" == 0, "monitor.added (fired once enabled) starts no second settle")

status["DP-2"] = "connected"  -- Aurora DT: another USB-C port
fire "monitor.layout_changed"
check(ran "asahi-hdmi added DP-2" == 1 and ran "asahi-hdmi added DP-1" == 0, "DP-2 plug: its own settle")
fire("monitor.removed", { name = "DP-2" })
check(ran "asahi-hdmi removed DP-2" == 1, "DP-2 unplug: asahi-hdmi removed")

os.exit(fail)
