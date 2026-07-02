# General

These dotfiles target macOS (Apple Silicon), Linux x86, Asahi Fedora (aarch64 ARM).
Share as much as possible across OS while respecting arch diffs.
Makefile defines 5 profiles (micro, minimal, linux, macos, asahi) using symlinks,
brew/dnf installs, services. macOS WM: yabai+skhd or aerospace/flashspace +
sketchybar (lua configs for top/bottom bars in sketchybar/{top,bottom}/).
Asahi: Hyprland (modular lua: asahi/hypr/hyprland.lua + conf.d/*.lua),
quickshell (QML in asahi/quickshell/remix/ for bar/launcher/wallpaper on quicks branch)
+ hyprpaper/hyprlock/hypridle +
ghostty, custom asahi/bin scripts. Shared: nvim (full lua/),
zsh (zim+dots), mpv, ghostty. Always differentiate Linux by arch. Profiles:

- `micro` setup with bash, tmux, and htop where there are almost no rights for the user
- `minimal` setup with nvim, zsh, python, node and more tools installed locally without sudo
- `linux` setup for desktop and server settings with the full suite for both sudo and non-sudo users
- `macos` setup with the full suite of applications, window management and applications for native Apple Silicon
- `asahi` setup with the full suite of applications, window management and applications for Linux ARM

---

We need to always differentiate between the different Linux settings with respect to architecture.

# Executing

- always try to run scripts that do not break the system (have smoketests) and verify that symlinks are present
- always inspect the outputs of scripts and programs yourself to identify bugs and issues

# Documentation

## macOS
- yabai (tiling WM, bspwm-like): https://github.com/asmvik/yabai/wiki
- skhd (hotkey daemon): https://github.com/koekeishiya/skhd
- SketchyBar (lua status bars): https://felixkratz.github.io/SketchyBar/
- AeroSpace (i3/sway-like): https://nikitabobko.github.io/AeroSpace/
- FlashSpace: https://github.com/wojciech-kulik/FlashSpace
- Ghostty: https://ghostty.org/docs

## Asahi Linux Fedora
- Fedora Asahi Remix: https://asahilinux.org/fedora/
- Hyprland wiki: https://wiki.hypr.land/
- hyprpaper (wallpaper daemon): https://wiki.hypr.land/Hypr-Ecosystem/hyprpaper/
- hyprlock (screen locker): https://wiki.hypr.land/Hypr-Ecosystem/hyprlock/
- hypridle (idle daemon): https://wiki.hypr.land/Hypr-Ecosystem/hypridle/
- Quickshell (QML toolkit, bar/launcher + native notifications): https://quickshell.org/docs/
- **QML singletons (Quickshell/Qt6)**: `pragma Singleton` is ignored without `qmldir` registration. `import "File.qml" as X` silently falls back to white/black defaults. Create `qmldir` in module dirs (`singleton Name File.qml`), use module imports (`import "../foo"`), reference by registered name (`Foo.bar`). Prefer Quickshell `Singleton` root type (reloadable) over QtObject. Never `Foo {}` construct singletons.

## Shared
- Neovim: https://neovim.io/doc/
- Zsh: https://zsh.sourceforge.io/Doc/
- Ghostty: https://ghostty.org/docs
- mpv: https://mpv.io/manual/stable/

# SketchyBar layout (macOS)

Three instances: `sketchybar` (bottom), `sketchybar-top` (top), `sketchybar-island` (notch pill).
Config in `sketchybar/{bottom,top,island}/`; shared lua at `sketchybar/*.lua`. Reload each
with `<bin> --reload`. Prefer plain `require` for items (fail loud), not safe_require.

Requirements / decisions:
- Island pill follows the active theme (`theme.surface`/`theme.border`), never hardcoded black.
- Island is notch-aware: on the built-in (notched) display keep full width to straddle the notch;
  on external/notchless displays subtract the notch allowance (`effective_width` in island_core).
- Island shows ONLY on the focused display: every `sbar.bar` mutation carries `display = <focused>`.
  Focused display comes from `display.focused_index()`, which filters yabai's `has-focus` display
  (NOT `--display focused` — that is an invalid yabai DISPLAY_SEL and silently fails).
- Island items must NOT be display-pinned: no `display = ...` in the island's `sbar.default` or
  items. A pinned item renders only on that display, so the pill shows as an EMPTY capsule when
  the bar moves elsewhere. Verify via `--query island.main` → `geometry.associated_display_mask`
  must be 0. (`--query bar` does not expose `display`, so it can't verify bar targeting.)
- Island pill margins must be computed from the TARGET display's width (display.displays rows),
  never from `main_width` — island_core owns geometry; theme repaints delegate to
  `island_core.refresh_theme()` (recolor-only while expanded).
- Appswitch pill dedups on app name (`last_app`) — when testing with manual
  `--trigger front_app_switched INFO=...`, use a fresh name each time.
- Island expand height reserved by yabai `external_bar` top = appswitcher pill (`idle_height +
  y_offset_expand`), parsed from settings.lua in yabairc. Needs `yabai --restart-service` to apply.
- Top bar renders on ALL displays (no display pin). In dual-monitor `notch_width` stays 0 (avoids
  external cutout artifacts); the built-in notch is covered by the island pill, not a bar cutout.
- No `front_app` top widget: deleted. The island appswitch pill is the app indicator, driven
  directly by the native `front_app_switched` event in the island instance.
- No high-CPU alert pill.
- GPU widget (bottom): single-row `GPU 00%` label · graph · centered temp (the committed layout).
- Bar presets in settings.lua: `transparent` (default, invisible bar) / `gnix` (solid+blur).

# Hints

When working with sketchybar, you can inspect for both bars the logs in `/opt/homebrew/var/log/sketchybar/sketchybar.* /tmp/sketchybar-top.*` to inspect print outputs and much more.
Make sure to clean those files to track the latest changes.
