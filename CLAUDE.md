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
  `asahi-hdmi-lid-inhibit.service` holds `handle-lid-switch` while an HDMI/DP connector reads
  `connected` (udev: the **card's** `HOTPLUG=1` uevent — connectors never get one — re-checked 3 s
  later via `systemd-run`: sysfs `status` is stale until Hyprland probes; start/stop, never restart,
  the gap lets logind suspend); the drop-in
  sets `LidSwitchIgnoreInhibited=no`. `asahi-dpms` only touches Hyprland-enabled outputs. Two hangs,
  one recovery (hold power ~10s, wait ~15s, tap power): laptop-only lid close can reach s2idle and
  never exit, and a live HDMI plug can freeze DCP (`valid_mode:0` + eDP flip) — **do not close the
  lid** after one. `after_sleep_cmd` only runs on a real `suspend exit`. Diagnose `journalctl -b -1`
  (`Lid closed.` → `Suspending...` → `PM: suspend entry` with no `suspend exit`). Do not add
  `asahi-hdmi sync` to resume. Test:
  `asahi/bin/asahi_hdmi_test.sh`.
- **Failed suspend**: kernel can refuse s2idle (`apple-drm … failed to suspend: error -22`); logind
  then re-suspends every `HoldoffTimeoutSec` while the lid is closed. `systemd-suspend.service`
  `OnFailure=asahi-suspend-failed.service` blocks `handle-lid-switch` until lid open; `asahi-idle`
  skips sleep while `systemd-suspend.service` is failed. Stay-awake does not gate lid suspend.
- **Lock guard**: every lock path (hypridle `lock_cmd`, Super+Escape, launcher `loginctl
  lock-session`) runs `asahi-lock` = hyprlock in a restart loop (flock, 30 tries, stderr to
  `~/.local/state/asahi/hyprlock.log`). hyprlock exits 0 only on unlock / compositor `finished`
  after `locked`; a crash or `killall -9` exits non-zero and used to leave Hyprland's lockdead
  screen with the session locked and no way in. `allow_session_lock_restore` lets the new one
  retake the lock. Never auto-run `hl.clear_crashed_lockscreen()` (unlocks without a password).
  hypridle `inhibit_sleep = 3` explicitly — mode 2 only picks lock-notify when `lock_cmd`
  contains the string `hyprlock`; logind caps the wait at `InhibitDelayMaxSec`. TTY escape
  (`Fn+Ctrl+Alt+F3`): `pkill -f asahi-lock; killall hyprlock`.
- **Lock look**: one centered row `[uptime/battery] [password] [clock/date]` at fixed offsets from
  the centre (±800/832; left/right halign anchor to the monitor edge) on a flat full-width band
  (`$lock_band`, scheme bg ~72%, bottom 340px); scheme fg/muted type. Hostname sits on a top fade
  PNG (`lock-fade-top.png`, written by `write_hyprlock_conf` beside the colors; `halign = left` —
  hyprlock mis-centers images wider than the monitor, and `rotate` shifts them). Label shadows are
  too faint to help. Sizes are framebuffer px (no monitor scale): the row must fit the Dell 2560.
  Preview without locking: nested `Hyprland -c <min.lua>` + `hyprctl output create headless` +
  hyprlock + grim.
- **Lid + DPMS (2026-09-22)**: Hyprland DPMS off is an aquamarine output disable — the DRM
  connector's sysfs `enabled` reads `disabled` (verified live). logind counts a closed lid as
  docked only while an external connector reads `enabled`, and re-checks after every event-loop
  wakeup, so clamshell + 15-min blank = laptop-only lid → `Suspending...` with no new
  `Lid closed.` → lid-closed s2idle → lockdead on lid open → lid re-close hung. Two guards:
  `asahi-clamshell` holds a `handle-lid-switch` block inhibitor for the flag's lifetime, and
  `asahi-hdmi-lid-inhibit.service` is enabled at boot behind an `ExecCondition` on HDMI/DP `status`
  (its `--why` must be one token — `--why=HDMI connected` made systemd run `connected`, exit 1,
  no inhibitor ever). The external may DPMS off in clamshell; HPD survives it (Dell kept HPD
  through 50 min). `./install.sh asahi-logind` after touching the unit.
