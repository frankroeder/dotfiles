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

-- Lid: Apple Silicon names this switch "Apple SMC power/lid events", not "Lid Switch".
-- Docked + closed (clamshell) disables eDP-1 so workspaces leave the black panel.
-- Undocked + closed keeps DPMS + idle-brightness (no lock — tty1/hypridle own that).
-- locked = true so the bind still fires on the lock screen.
hl.bind(
  "switch:on:Apple SMC power/lid events",
  hl.dsp.exec_cmd(dotfilesDir .. "/asahi/bin/asahi-monitor-internal clamshell"),
  { locked = true }
)
hl.bind(
  "switch:off:Apple SMC power/lid events",
  hl.dsp.exec_cmd(dotfilesDir .. "/asahi/bin/asahi-monitor-internal clamshell"),
  { locked = true }
)
