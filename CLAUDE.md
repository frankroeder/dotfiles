# General

These dotfiles target macOS (Apple Silicon), Linux x86, Asahi Fedora (aarch64 ARM).
Share as much as possible across OS while respecting arch diffs.
Makefile defines 5 profiles (micro, minimal, linux, macos, asahi) using
symlinks, brew/dnf installs, services. Always differentiate Linux by arch.

- macOS WM: yabai+skhd or aerospace/flashspace + sketchybar (`sketchybar/{top,bottom,island}/`)
- Asahi: Hyprland (`asahi/hypr/hyprland.lua` + `conf.d/*.lua`), quickshell remix
  (`asahi/quickshell/remix/`), hyprpaper/hyprlock/hypridle, ghostty, `asahi/bin`
- Shared: nvim (`lua/`), zsh (zim+dots), mpv, ghostty

Profiles: `micro` (bash/tmux/htop, almost no rights), `minimal` (nvim/zsh/python/node,
local, no sudo), `linux` (full desktop/server), `macos` (Apple Silicon suite), `asahi`
(Linux ARM suite).

# Executing

- Run smoketests; inspect outputs; verify symlinks.
- Required-step failures must fail the installer (not warn-only).
- doctor must not flag Hyprland on generic Linux.

# Documentation

## macOS
- yabai: https://github.com/asmvik/yabai/wiki
- skhd: https://github.com/asmvik/skhd
- SketchyBar: https://felixkratz.github.io/SketchyBar/
- AeroSpace: https://nikitabobko.github.io/AeroSpace/
- FlashSpace: https://github.com/wojciech-kulik/FlashSpace
- Ghostty: https://ghostty.org/docs

## Asahi Linux Fedora
- Fedora Asahi Remix: https://asahilinux.org/fedora/
- Hyprland: https://wiki.hypr.land/
- hyprpaper / hyprlock / hypridle: https://wiki.hypr.land/Hypr-Ecosystem/
- Quickshell: https://quickshell.org/docs/

- **QML singletons**: `pragma Singleton` is ignored without `qmldir`. `import "File.qml" as X`
  silently falls back to white/black. Register (`singleton Name File.qml`), module-import,
  reference by name. Prefer Quickshell `Singleton` (reloadable). Never `Foo {}` construct them.
- **Lock on boot**: getty on tty1 is the auth gate — do not hyprlock after Hyprland starts, and
  do not `agetty --autologin` (zsh/zprofile can fall through to an unauthenticated shell).
  Leftover `/etc/systemd/system/getty@tty1.service.d/10-asahi-autologin.conf`:
  `./install.sh asahi-getty` (also `comp_asahi_system`). Do not restart `getty@tty1` live (kills
  Hyprland). No display manager. Super+Escape and hypridle still lock.
- **Console**: `asahi/vconsole.conf` — `KEYMAP="de-latin1-nodeadkeys"` (legacy kbd map, counterpart
  of `input.lua` `de`/`mac_nodeadkeys`) and `FONT="ter-v32n"`. xkb-converted maps under
  `/usr/lib/kbd/keymaps/xkb/` fail (`lk_add_key … keycode -1`); `mac-*` maps compile but use ADB
  keycodes and scramble `hid_apple`. Check: `loadkeys --mktable <name> >/dev/null`. Font lives in
  vconsole.conf (installed by `comp_asahi_system`) — a setfont unit loses to later
  `systemd-vconsole-setup`.