- **Clamshell / outputs**: never zero outputs — enable the external (`disabled = false`) before
  eDP-1 goes dark. `asahi-clamshell apply` on `config.reloaded` / `monitor.removed` brings eDP back
  if the external vanishes; after a 10 s grace it drops the flag (its inhibitor ends, logind suspends
  the closed lid) unless the external came back (eDP off again) or the lid opened (flag gone).
  `hl.on("monitor.added"/"removed")` hands **userdata**; read `.name`, and an unknown name is a
  no-op (`asahi-hdmi` with no arg defaults to HDMI-A-1). Mirroring
  `HDMI-A-1` strands workspaces 1–4 — mirror eval is **only** `mirror = <source>` (no `mode` /
  `position`). Source must be an enabled output. Undo: Unmirror/Extend, `Super+Ctrl+Alt+R`, or the
  Monitors pane 15 s auto-revert (unless Keep). Pane drag-arrange sends **position-only**
  `hl.monitor` (partial rules merge with the live mode/scale) and reverts by re-evaluating the old
  positions (a reload would re-modeset HDMI).
  Keep → `asahi-hdmi save` into `~/.local/state/asahi/monitor-layout.json` (per sink desc, keyed
  `<hdmi scale>@<eDP scale>`; `layout_fields` prefers it). Extend → `asahi-hdmi reset` + reload.
  Hyprland has no primary display; eDP-1 is only the mirror source and the 0,0 anchor. USB-C
  (`DP-*`) has no enable gate; `asahi-hdmi place DP-1` re-derives its position (eDP scale / kept
  layout — the desc rules assume eDP at 4/3) on add, reload and eDP scale changes. DP refuses the HDMI
  actions (added/sync/on/off).
- **Notch / fnmode**: `comp_asahi_system` writes `asahi-notch.conf` (`show_notch=1`) and
  `hid_apple fnmode=1`, then `dracut -f`. Reboot required. Live fnmode:
  `/sys/module/hid_apple/parameters/fnmode`.
- **Keyboard / display brightness**: `XF86Search` / `XF86LaunchA` (Shift = fine). Display stays on
  `XF86MonBrightness*` (Shift = fine).
- **Keybinding grammar**: Bare Super = focused window / navigate; Super+Shift = inverse (move vs
  focus); Super+Alt = variant (focus→resize, capture→record). `Super+Alt+HJKL` moves the **shared
  split border** — label by direction, never grow/shrink. `Super+Ctrl+<letter>` = system panel
  (A audio, B bluetooth, D display, W network, P power, R backup, S screenshot gallery, T activity, I
  stay-awake, N night light, E emoji, V clipboard, K keybindings). `Super+Ctrl+Alt` restarts the
  stack. `Super+Ctrl+plus/minus` = display scale; `Super+Ctrl+Z` / `Super+Ctrl+Alt+Z` = cursor
  magnifier (`hl.config { cursor = { zoom_factor } }`, lua, not `hyprctl keyword`). Panels:
  `quick()` in `bindings.lua` (`quickActions` in `LauncherWindow.qml`); the same combo again closes
  (`openQuick`/`openCategory` toggle). Esc: one layer per press (Quick pane → home → close); opened
  by a shortcut → closes (`openedByShortcut`). Super+B/N are free. **Every
  bind needs a `desc`** (`parseHyprBinds` drops descless ones). `code:NN` needs `bindCombo`
  `codeNames` — labels are **de(mac_nodeadkeys)** (`code:34/35` = `ü`/`+`, not `[]`).
- **Monitor direction binds**: `Super+Ctrl+arrows` and `Super+Shift+Ctrl+HJKL` must
  `hl.get_monitor(dir)` first (nil on laptop-only). Generated in `bindings.lua`.
