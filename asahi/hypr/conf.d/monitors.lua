hl.monitor({
  output = "eDP-1",
  mode = "3024x1890@120.000",
  position = "0x0",
  scale = 1.75,
})

hl.monitor({
  output = "desc:LG Electronics LG ULTRAFINE 112NTMX6B267",
  mode = "3840x2160@60.000",
  position = "-2560x-360",
  scale = 1.5,
})

hl.monitor({
  output = "desc:Dell Inc. DELL P2723DE 895ZNR3",
  mode = "2560x1440@59.95100",
  position = "-160x-1252",
  scale = 1.25,
})

hl.monitor({
  output = "",
  mode = "preferred",
  position = "auto",
  scale = 1.5,
})

hl.workspace_rule({ workspace = "1", monitor = "HDMI-A-1" })
hl.workspace_rule({ workspace = "2", monitor = "HDMI-A-1" })
hl.workspace_rule({ workspace = "3", monitor = "HDMI-A-1" })
hl.workspace_rule({ workspace = "4", monitor = "HDMI-A-1" })
