-- Notch panel is 3024x1964 (1890 was the pre-notch crop). 1.5 is not a
-- legal 1/120 scale on 1964; Hyprland snaps it to 4/3.
hl.monitor {
  output = "eDP-1",
  mode = "3024x1964@120.000",
  position = "0x0",
  scale = 1.333334,
}

-- Known panels are desc:-keyed, so HDMI-A-1 and a USB-C DP-* share
-- geometry. asahi-hdmi reapplies the matching block after HDMI link
-- training (and on sync if identity drifted).
--
-- LG UltraFine: left of the laptop, 4K @ 1.875 (logical 2048x1152).
-- x must be -2048, not -2560 (that was 3840/1.5 and left a 512px cursor gap).
hl.monitor {
  output = "desc:LG Electronics LG ULTRAFINE 112NTMX6B267",
  mode = "3840x2160@60.000",
  position = "-2048x-360",
  scale = 1.875,
}

-- Dell P2723DE: left of the laptop, bottoms aligned, 1440p @ 1.25
-- (logical 2048x1152). eDP-1 at 4/3 is 1473 tall, so y = 321.
-- asahi-hdmi recomputes y from the session eDP scale (scale 2 → y = -170).
hl.monitor {
  output = "desc:Dell Inc. DELL P2723DE 895ZNR3",
  mode = "2560x1440@59.95100",
  position = "-2048x321",
  scale = 1.25,
}

-- Last named rule for HDMI-A-1: skip the udev-tick modeset (DCP not ready).
-- asahi-hdmi enables after link training; that eval must set disabled = false.
hl.monitor {
  output = "HDMI-A-1",
  disabled = true,
}

hl.monitor {
  output = "",
  mode = "preferred",
  position = "auto",
  scale = 1.5,
}

-- Workspaces 1-4 follow the external that is actually up. A static
-- HDMI-A-1 name misses USB-C (DP-1). Retarget on add, remove, and reload.

-- Lid: asahi-clamshell disables eDP-1 while an external is enabled (clamshell,
-- persisted for the session). Without an external it is a no-op — logind
-- suspends; do not DPMS-blank here (races s2idle, hangs DCP). Apple Silicon names
-- this switch "Apple SMC power/lid events", not "Lid Switch".
-- locked = true so the bind still fires on the lock screen.
local clamshell = dotfilesDir .. "/asahi/bin/asahi-clamshell"
hl.bind("switch:on:Apple SMC power/lid events", hl.dsp.exec_cmd(clamshell .. " close"), { locked = true })
hl.bind("switch:off:Apple SMC power/lid events", hl.dsp.exec_cmd(clamshell .. " open"), { locked = true })

local hdmi = dotfilesDir .. "/asahi/bin/asahi-hdmi"
local scale = dotfilesDir .. "/asahi/bin/asahi-monitor-scale"

-- monitor.added/removed hand an HL.Monitor *userdata*, not a table.
local function monitor_name(m)
  if type(m) == "string" then
    return m
  end
  if type(m) == "table" or type(m) == "userdata" then
    return type(m.name) == "string" and m.name or ""
  end
  return ""
end

-- An unknown name must be a no-op: `asahi-hdmi <action>` without an argument
-- defaults to HDMI-A-1, so disabling eDP-1 used to switch off the external.
local function hdmi_cmd(action, m)
  local n = monitor_name(m)
  if not n:match "^HDMI" then
    return
  end
  hl.exec_cmd(hdmi .. " " .. action .. " " .. n)
end

-- USB-C (DP-*) needs no enable gate, but its desc rule assumes eDP at 4/3: `asahi-hdmi place`
-- re-derives the position from the session eDP scale. On reload `asahi-monitor-scale apply`
-- places DP after re-applying the scales; doing it from config.reloaded too would race.
local function dp_place(m)
  local n = monitor_name(m)
  if n:match "^DP" then
    hl.exec_cmd(hdmi .. " place " .. n)
  end
end

-- prefer is the output that just appeared. A name not yet in the layout
-- (HDMI still disabled) is remembered so the next switch creates 1-4 there.
local function external_target(prefer)
  local monitors = hl.get_monitors()
  local function listed(name)
    if type(monitors) ~= "table" or name == "" then
      return false
    end
    for _, m in ipairs(monitors) do
      if monitor_name(m) == name then
        return true
      end
    end
    return false
  end

  local want = monitor_name(prefer)
  if want == "eDP-1" then
    want = ""
  end
  if listed(want) then
    return want, true
  end
  if type(monitors) == "table" then
    for _, m in ipairs(monitors) do
      local n = monitor_name(m)
      if n ~= "" and n ~= "eDP-1" then
        return n, true
      end
    end
  end
  if want ~= "" then
    return want, false
  end
  return "", false
end

local function pin_external_workspaces(prefer)
  local n, live = external_target(prefer)
  if n == "" then
    return
  end
  for i = 1, 4 do
    local id = tostring(i)
    hl.workspace_rule { workspace = id, monitor = n }
    if live then
      local ws = hl.get_workspace(id)
      if ws and monitor_name(ws.monitor) ~= n then
        hl.dispatch(hl.dsp.workspace.move { workspace = id, monitor = n })
      end
    end
  end
end

hl.on("monitor.added", function(m)
  hdmi_cmd("added", m)
  dp_place(m)
  pin_external_workspaces(m)
end)
hl.on("monitor.removed", function(m)
  hdmi_cmd("removed", m)
  -- External gone while in clamshell: bring eDP-1 back, never zero outputs.
  hl.exec_cmd(clamshell .. " apply")
  pin_external_workspaces()
end)
-- A reload re-applies the static rules above; restore the session overrides.
hl.on("config.reloaded", function()
  hl.exec_cmd(hdmi .. " sync")
  hl.exec_cmd(scale .. " apply")
  hl.exec_cmd(clamshell .. " apply")
  pin_external_workspaces()
end)