- **Clipboard secrets**: `asahi-cliphist` watchers run `wl-paste --watch <self> store` so
  `store_unless_sensitive` drops `x-kde-passwordManagerHint` (`wl-copy --sensitive`).
  `asahi-cliphist types` shows whether a copy carries the hint. `start_watcher` pkills the
  old `--watch cliphist store` form. Browser extensions (Proton Pass) never set the hint:
  password-shaped tokens copied while Firefox is focused are dropped, and a 0-byte copy (Proton's
  auto-clear writes `""`) deletes the newest entry only if the previous copy was a *stored* browser
  copy (`$XDG_RUNTIME_DIR/asahi-cliphist/last-store`). The new store
  tests use `CLIPHIST_DB_PATH` + a fake `hyprctl`; the older ones still touch the real db.
- **Screenshots**: slurp + grim, no hyprpicker freeze. Super+F10/F11/F12 (window / smart / display)
  and Super+mute/vol-/vol+; macOS aliases Super+Ctrl+Shift+3/4/5 (`code:12/13/14`). Clipboard only
  (`asahi-cmd-screenshot <mode> --clip`, nothing in ~/screenshots): Super+Ctrl+Shift+F10/F11/F12
  and top row, gallery "Copy" pill. OCR/QR:
  Super+Shift/Ctrl+F11. Color: Super+Shift+F12. Record: Super+Alt+F11 region, Super+Alt+F12
  display, Super+Alt+Shift+F12 + webcam (`asahi-webcam`; Super+Alt+ü/+ resize = `code:34/35`).
  Test: `asahi/bin/asahi_webcam_test.sh`.
- **Browser screenshare**: camera/mic work. Chromium needs
  `CHROMIUM_USER_FLAGS=--enable-features=WebRTCPipeWireCapturer` in `env.lua` and
  `environment.d/90-asahi.conf` (Fedora ignores `chromium-flags.conf`). No Google Chrome; Fedora
  ships `hyprland-share-picker`. xdph never reconnects to PipeWire: after a pipewire restart its
  ScreenCast `Start` spins (~95% CPU) and every share hangs — drop-in
  `xdg-desktop-portal-hyprland.service.d/10-asahi-pipewire.conf` (`PartOf=pipewire.service`).
- **asahi-debug**: Fedora Asahi health (`asahi/bin/asahi-debug [--json]`). dnf/rpm,
  `wpa_supplicant`, asahi-audio, `speakersafetyd`, `kernel-16k`, HID, notch, sshd mask,
  no-hibernate. Not pacman/iwd/SDDM. Test: `asahi/bin/asahi_debug_test.sh`. Not part of
  `make doctor`; must not flag Hyprland on generic Linux.
- **Night light**: Super+Ctrl+N → `asahi-nightlight` (hyprsunset). On = `hyprsunset.conf` 1500K;
  off = `hyprctl hyprsunset identity`. Identity profile so autostart tints nothing.
- **Bar notch**: cutout is a hole (`BarModel.notchRegionInset`), not a spacer. Height is geometry
  (3024x1964 → **74**), width is the real cutout (370/3024 of logical width + 12). Overflow is
  clipped at the wall; `ccuCompact` (reads compact-independent `fullWidth`) is the only give — the
  clock always shows weekday + date. Chip pads are 6px, `barIconSlot` 26. Anything added to the
  right cluster eats that budget.
- **Bar tray**: `maxInline` 3, rest behind `+N` → `TrayPanel.qml`. Use `SystemTrayItem.NeedsAttention`
  (no `SystemTrayStatus`). Popups need `screen:` + `exclusionMode: ExclusionMode.Ignore`.
  SysPanel / CCU / tray `+N` close on Esc or click-outside: `HyprlandFocusGrab` whitelists the popup
  **and the bar window** (else the opening click counts as outside) — `QsWindow.window` needs
  `import Quickshell` (without it QsWindow is undefined and tray menus silently break); an Item is
  dropped. Esc is a `Qt.ApplicationShortcut` (the grab may focus the bar). App menus take their own
  popup grab: TrayPanel opens them via `QsMenuAnchor` and drops its grab until `closed`.
  `HyprlandFocusGrab` dies on `focusable: false`. Attention dot is static (a pulse redraws the bar
  every frame). Menu positions are window coords (`mapToItem(null, …)`).
