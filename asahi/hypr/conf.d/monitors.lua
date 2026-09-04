hl.monitor {
  output = "eDP-1",
  mode = "3024x1890@120.000",
  position = "0x0",
  scale = 1.5,
}

hl.monitor {
  output = "desc:LG Electronics LG ULTRAFINE 112NTMX6B267",
  mode = "3840x2160@60.000",
  position = "-2560x-360",
  scale = 1.88,
}

hl.monitor {
  output = "desc:Dell Inc. DELL P2723DE 895ZNR3",
  mode = "2560x1440@59.95100",
  position = "0x-1252",
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