- **Sleep / lid / HDMI**: Asahi is s2idle only (`freeze`/`mem`; zram is not a resume image). No
  Hibernate row; logind/sleep drop-ins ignore hibernate keys; `systemctl suspend`. Power tap:
  `HandlePowerKey`/`…LongPress=ignore` in `asahi/systemd/logind.conf.d/10-asahi-sleep.conf`
  (`./install.sh asahi-logind` also installs the udev rule + inhibit unit; HUP logind, never restart
  it; never `udevadm trigger` drm — that hotplugs HDMI). `InhibitDelayMaxSec=15` gives hyprlock time
  on lid close. gsettings `power-button-action` is a GNOME no-op here. ~10s hold is SMC force-reset.
  Lid switch is `Apple SMC power/lid events` (`locked = true` in `monitors.lua`). Do **not** set
  `HandleLidSwitch` — laptop-only close is logind `suspend`; docked (`sysfs enabled=enabled`) is
  `HandleLidSwitchDocked=ignore` and `asahi-clamshell` disables eDP-1. Clamshell close is a no-op
  without a Hyprland-enabled external (do not DPMS-blank eDP there — races s2idle, `8000000a`,
  hangs). HDMI-A-1 stays `disabled = true` in `monitors.lua` until `asahi-hdmi` (~2s) sets
  `disabled = false`. logind does not count that cable as docked, so
  `asahi-hdmi-lid-inhibit.service` (udev on HDMI `status`) holds `handle-lid-switch`; the drop-in
  sets `LidSwitchIgnoreInhibited=no`. `asahi-dpms` only touches Hyprland-enabled outputs. Two hangs,
  one recovery (hold power ~10s, wait ~15s, tap power): laptop-only lid close can reach s2idle and
  never exit, and a live HDMI plug can freeze DCP (`valid_mode:0` + eDP flip) — **do not close the
  lid** after one. `after_sleep_cmd` only runs on a real `suspend exit`. Diagnose `journalctl -b -1` (`Lid closed.` → `Suspending...` →
  `PM: suspend entry` with no `suspend exit`). Do not add `asahi-hdmi sync` to resume. Test:
  `asahi/bin/asahi_hdmi_test.sh`.
- **Clamshell / outputs**: never zero outputs — enable the external (`disabled = false`) before
  eDP-1 goes dark. `asahi-clamshell apply` on `config.reloaded` / `monitor.removed` brings eDP back
  if the external vanishes. `hl.on("monitor.added"/"removed")` hands **userdata**; read `.name`,
  and an unknown name is a no-op (`asahi-hdmi` with no arg defaults to HDMI-A-1). Mirroring
  `HDMI-A-1` strands workspaces 1–4 — mirror eval is **only** `mirror = <source>` (no `mode` /
  `position`). Source must be an enabled output. Undo: Unmirror/Extend, `Super+Ctrl+Alt+R`, or the
  Monitors pane 15 s auto-revert (unless Keep).
- **Notch / fnmode**: `comp_asahi_system` writes `asahi-notch.conf` (`show_notch=1`) and
  `hid_apple fnmode=1`, then `dracut -f`. Reboot required. Live fnmode:
  `/sys/module/hid_apple/parameters/fnmode`.
- **Keyboard / display brightness**: `XF86Search` / `XF86LaunchA` (Shift = fine). Display stays on
  `XF86MonBrightness*` (Shift = fine).
- **Keybinding grammar**: Bare Super = focused window / navigate; Super+Shift = inverse (move vs
  focus); Super+Alt = variant (focus→resize, capture→record). `Super+Alt+HJKL` moves the **shared
  split border** — label by direction, never grow/shrink. `Super+Ctrl+<letter>` = system panel
  (A audio, B bluetooth, D display, W network, P power, S screenshot gallery, T activity, I
  stay-awake, N night light, E emoji, V clipboard, K keybindings). `Super+Ctrl+Alt` restarts the
  stack. `Super+Ctrl+plus/minus` = display scale; `Super+Ctrl+Z` / `Super+Ctrl+Alt+Z` = cursor
  magnifier (`hl.config { cursor = { zoom_factor } }`, lua, not `hyprctl keyword`). Panels:
  `quick()` in `bindings.lua` (`quickActions` in `LauncherWindow.qml`). Super+B/N are free. **Every
  bind needs a `desc`** (`parseHyprBinds` drops descless ones). `code:NN` needs `bindCombo`
  `codeNames` — labels are **de(mac_nodeadkeys)** (`code:34/35` = `ü`/`+`, not `[]`).
- **Monitor direction binds**: `Super+Ctrl+arrows` and `Super+Shift+Ctrl+HJKL` must
  `hl.get_monitor(dir)` first (nil on laptop-only). Generated in `bindings.lua`.