- **Bar = click to act, event-driven**: hover tint (`HoverTint`), tooltip only on tray icons,
  night-light chip only while on. Vol/mic bind Pipewire (+`PwObjectTracker`), BT binds BlueZ,
  battery = UPower (60 s fallback), network = `nmcli monitor` (+30 s signal poll), CPU/RAM/heatpipe
  in-process `FileView`; `asahi-cpu`/`-memory` only while SysPanel is open. Stay-awake / night light
  / timer watch files (FileView's directory watch sees create/delete). Long-lived children get
  `setpriv --pdeathsig TERM` (a SIGTERMed qs orphans them). Chip clicks →
  `barHost.quickRequested(key)` → shell.qml (no `qs ipc` client per click). Wheel steps accumulate
  to 120, horizontal swipes ignored. Visualizers share one cava (`services/Cava.qml`, `hold()`);
  hidden items bound to it still repaint, so bars exist only while shown. One bar per screen —
  every poll doubles when docked.
- **Launcher quick panes**: one file each in `quickshell/remix/modules/launcher/panes/`;
  `LauncherWindow.qml` does `Panes.XPane { root: launcherSelf }` (`root` inside a pane is that
  property, not the launcher id). Shared M3 widgets in `modules/menu`. A visible Quick tile **must
  have a pane** (`quickPaneKey` falls back to `t.key`); paneless actions go in `quickDeckHidden`
  (`wallpaper_carousel_test.js` derives that list). Any close keeps the pane alive (the next open
  destroys it): poll Timers, `SystemClock` and looping animations gate on `root.shouldShow`;
  countdowns (Monitors revert) and BT stop-retries must not. Must-finish actions run as
  `systemd-run --user --wait --quiet --collect` (exit code passes through — Wi-Fi band, BT
  pair/forget); `MonitorsPane` reverts on destruction. A failed connect deletes only a profile it
  just created with a typed passphrase.
- **Recorder**: Super+Alt+R toggles `RecordPanel`. Bar REC chip only while recording (click =
  panel, right-click = stop). `asahi-cmd-record status --json` via `Recorder` singleton. No pause
  (wf-recorder exits on SIGUSR1). IPC: `qs -c remix ipc call recording panel`.
- **Wallpaper**: one picker, `WallpaperManager` (Super+Shift+W). `ipc: "wallpaper"` and
  `wallpaper: true` in `quickDeckHidden` — not a Quick tile; search still finds it. Browse:
  `WallpaperCarousel` (skewed window fan: centre 16:9, neighbours are leaning
  slices; ←/→, Ctrl+h/l, wheel, click a slice to select; ⏎/Apply/click the centre
  applies, Esc restores). The picker covers the windows with the wallpaper itself (blurred,
  crisp while Live). Live preview is **opt-in** (`WallpaperService.liveMode`, default off): Shift /
  Shift+←/→ / Live chip; ignore bare Shift in the search field. Debounce 70ms. Color index from
  cached thumbs → `wallpaper_colors.js`; filters on `WallpaperService.arranged(query)`. Test:
  `wallpaper_colors_test.js`.
- **Autotheme**: Hyprland has no portal Settings — `portals.conf` pins Settings to gtk. Flavours
  `source content vibrant calm mono` (`FLAVORS` is the source of truth; saturation is a fraction of
  gamut room, never a multiplier). Writes `~/.local/state/asahi-theme/`. GTK ini is a real file,
  not a symlink. Unset portal `0` = light. Live: Ghostty `reload-config`, Quickshell `FileView`,
  Hyprland borders, btop SIGUSR2, Firefox. **GTK3 never repaints live** — do not add watchers.
  Tests: `asahi/theme/tests/test_palette.py`, `asahi/theme/smoke_test.sh`.
- **Firefox (Flathub flatpak)**: release build enforces addon signing (`MOZ_REQUIRE_SIGNING`), so
  live theme = signed AMO **CaelestiaFox** (`caelestiafox@caelestia.org`, `browser.theme.update`) +
  native host `caelestiafox` = `asahi-firefox-theme` (streams `firefox.json` from
  `write_firefox_scheme`: caelestia M3 keys, hex without `#`; Firefox passes manifest path + ext id as
  args — ignore them). Sandbox can't run host scripts: `xdg-native-messaging-proxy` (dnf, D-Bus
  activated) + `flatpak override --talk-name=org.freedesktop.NativeMessagingProxy`; host manifest in
  `~/.config/mozilla/native-messaging-hosts/`. Profiles: `~/.var/app/org.mozilla.firefox/config/mozilla/firefox/`
  — `asahi/firefox/user.js` is **symlinked** (`flatpak override --filesystem=$DOTFILES/asahi/firefox:ro`; the
  sandbox sees nothing else of `$DOTFILES`), XPI is downloaded into the profile; `user.js` sets
  `widget.use-xdg-desktop-portal.native-messaging-proxy = 1` (default 0) and `autoDisableScopes = 14`.
  `BROWSER=org.mozilla.firefox` (flatpak export; `~/.local/share/flatpak/exports/bin` is on PATH). Test: `asahi/bin/asahi_firefox_theme_test.sh`.
