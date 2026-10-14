hl.on("hyprland.start", function()
  -- --systemd also imports into the user manager (no separate `systemctl --user import-environment`).
  hl.exec_cmd("dbus-update-activation-environment --systemd WAYLAND_DISPLAY XDG_CURRENT_DESKTOP XDG_SESSION_DESKTOP"
    .. " XDG_SESSION_TYPE HYPRLAND_INSTANCE_SIGNATURE")
  -- gnome-keyring owns org.freedesktop.secrets (kwallet is disabled). SSH stays with keychain.
  hl.exec_cmd "~/.dotfiles/asahi/bin/asahi-gnome-keyring"
  -- Fallback dark until asahi-autotheme reads wallpaper lightness (gsettings + GTK + icons).
  -- Firefox / GTK4 / Qt-via-gtk3 / nvim follow this portal signal, not quickshell hex.
  hl.exec_cmd "gsettings set org.gnome.desktop.interface color-scheme prefer-dark"
  hl.exec_cmd "gsettings set org.gnome.desktop.interface gtk-theme adw-gtk3-dark"
  hl.exec_cmd "gsettings set org.gnome.desktop.interface icon-theme Papirus-Dark"
  hl.exec_cmd "systemctl --user start hyprland-session.target"
  hl.exec_cmd "systemctl --user start pipewire.socket pipewire-pulse.socket wireplumber.service"
  -- gtk portal owns org.freedesktop.impl.portal.Settings (Hyprland does not).
  hl.exec_cmd "systemctl --user restart xdg-desktop-portal-hyprland.service xdg-desktop-portal-gtk.service xdg-desktop-portal.service"
  hl.exec_cmd "~/.dotfiles/asahi/bin/asahi-ssh-keychain"
  hl.exec_cmd "playerctld"
  -- F6 (moon) is KEY_SLEEP: logind suspended on a tap, past every asahi-idle guard (external display,
  -- audio). This block lock makes logind leave the key to Hyprland (XF86Sleep = Do Not Disturb) for the
  -- session only; active sessions may take it without root (polkit inhibit-handle-suspend-key).
  hl.exec_cmd "systemd-inhibit --what=handle-suspend-key --who=Hyprland --why=F6-is-Do-Not-Disturb --mode=block sleep infinity"
  hl.exec_cmd "~/.dotfiles/asahi/bin/asahi-cliphist watch"
  hl.exec_cmd "hyprpaper"
  hl.exec_cmd "~/.dotfiles/asahi/bin/asahi-start-quickshell"
  -- Not Fedora's hypridle.service: hyprlock, the saver and asahi-idle's loops would live in the unit's
  -- cgroup (a crash restart kills the lock screen: lockdead), and `qs ipc` from the unit's env (no
  -- QT_QPA_PLATFORM) cannot find the shell, so dim and saver would fail silently.
  hl.exec_cmd "hypridle"
  -- Identity profile in hyprsunset.conf: no tint until Super+Ctrl+N.
  hl.exec_cmd "hyprsunset"
  hl.exec_cmd(dotfilesDir .. "/asahi/bin/asahi-hdmi sync")
  -- Restore wallpaper-adaptive theme (Quickshell / Ghostty / borders / browsers / gsettings).
  hl.exec_cmd(dotfilesDir .. "/asahi/bin/asahi-autotheme")
  -- No lock-on-boot: tty1 getty already authenticated this session (Service=login).
  hl.exec_cmd(launch(terminal), { workspace = "1 silent" })
end)