- **Clipboard secrets**: `asahi-cliphist` watchers run `wl-paste --watch <self> store` so
  `store_unless_sensitive` drops `x-kde-passwordManagerHint` (`wl-copy --sensitive`).
  `asahi-cliphist types` shows whether a given copy would be filtered. `start_watcher` pkills the
  old `--watch cliphist store` form.
- **Screenshots**: slurp + grim, no hyprpicker freeze. Super+F10/F11/F12 (window / smart / display)
  and Super+mute/vol-/vol+; macOS aliases Super+Ctrl+Shift+3/4/5 (`code:12/13/14`). OCR/QR:
  Super+Shift/Ctrl+F11. Color: Super+Shift+F12. Record: Super+Alt+F11 region, Super+Alt+F12
  display, Super+Alt+Shift+F12 + webcam (`asahi-webcam`; Super+Alt+ü/+ resize = `code:34/35`).
  Test: `asahi/bin/asahi_webcam_test.sh`.
- **Browser screenshare**: camera/mic work. Chromium needs
  `CHROMIUM_USER_FLAGS=--enable-features=WebRTCPipeWireCapturer` in `env.lua` and
  `environment.d/90-asahi.conf` (Fedora ignores `chromium-flags.conf`). No Google Chrome; Fedora
  ships `hyprland-share-picker`.
- **asahi-debug**: Fedora Asahi health (`asahi/bin/asahi-debug [--json]`). dnf/rpm,
  `wpa_supplicant`, asahi-audio, `speakersafetyd`, `kernel-16k`, HID, notch, sshd mask,
  no-hibernate. Not pacman/iwd/SDDM. Test: `asahi/bin/asahi_debug_test.sh`. Not part of
  `make doctor`; must not flag Hyprland on generic Linux.
- **Night light**: Super+Ctrl+N → `asahi-nightlight` (hyprsunset). On = `hyprsunset.conf` 1500K;
  off = `hyprctl hyprsunset identity`. Identity profile so autostart tints nothing.
- **Bar notch**: cutout is a hole (`BarModel.notchRegionInset`), not a spacer. Height is geometry
  (3024x1964 → **74**). `BarHost.ccuCompact` shortens CCU when the right cluster does not fit;
  `rightOthers` excludes CCU's own width. Anything added to the right cluster eats that budget.
- **Bar tray**: `maxInline` 3, rest behind `+N` → `TrayPanel.qml`. Use `SystemTrayItem.NeedsAttention`
  (no `SystemTrayStatus`). Popups need `screen:` + `exclusionMode: ExclusionMode.Ignore`.
  `HyprlandFocusGrab` dies on `focusable: false`.
- **Launcher quick panes**: one file each in `quickshell/remix/modules/launcher/panes/`;
  `LauncherWindow.qml` does `Panes.XPane { root: launcherSelf }` (`root` inside a pane is that
  property, not the launcher id). Shared M3 widgets in `modules/menu`. A visible Quick tile **must
  have a pane** (`quickPaneKey` falls back to `t.key`); paneless actions go in `quickDeckHidden`
  (`wallpaper_carousel_test.js` derives that list).
- **Recorder**: Super+Alt+R toggles `RecordPanel`. Bar REC chip only while recording (click =
  panel, right-click = stop). `asahi-cmd-record status --json` via `Recorder` singleton. No pause
  (wf-recorder exits on SIGUSR1). IPC: `qs -c remix ipc call recording panel`.
- **Wallpaper**: one picker, `WallpaperManager` (Super+Shift+W). `ipc: "wallpaper"` and
  `wallpaper: true` in `quickDeckHidden` — not a Quick tile; search still finds it. Browse:
  `WallpaperCarousel` (prev/current/next; ←/→, Ctrl+h/l, wheel; ⏎/Apply/click applies,
  Esc restores). Live preview is **opt-in** (`WallpaperService.liveMode`, default off): Shift /
  Shift+←/→ / Live chip; ignore bare Shift in the search field. Debounce 70ms. Color index from
  cached thumbs → `wallpaper_colors.js`; filters on `WallpaperService.arranged(query)`. Test:
  `wallpaper_colors_test.js`.