- **Firefox wake locks (2026-10-05)**: flatpak override `MOZ_WAKE_LOCK_TYPE=WaylandIdleInhibit`
  (`comp_asahi_desktop`). Default path = portal Inhibit → xdg-desktop-portal-gtk →
  `org.freedesktop.ScreenSaver.Inhibit` on hypridle; Firefox left 3 of those open (no media playing)
  and hypridle skipped every listener for ~5 h (idle.log silent = no `asahi-idle at` call at all).
  Wayland inhibitors bind to the window (only while visible, gone with it) and show as
  `inhibitingIdle` in `hyprctl clients`. Diagnose D-Bus ones: `busctl --user tree
  org.freedesktop.impl.portal.desktop.gtk` (open `request/<sender>/t/*`; owner via
  `busctl --user status :1.N`), release with `busctl --user call … org.freedesktop.impl.portal.Request
  Close` (gtk then sends `UnInhibit`). Verify a running Firefox: `MOZ_LOG=LinuxWakeLock:5,sync`.
- **sshd**: Fedora enables it; disable and mask `sshd.service` + `sshd.socket`. Re-check after a
  release upgrade.
- **Notification images**: `localImage()` only `image:`/`file:`/`/…`. Summary/body are
  `Text.PlainText` (no `<img src>`). Toasts top-right, `ExclusionMode.Normal` + zone 0 (clears
  bar/notch). History persists to `~/.local/state/asahi/notifications.json` (0600, non-atomic
  writes keep the mode). Bell badge = unread since last sheet toggle. Click = focus sender by
  class (never run notification actions); right-click dismisses. shell.qml id is `notifCenter` —
  `notificationCenter: notificationCenter` self-binds to null.
- **bash 5.3 / trailing `&&`**: an EXIT trap or function whose last command is `[[ -n $x ]] && …`
  returns 1 when `$x` is empty; under `set -e` that kills the script (`asahi-network` lost JSON
  this way). End traps on `|| true` / `if`; optional tail lines in `if` blocks. Interactive zsh
  helpers without `set -e` are fine.
- **Apple HID race**: dockchannel-hid binds `hid-generic` first; `asahi/dracut.conf.d/10-asahi-hid.conf`
  force-loads `hid_apple` only (`hid_magicmouse` is builtin). Verify
  `/sys/bus/hid/drivers/` + `readlink -f /sys/bus/hid/devices/*/driver`. Live trackpad recovery:
  `sudo udevadm trigger --action=add /dev/input/eventN` (input node, not drm).
