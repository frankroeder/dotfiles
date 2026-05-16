local function window_rule(match, props)
  local spec = { match = match }
  for key, value in pairs(props) do
    spec[key] = value
  end
  hl.window_rule(spec)
end

local function layer_rule(namespace, props)
  local spec = { match = { namespace = namespace } }
  for key, value in pairs(props) do
    spec[key] = value
  end
  hl.layer_rule(spec)
end

window_rule({ class = ".*" }, { opacity = "0.97 0.9" })
window_rule({ class = "^(firefox|librewolf)$", title = "^(Picture-in-Picture)$" }, { float = true })
window_rule({ class = "^(zoom)$" }, { float = true })
window_rule({ class = "^(blueman-manager|nm-connection-editor)$" }, { float = true, center = true })

layer_rule("^(volume_osd)$", { no_anim = true })
layer_rule("^(brightness_osd)$", { no_anim = true })
layer_rule("waybar", { blur = true, ignore_alpha = 0.35 })

window_rule({ class = "^(pavucontrol|easyeffects|gnome-control-center|nm-applet)$" }, { float = true, center = true })
window_rule({ class = "^(org.pwmt.zathura|sioyek|evince|okular)$" }, { opacity = "0.98 0.92", pseudo = false })
window_rule({ class = ".*", title = ".*(Open File|Save As|Choose|Preferences|Properties|Dialog).*" }, { float = true, center = true })

layer_rule("^(gtk-layer-shell|notifications|swayosd)$", { blur = true, ignore_alpha = 0.3 })