- **Autotheme**: Hyprland has no portal Settings — `portals.conf` pins Settings to gtk. Flavours
  `source content vibrant calm mono` (`FLAVORS` is the source of truth; saturation is a fraction of
  gamut room, never a multiplier). Writes `~/.local/state/asahi-theme/`. GTK ini is a real file,
  not a symlink. Unset portal `0` = light. Live: Ghostty `reload-config`, Quickshell `FileView`,
  Hyprland borders, btop SIGUSR2. **GTK3 and LibreWolf never repaint live** — do not add watchers.
  LibreWolf autoconfig has no XPCOM; `userChrome.css` is startup-only. Vertical-tabs sidebar is
  shadow DOM — only inherited custom properties cross it. `write_librewolf_css` must emit names
  current Firefox still reads (tests fail on the dead `--lwt-*` / `--toolbar-*` spellings; grep
  both `omni.ja` files, exclude `chrome/devtools`, require a non-name char after the ident).
  Tests: `asahi/theme/tests/test_palette.py`, `asahi/theme/smoke_test.sh`.
- **sshd**: Fedora enables it; disable and mask `sshd.service` + `sshd.socket`. Re-check after a
  release upgrade.
- **Notification images**: `localImage()` only `image:`/`file:`/`/…`. Summary/body are
  `Text.PlainText` (no `<img src>`).
- **bash 5.3 / trailing `&&`**: an EXIT trap or function whose last command is `[[ -n $x ]] && …`
  returns 1 when `$x` is empty; under `set -e` that kills the script (`asahi-network` lost JSON
  this way). End traps on `|| true` / `if`; optional tail lines in `if` blocks. Interactive zsh
  helpers without `set -e` are fine.
- **Apple HID race**: dockchannel-hid binds `hid-generic` first; `asahi/dracut.conf.d/10-asahi-hid.conf`
  force-loads `hid_apple` only (`hid_magicmouse` is builtin). Verify
  `/sys/bus/hid/drivers/` + `readlink -f /sys/bus/hid/devices/*/driver`.
- **Audio**: Fedora Asahi already ships the stack — do not port omarchy's Apple audio.sh. RT check
  is the **thread**: `ps -eLo comm,rtprio,cls | grep data-loop` → `20 RR`.
- **Trackpad**: `tap_to_click = true` (omarchy uses false on Asahi). No touchpad toggle;
  `disable_while_typing` only. Pointer feel is the `hl.device` curve on `apple-mtp-multi-touch` in
  `input.lua` (libinput ignores `sensitivity` under a custom profile). `hyprctl reload` does **not**
  reset a device — keep that explicit rule or a bad `hyprctl eval 'hl.device({…})'` survives until
  reboot. `hl.device` checks field names, not values. Terminal scroll: `scroll_touchpad = 0.2` for
  Ghostty in `rules.lua` (also the global factor — keep the rule).
- **WM defaults**: `general.lua` — `dwindle.force_split = 2`, `hide_special_on_workspace_change`,
  `allow_session_lock_restore`, `on_focus_under_fullscreen`, `initial_workspace_tracking = 0`,
  `anr_missed_pings = 3`, `group`/`groupbar` themed to the Catppuccin borders (Super+W groups),
  `hl.gesture` 3-finger workspace swipe (`scale 0.75`, `workspace_swipe_cancel_ratio = 0.25`).
  Validate keys against `/usr/share/hypr/stubs/hl.meta.lua`, then
  `hyprctl reload && hyprctl configerrors`. Lua dispatchers: `hyprctl dispatch 'hl.dsp.…({…})'`
  (legacy `dispatch <name> <args>` is dead). Float is its own call; maximized refuses resize+pin.
- **asahi/bin**: helpers in `asahi/bin/lib/common.sh`, sourced via
  `$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/lib/common.sh`. `asahi-launch` is the only
  `uwsm-app`/`setsid` site. Sibling paths through that dirname, not `$HOME/.dotfiles`.
  `components.sh` chmods `asahi/bin/*` and skips `lib/` (a dir) — keep sourced files there.
- **Quickshell launch**: never `qs -d` (EPIPE/`qFatal` if the parent is gone). `setsid -f qs -n -c
  <module>`. Bar vanished → `asahi-debug` coredumps first.
- **Stay awake**: one flag `$XDG_RUNTIME_DIR/asahi-stay-awake`, owned by `asahi-stay-awake`.
  hypridle listeners run through `unless`.