- **Audio**: Fedora Asahi already ships the stack — do not port omarchy's Apple audio.sh. RT check
  is the **thread**: `ps -eLo comm,rtprio,cls | grep data-loop` → `20 RR`. Mic:
  `effect_output.j414-mic` is 1ch `AUX0` (stereo recorders: left only) →
  `asahi/wireplumber/wireplumber.conf.d/asahi-mic.conf`: a software-dsp copy stage publishes MONO
  `asahi_mic` (default, prio 2010) and `hide-parent` hides AUX0 — one mic, one mute. Not a loopback
  (AUX0 stayed visible: mute bypass); daemon `node.rules` can't remap a filter's channels. A new
  filter node reports 2 `channelVolumes` until its first capture (bar mic chip reads 0 % / unmuted)
  — prime once: `timeout 1 pw-record --target asahi_mic /dev/null`. The headset jack source stays
  listed (port `not available`). Never override asahi-audio's node scripts (a `software-dsp.lua`
  overlay hung WirePlumber upstream). 96 kHz playback can lock speakersafetyd (kernel: `Speaker
  volumes locked`): `sudo systemctl reset-failed speakersafetyd && sudo systemctl start speakersafetyd`.
- **Trackpad**: `tap_to_click = true` (omarchy uses false on Asahi). No touchpad toggle;
  `disable_while_typing` only. Pointer feel is the `hl.device` curve on `apple-mtp-multi-touch` in
  `input.lua` (libinput ignores `sensitivity` under a custom profile). `hyprctl reload` does **not**
  reset a device — keep that explicit rule or a bad `hyprctl eval 'hl.device({…})'` survives until
  reboot. `hl.device` checks field names, not values. Terminal scroll: `scroll_touchpad = 0.2` for
  Ghostty in `rules.lua` (also the global factor — keep the rule). DWT works out of the box: stock
  `50-system-apple.quirks` `[Apple Laptop Keyboard (MTP)]` tags the keyboard internal — no local quirk.
- **Bluetooth off**: `asahi-bluetooth-power` `bluetoothctl power off` (blocks until BlueZ confirms), then
  `rfkill block` — blocking a live BCM43xx radio can wedge it until reboot.
- **zram**: only swap. `asahi-system` installs zstd (`zram-generator.conf.d`) +
  `sysctl.d/99-asahi-zram.conf` (swappiness 150, page-cluster 0, watermark boost 0 / scale 125).
- **Wi-Fi band**: `asahi-wifi-band [status|auto|2.4|5]` pins the profile's band (the AP band-steers
  between its 2.4/5 GHz BSSIDs), reverts if the reconnect fails; Network pane "Band" pill cycles
  auto → 5 → 2.4. BCM4388 resume fix (omarchy-mac) not ported: post-resume rejects recover in
  6–30 s. Test: `asahi/bin/asahi_wifi_band_test.sh` (fake nmcli).
- **Kernel**: self-built `fairydust` (USB-C DP alt mode) in `~/linux-fairydust`, 16k pages;
  `asahi-debug` accepts `*fairydust*`. Patches in `asahi/kernel/` (re-apply with `git am` on a local
  branch): brcmfmac `roam_delta` init (`WLC_SET_ROAM_DELTA error (-52)`), dcp HPD re-sample on resume
  (HDMI-on-resume untested), j414s DTS disabling AVD + its DART (no avd-fw on Fedora; the failed
  probe keeps `avd_sys` powered — needs `make dtbs && sudo make dtbs_install && sudo update-m1n1`).
  USB-C display = `card2-DP-1`; no `ddc` link on DP or HDMI. The roam fix is in
  `/lib/modules/7.1.13-fairydust+/updates/`, which depmod prefers: delete it on the next full rebuild.
