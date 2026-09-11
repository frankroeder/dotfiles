-- Notch panel is 3024x1964 (1890 was the pre-notch crop). 1.5 is not a
-- legal 1/120 scale on 1964; Hyprland snaps it to 4/3.
hl.monitor {
  output = "eDP-1",
  mode = "3024x1964@120.000",
  position = "0x0",
  scale = 1.333334,
}

-- Both externals arrive as HDMI-A-1. Rules are desc:-keyed so a sink
-- swap cannot inherit the other panel's geometry. asahi-hdmi reapplies
-- the matching block after link training (and on sync if identity drifted).
--
-- LG UltraFine: left of the laptop, 4K @ 1.875 (logical 2048x1152).
-- x must be -2048, not -2560 (that was 3840/1.5 and left a 512px cursor gap).
hl.monitor {
  output = "desc:LG Electronics LG ULTRAFINE 112NTMX6B267",
  mode = "3840x2160@60.000",
  position = "-2048x-360",
  scale = 1.875,
}

-- Dell P2723DE: above the laptop, 1440p @ 1.25 (logical 2048x1152).
-- Not the UltraFine's left-side stack — y = -1152 so the bottom edge meets eDP-1.
hl.monitor {
  output = "desc:Dell Inc. DELL P2723DE 895ZNR3",
  mode = "2560x1440@59.95100",
  position = "0x-1152",
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

hl.workspace_rule { workspace = "1", monitor = "HDMI-A-1" }
hl.workspace_rule { workspace = "2", monitor = "HDMI-A-1" }
hl.workspace_rule { workspace = "3", monitor = "HDMI-A-1" }
hl.workspace_rule { workspace = "4", monitor = "HDMI-A-1" }

-- Lid close: only eDP-1 (not external/HDMI). asahi-idle-brightness off (panel bl + kbd) + dpms off eDP-1.
-- Apple Silicon names this switch "Apple SMC power/lid events", not "Lid Switch".
-- locked = true so the bind still fires on the lock screen.
hl.bind(
  "switch:on:Apple SMC power/lid events",
  hl.dsp.exec_cmd "~/.dotfiles/asahi/bin/asahi-idle-brightness off; hyprctl dispatch dpms off eDP-1",
  { locked = true }
)
hl.bind(
  "switch:off:Apple SMC power/lid events",
  hl.dsp.exec_cmd "hyprctl dispatch dpms on eDP-1; ~/.dotfiles/asahi/bin/asahi-idle-brightness restore",
  { locked = true }
)

local hdmi = dotfilesDir .. "/asahi/bin/asahi-hdmi"

local function hdmi_name(m)
  if type(m) == "table" then
    return m.name or ""
  end
  return type(m) == "string" and m or ""
end

local function hdmi_cmd(action, m)
  local n = hdmi_name(m)
  if n ~= "" and not n:match "^HDMI" then
    return
  end
  local cmd = hdmi .. " " .. action
  if n ~= "" then
    cmd = cmd .. " " .. n
  end
  hl.exec_cmd(cmd)
end

hl.on("monitor.added", function(m)
  hdmi_cmd("added", m)
end)
hl.on("monitor.removed", function(m)
  hdmi_cmd("removed", m)
end)
hl.on("config.reloaded", function()
  hl.exec_cmd(hdmi .. " sync")
end)