- **Timers**: `asahi-timer add <dur> [label]` = transient `systemd-run --user --on-active`.
  Launcher `:timer 10m tea` (`arg_commands.js`, tested).
- **Window pop**: Super+O → `asahi-window-pop` (float/resize/center/pin/`pop`); second press
  retiles.
- **Display scale**: Super+Ctrl+plus/minus → `asahi-monitor-scale`. Legal scales are 1/120
  divisors (eDP-1: 1 / 1.333333 / 2). Saved per output name under `$XDG_RUNTIME_DIR`; HDMI-A-1 is
  reused by both sinks. Positions are **derived** (`anchor_offset` in `lib/common.sh`), never pinned.
- **Speed test**: `asahi-speedtest [--json]` — Cloudflare 50 MB down / 25 MB up (~20 s; 100 MB is
  403). Network pane button.
- **Wi-Fi QR**: `asahi-wifi-qr` → `$XDG_RUNTIME_DIR` mode 600; `nmcli -s` for the PSK.
- **Autostart**: `asahi/xdg-autostart/` (only a Hidden stub masking gnome-keyring-ssh) vs Hyprland
  `exec-once` in `autostart.lua`. Verify no `app-gnome\x2dkeyring\x2dssh@autostart.service` under
  the user generator.late.
- **Secrets**: `asahi/kwalletrc` disables kwallet. `gnome-keyring-daemon --components=secrets`
  only; SSH is keychain. Do not start gnome-keyring ssh.
- **SSH / keychain**: Fedora's `/etc/profile.d/keychain.sh` prompts every key on tty1 — export
  `KEYCHAIN_DONE=1` from `zshenv`. `asahi-ssh-keychain`: no `--quick`, drop a stale pidfile
  without killing a reused PID, start an **empty** `--noask` agent. First `git`/`ssh` unlocks via
  `AddKeysToAgent yes`. `zshenv` unsets `SSH_AUTH_SOCK` when `ssh-add -l` cannot talk to the agent
  (exit > 1).

## Shared
- **CCU**: one core, `sketchybar/helpers/ccu_common.py`. Front-ends: Lua literal (sketchybar) or
  `--json` (`asahi-ccu`). `ccu_cost.py` is JSON-only (reserved keys). Test:
  `python3 asahi/bin/asahi_ccu_test.py`.
- **Lua tests**: `sketchybar/top/tests/prelude.lua` — five-line `dofile` bootstrap in its header.
- **dict.cc**: one core `vicinae/extensions/dict-cc/src/dictcc-core.mjs` (ES2018, no fetch/matchAll).
  Asahi imports it in QML via XHR. Test: `node asahi/quickshell/remix/modules/launcher/dictcc_test.js`.
- Neovim: https://neovim.io/doc/
- Zsh: https://zsh.sourceforge.io/Doc/
- Ghostty: https://ghostty.org/docs
- mpv: https://mpv.io/manual/stable/

# SketchyBar layout (macOS)

Three instances: `sketchybar` (bottom), `sketchybar-top` (top), `sketchybar-island` (notch pill).
Config in `sketchybar/{bottom,top,island}/`; shared lua at `sketchybar/*.lua`. Reload with
`<bin> --reload`. Prefer plain `require` (fail loud). Logs:
`/opt/homebrew/var/log/sketchybar/sketchybar.*` and `/tmp/sketchybar-top.*` — truncate them before
a debug run. Smoke: `sketchybar/island/smoke_test.sh [out_dir]`.

- Island fill **and** border are notch-black (`0xff000000`), `border_width` 0. Foregrounds:
  `colors.mocha` at full alpha. No capsule drop shadows. No battery/power/volume/wifi/space/
  now-playing/vpn pills. Pills: appswitch, siri, layout, mic, bluetooth, window.
- Expand: lower prio never clobbers higher; sticky siri (duration=0) only yields to higher prio or
  same kind. Dual dismiss timers (`sbar.delay` + `sbar.exec sleep`). Dismiss is vertical only
  (`y_offset` → `-(height+1)`), no fade, no sideways collapse. Idle geometry snaps **after** hide.
  Never put unchanged props in `sbar.animate` (1px jitter). Color-only bar changes snap
  un-animated. Fresh shows seed content transparent before unhiding.