- **m1n1 DTB pin**: m1n1 `boot.bin` carries ONE device-tree set. On each kernel add/remove grubby's
  `10-devicetree.install` re-points `/boot/dtb` to the newest Fedora `dtb-*` and
  `15-update-m1n1.install` rebuilds `boot.bin` — fairydust then boots without DP alt mode (no
  `/proc/device-tree/aliases/dcpext1`). `asahi-system` (before dnf) links `/boot/dtbs/fairydust` →
  the running release, sets `DTBS="/boot/dtbs/fairydust"` in `/etc/sysconfig/update-m1n1` and
  `UPDATEDEFAULT=no` in `/etc/sysconfig/kernel`; rerun after a new fairydust (`asahi-debug` WARNs
  `fairydust-pin`). Recovery: fix the pin, `sudo update-m1n1`; worst case swap `m1n1/boot.bin` and
  `boot.bin.old` on the ESP.
- **WM defaults**: `general.lua` — `dwindle.force_split = 2`, `hide_special_on_workspace_change`,
  `allow_session_lock_restore`, `on_focus_under_fullscreen`, `initial_workspace_tracking = 0`,
  `anr_missed_pings = 3`, `group`/`groupbar` themed to the Catppuccin borders (Super+W groups),
  `hl.gesture` 3-finger workspace swipe (`scale 0.75`, `workspace_swipe_cancel_ratio = 0.25`).
  Validate keys against `/usr/share/hypr/stubs/hl.meta.lua`, then
  `hyprctl reload && hyprctl configerrors`. Lua dispatchers: `hyprctl dispatch 'hl.dsp.…({…})'`
  (legacy `dispatch <name> <args>` is dead). Float is its own call; maximized refuses resize+pin.
  Window-rule `opacity` multiplies with `inactive_opacity` — use `opaque = true` for media/PiP/
  webcam. Capture binds (screenshot/record/picker) must not be `locked` (recording from the lock
  screen keeps running after unlock).
- **asahi/bin**: helpers in `asahi/bin/lib/common.sh`, sourced via
  `$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/lib/common.sh`. `asahi-launch` is the only
  `uwsm-app`/`setsid` site. Sibling paths through that dirname, not `$HOME/.dotfiles`.
  `components.sh` chmods `asahi/bin/*` and skips `lib/` (a dir) — keep sourced files there.
- **Quickshell launch**: never `qs -d` (EPIPE/`qFatal` if the parent is gone). `setsid -f qs -n -c
  <module>`. Bar vanished → `asahi-debug` coredumps first. qs reloads on save (log:
  `/run/user/$UID/quickshell/by-pid/<pid>/log.log`). `grim` blocks on a DPMS-off output — always
  `timeout`. zprofile unsets Lmod's `BASH_ENV` (13 ms → 1.2 ms per bash start).
- **Stay awake**: one flag `$XDG_RUNTIME_DIR/asahi-stay-awake`, owned by `asahi-stay-awake`.
  hypridle listeners skip under it (`asahi-idle` checks `status`).
