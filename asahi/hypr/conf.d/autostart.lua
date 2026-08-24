local terminal = "ghostty"

hl.on("hyprland.start", function()
  hl.exec_cmd "dbus-update-activation-environment --systemd WAYLAND_DISPLAY XDG_CURRENT_DESKTOP XDG_SESSION_DESKTOP XDG_SESSION_TYPE HYPRLAND_INSTANCE_SIGNATURE"
  hl.exec_cmd "systemctl --user import-environment WAYLAND_DISPLAY XDG_CURRENT_DESKTOP XDG_SESSION_DESKTOP XDG_SESSION_TYPE HYPRLAND_INSTANCE_SIGNATURE"
  -- Portal Settings (LibreWolf / GTK4 / nvim) read this, not quickshell/ghostty colors.
  hl.exec_cmd "gsettings set org.gnome.desktop.interface color-scheme prefer-dark"
  hl.exec_cmd "gsettings set org.gnome.desktop.interface gtk-theme adw-gtk3-dark"
  hl.exec_cmd "gsettings set org.gnome.desktop.interface icon-theme Papirus-Dark"
  hl.exec_cmd "systemctl --user start hyprland-session.target"
  hl.exec_cmd "systemctl --user start pipewire.socket pipewire-pulse.socket wireplumber.service"
  hl.exec_cmd "systemctl --user restart xdg-desktop-portal-hyprland.service xdg-desktop-portal.service"
  hl.exec_cmd "~/.dotfiles/asahi/autostart-scripts/ssh-keychain"
  hl.exec_cmd "playerctld"
  hl.exec_cmd "hyprpaper"
  hl.exec_cmd "~/.dotfiles/asahi/bin/asahi-start-quickshell"
  hl.exec_cmd "hypridle"
  -- No lock-on-boot: tty1 getty already authenticated this session (Service=login).
  hl.exec_cmd(launch(terminal), { workspace = "1 silent" })
end)