- `display.notch_width`: both flanks + n < 40% of screen, else 0 (full-width "notch" on externals
  was a false positive). Tuck = corner_radius (offsets -16).
- Notch display: wide left text + fixed right glyph; do **not** fake the gap with ~notch-width
  padding (sketchybar mis-renders it). External: equal halves. Pill width is dynamic
  (`island_core.pill_width` + `island_text`); `island_text.fit` is the hard guarantee text stays
  out of the cutout. Truncate names with `utils.ellipsize` (not `string.sub`).
- Island **only** on the focused display: every `sbar.bar` mutation has `display = <focused>` from
  `display.focused_index()` (yabai `has-focus`, **not** `--display focused`). Items must **not** be
  display-pinned (`associated_display_mask` 0). Margins from the **target** display's width.
- Appswitch dedups on `last_app` — manual `--trigger` needs a fresh name. yabai `external_bar` top
  = idle pill only; `topmost=on`; needs `yabai --restart-service`. Bar `margin` is horizontal only —
  `external_bar` reserves `height` alone.
- Top bar on ALL displays; dual-monitor `notch_width` stays 0. No `front_app` top widget (island
  appswitch is the indicator). No high-CPU pill.
- GPU (bottom): `GPU 00%` · graph · temp. `silistats --once`: `usage.*.perf_percent`,
  `temperature.*_avg_c`, `power.system_watts`. No fallbacks. Presets: `transparent` / `gnix`.
- Font is **SF Pro** (not SF Mono). Measure with probe items + `bounding_rects`, never by eye.
  Icon-only strip 18pt in 24px with 4px pads — wifi must not use a fixed `width`. Bluetooth is
  Hack Nerd Font 18. Network rates LEFT-aligned in 56px ("12 KB/s"); idle = wifi icon, hover
  opens ↑/↓. Mic/volume % hover-only in a fixed 42px box; `drawing` snaps outside animate.
  Leading spaces are trimmed — use U+2007 for interior digit align; ccu grids need Menlo.
- Island process corruption: `--bar hidden=` and `--animate` bar props become no-ops; only
  `launchctl kickstart -k gui/$UID/git.frank.sketchybar-island` clears it (`--reload` does not).
  macOS 26 CVDisplayLink wedge after lock is **system-wide** — restarts do not help, reboot does.
  Guards: `lock.lua` `ensure_rest_after`, island dual timers. SketchyBar #691/#776/#738.
- CCU cards: head = provider + plan + email/rebill; subline = % of limit + reset; meters are
  background items (keep_w on relayout), not sliders. Grok = `grok_usage.py`, Cursor =
  `cursor_usage.py`; all-time/30d/7d + chart from `ccu_cost.py`.
- Layout pill: `refresh_layout_pill` is the sole writer (generation counter). Tint: zoom > float >
  sticky > layout. Click cycles bsp→stack→float; middle-click is inert (space capsules own it).
  Relays `island_layout`. `property_change` is live — do not delete it.
- SF Symbols are in `/Library/Fonts/SF-Pro*.otf`, not SFNS.ttf. Verify a codepoint by rendering.
- Every `yabai -m signal --add` needs `label=` (append-only otherwise). One signal → one bar.
  Bottom bar has no yabai widgets. `updateLayout` is structure only; membership/focus is
  `updateStackIndicator` / `refresh_layout_pill`. `display_added`/`display_removed` are not
  redundant with `display_change` (they also run `arrange-displays.sh`). Non-obvious signals:
  `application_hidden`/`visible` (cmd-H changes per-space counts), `display_changed` → island
  `window_focus` (not the costly `display_change` re-probe), `mission_control_exit` →
  `layout_change` (a reorder fires no `space_*`). yabairc changes need `yabai --restart-service`.
- `bar_config.M.bar(extra)` sends **only** the props passed in. `BAR_NAME` is a lua global in each
  init.lua (launchd never exported it). Shared `siri.lua`: both tint, only top relays `island_siri`.
  "Item not found" right after restart is rebuild noise — fix the restarts.