- **Idle (macOS-shaped)**: `hypridle.conf` fires `asahi-idle at <secs>` at 150/180/300/600; the
  step comes from the power source **at fire time** (unplug mid-idle still locks). Battery: dim +
  kbd 10% at 2.5 min → lock, DPMS off + kbd off at 5 min, no saver (longer than macOS's 2 min by
  choice; dim halfway like macOS). AC: saver 3 → dim 5 → off 10 min. Panel backlight is **not**
  zeroed; `off` itself suspends 60 s later. The hyprlock surface map is
  fake pointer motion (`simulateMouseMovement`): it fires on-resume and restarts every listener, so
  `off` ignores wakes while locking (`$XDG_RUNTIME_DIR/asahi-idle-locking`) and then watches DPMS —
  `key_press_enables_dpms` relights on input → `asahi-idle wake`. Saver/dim skip while locked. Sleep
  skips while a running sink carries signal (`pw-record -P '{ stream.capture.sink = true }'` of its
  monitor — without that property pw-record falls back to the mic; the monitor is pre-volume, so
  muted playback counts, silent page streams don't) or a non-eDP output is enabled. `off` is
  single-instance (flock), retries sleep every minute and flags locking *before* stopping the saver
  (its unmap fakes motion too); the flag is honoured ≤15 s; hypridle's wake burst coalesces (flock).
  Saver ~30 fps.
  **Keyboard/trackpad cannot wake s2idle** (MTP DockChannel has no wakeup source); lid and power
  button (SMC) can. Log:
  `~/.local/state/asahi/idle.log`.
- **Time Machine**: `asahi-timemachine` = restic, one repo (`$TM_DIR` on the drive labelled `$TM_LABEL`)
  reached either locally (drive on this laptop → udisks mount, never unmounted: eject it yourself) or
  over SFTP (drive on the backup host). Host/path/port live **only** in
  `~/.config/asahi-timemachine/config` — never commit them. Own key `id_ed25519` there is
  `restrict,command="internal-sftp"` on the host (no shell, but full file access as that user — not
  a sandbox); ssh runs `-F /dev/null` + no agent (else the main key sneaks in and gets a shell).
  Password file beside it (copy in the password manager). Hourly timer, backs up only if last ok >
  `TM_MIN_AGE_H` (72); offline = skip, not fail; `last_success` is set as soon as the snapshot is
  saved (forget/prune ≤ weekly may fail without failing the run); notifications on start/done/fail.
  State `~/.local/state/asahi/timemachine.json` = flock + atomic `mv` (FileView follows renames;
  `status` only reads it and adds restic percent/ETA). `overview` caches snapshots + old rsync dirs +
  drive df (one SFTP session). Bar `BackupChip` (left of the notch, after SysChip) only while running /
  failed. Quick pane `backup` (Super+Ctrl+R): overview tiles, 30-day strip, snapshots, browse, restore
  → `~/Restored/<date>-<id>/<abs path>` (never overwrites; restore runs in a transient unit **without**
  `--pipe` — a dead client would SIGPIPE it). The old rsync snapshots `fedora-home-backup-*` on that
  drive are `chattr +i` — never delete (2026-09-28 is the last full one). No sleep inhibitor (lid
  close must still suspend). After install: `asahi-timemachine init` (key, password, repo, timer).
  Test: `asahi/bin/asahi_timemachine_test.sh`.
- **Timers**: `asahi-timer add <dur> [label]` = transient `systemd-run --user --on-active`.
  Launcher `:timer 10m tea` (`arg_commands.js`, tested).
- **Window pop**: Super+O → `asahi-window-pop` (float/resize/center/pin/`pop`); second press
  retiles.
- **Display scale**: Super+Ctrl+plus/minus → `asahi-monitor-scale`. Legal scales are 1/120
  divisors (eDP-1: 1 / 1.333333 / 2). Saved per output name under `$XDG_RUNTIME_DIR`; HDMI-A-1 is
  reused by both sinks. Positions are **derived** (`anchor_offset` in `lib/common.sh`), never pinned.
- **Refresh rate**: eDP-1 stays 120 Hz (`monitors.lua`); a battery 60 Hz switch saved ~3 W only
  during video — do not re-add. Wi-Fi power save: no gain, stays off.
- **Speed test**: `asahi-speedtest [--json]` — Cloudflare 50 MB down / 25 MB up (~20 s; 100 MB is
  403). Network pane button.
- **Wi-Fi QR**: `asahi-wifi-qr` → `$XDG_RUNTIME_DIR` mode 600; `nmcli -s` for the PSK.
- **Autostart**: `asahi/xdg-autostart/` (only a Hidden stub masking gnome-keyring-ssh) vs Hyprland
  `exec-once` in `autostart.lua`. Verify no `app-gnome\x2dkeyring\x2dssh@autostart.service` under
  the user generator.late.
- **Secrets**: `asahi/kwalletrc` disables kwallet. `gnome-keyring-daemon --components=secrets`
  only; SSH is keychain. Do not start gnome-keyring ssh. Flatpaks (Zotero) reach it only via the
  Secret portal — `portals.conf` pins `Secret=gnome-keyring` (its `.portal` is `UseIn=gnome`).
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
