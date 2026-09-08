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

-- Media and pickers stay fully opaque; the global 0.97/0.9 wash tints video.
window_rule({
  class = "^(zoom|vlc|mpv|org\\.kde\\.kdenlive|com\\.obsproject\\.Studio|imv|org\\.gnome\\.NautilusPreviewer)$",
}, { opacity = "1 1" })

-- PiP: pin a 16:9 tile to the top-right. Title match only — a bare
-- "Meet - …" rule would also float the main meeting window.
window_rule({ title = "(Picture.?in.?[Pp]icture)" }, {
  float = true,
  pin = true,
  size = { 600, 338 },
  keep_aspect_ratio = true,
  border_size = 0,
  opacity = "1 1",
  move = { "(monitor_w-window_w-40)", "(monitor_h*0.04)" },
})

window_rule({ class = "^(zoom)$" }, { float = true })
window_rule({ class = "^(blueman-manager|nm-connection-editor)$" }, { float = true, center = true })
window_rule({ class = "^(gcr-prompter)$" }, { float = true, center = true })
window_rule({ class = "^(xdg-desktop-portal-gtk)$" }, { float = true, center = true })

-- Recording face-cam. Class is WebcamOverlay-{small,medium,large} so this
-- does not inherit mpv's generic float/center rules.
window_rule({ class = "^WebcamOverlay-small$" }, {
  size = { "(monitor_h*4/25)", "(monitor_h*9/50)" },
  move = { "(monitor_w-monitor_h*4/25-40)", "(monitor_h-monitor_h*9/50-40)" },
})
window_rule({ class = "^WebcamOverlay-medium$" }, {
  size = { "(monitor_h*2/9)", "(monitor_h/4)" },
  move = { "(monitor_w-monitor_h*2/9-40)", "(monitor_h-monitor_h/4-40)" },
})
window_rule({ class = "^WebcamOverlay-large$" }, {
  size = { "(monitor_h*3/10)", "(monitor_h*27/80)" },
  move = { "(monitor_w-monitor_h*3/10-40)", "(monitor_h-monitor_h*27/80-40)" },
})
window_rule({ class = "^WebcamOverlay-(small|medium|large)$", title = "^WebcamOverlay$" }, {
  float = true,
  pin = true,
  no_initial_focus = true,
  opacity = "1 1",
})

-- Trackpad scrolling in the terminal is far too fast at the global
-- scroll_factor, because ghostty scrolls by lines rather than pixels. 0.2 is
-- omarchy's Asahi value for exactly this pairing.
window_rule({ class = "^(com\\.mitchellh\\.ghostty)$" }, { scroll_touchpad = 0.2 })

-- Quickshell (bar + popups + OSD + notif toast from NotificationServer in remix/shell.qml)
layer_rule("^(quickshell.*)$", { blur = true, ignore_alpha = 0.3 })
-- Launcher / wallpaper overlays: keep blur visible under a light frosted dim.
layer_rule("^(quickshell-launcher|quickshell-wallpaper|quickshell-pkgman)$", { blur = true, ignore_alpha = 0.05, xray = false })
layer_rule("^asahi-dim$", { no_anim = true, animation = "none" })

window_rule(
  { class = "^(pavucontrol|easyeffects|gnome-control-center|nm-applet)$" },
  { float = true, center = true }
)
window_rule(
  { class = "^(org.pwmt.zathura|sioyek|evince|okular)$" },
  { opacity = "0.98 0.92", pseudo = false }
)
window_rule(
  { class = ".*", title = ".*(Open File|Save As|Choose|Preferences|Properties|Dialog).*" },
  { float = true, center = true }
)
window_rule(
  { class = "^(hyprland-share-picker)$" },
  { float = true, center = true, opacity = 1.0, pseudo = false }
)

layer_rule("^(gtk-layer-shell)$", { blur = true, ignore_alpha = 0.3 }) -- notifications removed (mako purged; QS notif toast covered by quickshell.*)
layer_rule("^(ghostty-quick-terminal)$", { blur = true, ignore_alpha = 0.05, xray = false })
