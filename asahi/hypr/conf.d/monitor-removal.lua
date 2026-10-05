-- Keep your workspace when a monitor goes away (dock unplug, clamshell): Hyprland 0.56.2
-- warps focus first and moves workspaces after, hiding yours (omarchy-mac #608).
-- Inside monitor.focused, hl.get_active_monitor() still returns the monitor being left: remember
-- its workspace for one event-loop turn and refocus it on monitor.removed.

local left_behind = nil
local generation = 0

local function selector(ws)
  if not ws or type(ws.id) ~= "number" then
    return nil
  end
  -- Named workspaces have negative ids, which a selector reads as relative.
  if ws.id > 0 then
    return tostring(ws.id)
  end
  return "name:" .. ws.name
end

local function later(fn)
  hl.timer(fn, { timeout = 1, type = "oneshot" })
end

hl.on("monitor.focused", function(monitor)
  generation = generation + 1
  left_behind = nil

  local leaving = hl.get_active_monitor()
  if not leaving or not monitor or leaving.name == monitor.name then
    return
  end
  -- An open scratchpad already comes along to the front of the next monitor.
  if hl.get_active_special_workspace(leaving) then
    return
  end

  left_behind = selector(hl.get_active_workspace(leaving))
  local seen = generation
  later(function()
    if generation == seen then
      left_behind = nil
    end
  end)
end)

-- Loaded after monitors.lua, so this runs after its handler; later() lets Hyprland's own
-- workspace moves finish first.
hl.on("monitor.removed", function()
  local workspace = left_behind
  left_behind = nil
  if not workspace then
    return
  end
  later(function()
    if selector(hl.get_active_workspace()) ~= workspace and hl.get_workspace(workspace) then
      hl.dispatch(hl.dsp.focus { workspace = workspace })
    end
  end)
end)
