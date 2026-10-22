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

- Run smoketests; inspect outputs; verify symlinks. Asahi: `make test-asahi` runs every Asahi test
  (Quickshell JS, `asahi/bin` shell + Python, theme pytest, Lua syntax; ~20 s; fakes or read-only checks).
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
  reference by name. Prefer Quickshell `Singleton` (reloadable). Never `Foo {}` construct them. A singleton
  added while qs runs stays `undefined` across hot reloads: restart qs (Super+Ctrl+Alt+W).
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
  `HandlePowerKey`/`…LongPress=ignore` in `asahi/systemd/logind.conf.d/10-asahi-sleep.conf`; F6 (moon)
  is KEY_SLEEP (a tap suspended past every idle guard): `autostart.lua` holds a session
  `systemd-inhibit --what=handle-suspend-key` block lock (no root: polkit allows active sessions; no
  drop-in to install) and Hyprland binds `XF86Sleep` to Do Not Disturb
  (`./install.sh asahi-logind` also installs the udev rule + inhibit unit; HUP logind, never restart
  it; never `udevadm trigger` drm — that hotplugs HDMI). `InhibitDelayMaxSec=15` gives hyprlock time
  on lid close. gsettings `power-button-action` is a GNOME no-op here. ~10s hold is SMC force-reset.
  Lid switch is `Apple SMC power/lid events` (`locked = true` in `monitors.lua`). Do **not** set
  `HandleLidSwitch` — laptop-only close is logind `suspend`; docked (`sysfs enabled=enabled`) is
  `HandleLidSwitchDocked=ignore` and `asahi-clamshell` disables eDP-1. Clamshell close is a no-op
  without a Hyprland-enabled external (do not DPMS-blank eDP there — races s2idle, `8000000a`,
  hangs) — unless a block inhibitor (`asahi-hdmi`: cable in, output not enabled) stops the suspend:
  then close waits 5 s for the external (→ clamshell), else blanks + locks. HDMI-A-1 stays `disabled = true` in `monitors.lua` until `asahi-hdmi` (~2s) sets
  `disabled = false`. logind does not count that cable as docked, so
  `asahi-hdmi-lid-inhibit.service` holds `handle-lid-switch` while an HDMI/DP connector reads
  `connected` (udev: the **card's** `HOTPLUG=1` uevent — connectors never get one — re-checked 3 s
  later via `systemd-run`: sysfs `status` is stale until Hyprland probes; start/stop, never restart,
  the gap lets logind suspend); the drop-in
  sets `LidSwitchIgnoreInhibited=no`. `asahi-dpms` only touches Hyprland-enabled outputs in the other state (a redundant enable flashes the panel). Two hangs,
  one recovery (hold power ~10s, wait ~15s, tap power): laptop-only lid close can reach s2idle and
  never exit, and a live HDMI plug can freeze DCP (`valid_mode:0` + eDP flip) — **do not close the
  lid** after one. `after_sleep_cmd` also runs after a refused suspend. Diagnose `journalctl -b -1`
  (`Lid closed.` → `Suspending...` → `PM: suspend entry` with no `suspend exit`). Do not add
  `asahi-hdmi sync` to resume. Test:
  `asahi/bin/asahi_hdmi_test.sh`.
- **Sleep drain (AsahiLinux/linux#262, 2026-10-16)**: s2idle costs ~1.4–1.85 W here (~3 %/h, `slept …` lines in
  `idle.log`) — a kernel floor, not ours; do not chase it in userspace. No S3 / hibernate / RTC `wakealarm` (no
  suspend-then-poweroff). AOP ALS wakes ~3.6/s in sleep (#638), but silencing it (blacklist, PM notifier) changed
  nothing in the thread; lid-angle stream can't be stopped. j314s hangs there were the out-of-tree SEP Touch ID
  driver + `fprintd` — no SEP here; our hangs are the DCP path below.
- **Failed suspend**: kernel can refuse s2idle (`apple-drm … failed to suspend: error -22`). Cause
  (2026-10-09): USB-C unplug while DP-1 is on — poweroff's clear swap times out and silently sets
  `dcp->crashed`, `dcp_crtc_atomic_check` then rejects the suspend's disable-all until reboot
  (dcp atomic_check fix in `~/linux-fairydust`). Signature: aquamarine `Cannot commit a disconnected output`, no dcpext
  `dcp_poweroff() done`. logind then re-suspends every `HoldoffTimeoutSec` while the lid is closed. `systemd-suspend.service`
  `OnFailure=asahi-suspend-failed.service` blocks `handle-lid-switch` until lid open; `asahi-idle`
  skips sleep while `systemd-suspend.service` is failed (one critical "Sleep disabled" notification
  per boot — it once silently kept the SoC awake for 33 h). `asahi-idle wake` (after_sleep) keeps the
  panel dark while the lid is closed (outside clamshell; lid open relights via `asahi-clamshell
  open`). Stay-awake does not gate lid suspend.
- **Lock guard**: every lock path (hypridle `lock_cmd`, Super+Escape, launcher Lock — direct,
  not `loginctl lock-session`, so it works without hypridle) runs `asahi-lock` = hyprlock in a restart loop (flock, 30 tries, stderr to
  `~/.local/state/asahi/hyprlock.log`). hyprlock exits 0 only on unlock / compositor `finished`
  after `locked`; a crash or `killall -9` exits non-zero and used to leave Hyprland's lockdead
  screen with the session locked and no way in. `allow_session_lock_restore` lets the new one
  retake the lock. Never auto-run `hl.clear_crashed_lockscreen()` (unlocks without a password).
  hypridle `inhibit_sleep = 3` explicitly — mode 2 only picks lock-notify when `lock_cmd`
  contains the string `hyprlock`; logind caps the wait at `InhibitDelayMaxSec`. Super+Escape is a
  `locked` bind: on the lockdead screen (guard out of retries) it starts a fresh
  hyprlock; while one runs asahi-lock exits at once (flock / pidof). Verified in a nested session
  (kill -9 guard + hyprlock → lockdead): a non-`locked` bind does nothing there, the `locked` one
  re-locks. Nested Hyprland gets no modifiers from `send_shortcut` — test with a plain key. TTY escape
  (`Fn+Ctrl+Alt+F3`): `pkill -f asahi-lock; killall hyprlock`.
- **Lock look**: one centered row `[uptime/battery] [password] [clock/date]` at fixed offsets from
  the centre (±800/832; left/right halign anchor to the monitor edge) on a flat full-width band
  (`$lock_band`, scheme bg ~72%, bottom 340px); scheme fg/muted type. Hostname sits on a top fade
  PNG (`lock-fade-top.png`, written by `write_hyprlock_conf` beside the colors; `halign = left` —
  hyprlock mis-centers images wider than the monitor, and `rotate` shifts them). Label shadows are
  too faint to help. Sizes are framebuffer px (no monitor scale): the row must fit the Dell 2560.
  Three input-fields share the input. Outer 832 = 2px ring (transparent font); inner 624 = dots/text
  (hyprlock pads dots only `(h - dot)/2`; one field ran dots under the `de` label) — 13 dots max.
  Caps Lock highlights the border only, no fill. Outline thickness is static and drawn outside the
  box, so a second ring is 8px with `outer_color` clear and `capslock_color = $lock_caps`; the 2px
  ring's caps color is clear, so the hairline eases out as the thick stroke eases in
  (`inputFieldColors`, bezier `out`, speed 3). `$lock_caps` is palette yellow (the warning color;
  mocha fallback `f9e2af`), written by `write_hyprlock_conf`. Do not assign it after the `source`
  lines or the wallpaper color loses. Light mode darkens yellow for contrast, so the stroke is dark
  gold on a light band and bright on a dark one. Thick ring
  check/fail stay clear or a failed password would also draw it with Caps Lock off. A failed attempt
  replaces the caps color for `fail_timeout` (~2s), and the 2px ring shows `$lock_fail` / `$lock_check`.
  Dots keep `$lock_fg` (`swap_font_color`, caps color `$lock_fg`) so the box interior never fills;
  their check/fail stay real or "Checking…" / "Failed" blank. `asahi-lock-caps` draws bold CAPS in
  `$lock_fg` opposite `de` (x=354, same baseline). Polls the kbd-capslock LED (hyprctl only when no
  LED node). Never `$lock_fail` for the caps color.
  Preview without locking: nested `Hyprland -c <min.lua>` + `hyprctl output create headless` +
  hyprlock + grim; type via live `hl.dsp.send_shortcut` to `class:^(aquamarine)$` (never Enter: PAM).
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
  With no real output left Hyprland lists an enabled `FALLBACK` — `external_on` must not count it
  (it kept eDP off and a closed lid awake for hours after a clamshell USB-C unplug).
  `hl.on("monitor.added"/"removed")` hands **userdata**; read `.name`, and an unknown name is a
  no-op (`asahi-hdmi` with no arg defaults to HDMI-A-1). Mirroring
  `HDMI-A-1` strands workspaces 1–5 — mirror eval is **only** `mirror = <source>` (no `mode` /
  `position`). Source must be an enabled output. Undo: tap the filled Mirror pill, or Extend, `Super+Ctrl+Alt+R`, or the
  Monitors pane 15 s auto-revert (unless Keep). Mode pills: own pictograms (`panes/icons/`, white + alpha:
  `MultiEffect` tints one color). Laptop-only greys them out (Extend's reload blinks eDP-1); a
  plugged-in but disabled external keeps them (Extend's reload brings it back). Pane drag-arrange sends **position-only**
  `hl.monitor` (partial rules merge with the live mode/scale) and reverts by re-evaluating the old
  positions (a reload would re-modeset HDMI).
  Keep → `asahi-hdmi save` into `~/.local/state/asahi/monitor-layout.json` (per sink desc, keyed
  `<hdmi scale>@<eDP scale>`; `layout_fields` prefers it). Extend → `asahi-hdmi reset` + reload.
  Hyprland has no primary display; eDP-1 is only the mirror source and the 0,0 anchor. USB-C
  (`DP-*`) has no enable gate; `asahi-hdmi place DP-1` re-derives its position (eDP scale / kept
  layout — the desc rules assume eDP at 4/3) on add, reload and eDP scale changes; an eDP scale change re-places
  HDMI the same way (mirrors are skipped: no position of their own) (on reload HDMI stays `asahi-hdmi sync`'s: one writer per output). DP refuses the HDMI
  actions (added/sync/on/off).
- **Notch / fnmode**: `comp_asahi_system` writes `asahi-notch.conf` (`show_notch=1`) and
  `hid_apple fnmode=1`, then `dracut -f`. Reboot required. Live fnmode:
  `/sys/module/hid_apple/parameters/fnmode`.
- **Charge limit**: this SMC is CHLS (probed 2026-10-16: a 90 write reads back 90; CHWA would read 80) — any
  end 10–99 holds, start = end − 5 (start writes are ignored), and every end < 100 sets the CHLS force-discharge
  bit (100 writes 0) — battctl says a limit below the charge drains on AC (not observed here).
  `asahi-charge-limit` clamps 60–100; 100 = no limit, anything below is a hold (99 too, also in
  `asahi-battery`). One saved copy, `/var/lib/asahi/charge-limit` (dir root:wheel 2775; temp + rename, so a
  root-owned file is no obstacle), written only after the SMC took the value — boot applies it. Battery pane
  (Super+Ctrl+P): stepper (5 %) + Hold 80 / Full 100 (a preset also adopts the battery's value during drift),
  marker tick on the dial (`MenuHudDial.marker`), "Saved X%, battery has Y%" + Reapply when they
  differ; the limit is read on open and after a change, never polled. The SMC
  keeps it: 75 survived an unplug + 7.5 h s2idle (2026-10-19) — no AC-plug / resume re-apply (idea:
  omarchy-mac-battctl) unless a replug is seen to drop it. UPower 1.91.5: percentage = sysfs `capacity`, but
  its thresholds are a fixed hwdb 75/80 (said 80 while the SMC held 75) — never read the limit from UPower.
- **Keyboard / display brightness**: `XF86Search` / `XF86LaunchA` (Shift = fine). Display stays on
  `XF86MonBrightness*` (Shift = fine). Keys auto = `asahi-brightness-keyboard-auto`: log(lux) 8→180,
  re-derived only after a 25 % lux move seen twice in a row (shadow filter), smoothstep fades
  (`fade_brightness`), steady tick forks nothing. Auto fade, idle off/restore and the keyboard keys share
  `$XDG_RUNTIME_DIR/asahi-idle-brightness.lock` (`brightness_lock` in `lib/common.sh`); a key (keyboard or
  display) while idled off / dimmed steps from the saved level. hypridle 150 s listener (`ignore_inhibit`) fades keys off; `asahi-idle keys`
  relights (not on the lock surface's fake motion, not under a closed lid).
- **Keybinding grammar**: Bare Super = focused window / navigate; Super+Shift = inverse (move vs
  focus); Super+Alt = variant (focus→resize, capture→record). `Super+Alt+HJKL` moves the **shared
  split border** — label by direction, never grow/shrink. `Super+Ctrl+<letter>` = system panel
  (A audio, B bluetooth, C calendar, D display, W network, P power, R backup, S screenshot gallery, T
  activity, I stay-awake, N night light, E emoji, V clipboard, K keybindings). `Super+Ctrl+Alt`
  + R reloads Hyprland, + W/P/I restart Quickshell / hyprpaper / hypridle (+S suspends, +Z magnifier reset). `Super+Ctrl+plus/minus` = display scale; `Super+Ctrl+Z` / `+Shift+Z` /
  `+Alt+Z` = cursor magnifier in / out / reset (`hl.config { cursor = { zoom_factor } }`, lua, not `hyprctl keyword`). Panels:
  `quick()` in `bindings.lua` (`quickActions` in `LauncherWindow.qml`); the same combo again closes
  (`openQuick`/`openCategory` toggle). Esc: one layer per press (Quick pane → home → close); opened
  by a shortcut → closes (`openedByShortcut`). Workspaces: Super+N go, Super+Ctrl+N move,
  Super+Alt+N send without following, Super+Y back-and-forth. Super+Alt+F = fullscreen inside the tile
  (`fullscreen_state` client 2), Super+Alt+arrows join the neighbouring group, Alt+Tab cycles windows. Lock / media / lid binds are
  `submap_universal` (the writing-tools submap's catchall swallowed them). Super+B/N/S are free. **Every
  bind needs a `desc`** (`Data.parseHyprBinds` drops descless ones; tested in `data_test.js`) — except the lid
  switches and the writing submap. `code:NN` needs
  `bindCombo` `codeNames` — labels are **de(mac_nodeadkeys)** (`code:34/35` = `ü`/`+`, not `[]`).
- **Monitor direction binds**: `Super+Ctrl+arrows` and `Super+Shift+Ctrl+HJKL` must
  `hl.get_monitor(dir)` first (nil on laptop-only). Generated in `bindings.lua`.
- **Clipboard secrets**: `asahi-cliphist` watchers run `wl-paste --watch <self> store` so
  `store_unless_sensitive` drops `x-kde-passwordManagerHint` (`wl-copy --sensitive`). Every clipboard read
  there is under `timeout` (an app that never closed its pipe hung the watcher and history for the session).
  `asahi-cliphist types` shows whether a copy carries the hint. `start_watcher` pkills the
  old `--watch cliphist store` form. Browser extensions (Proton Pass) never set the hint:
  password-shaped tokens copied while Firefox is focused are dropped, and a 0-byte copy (Proton's
  auto-clear writes `""`) deletes the newest entry only if the previous copy was a *stored* browser
  copy (`$XDG_RUNTIME_DIR/asahi-cliphist/last-store`). `asahi-writing-tools` touches
  `$XDG_RUNTIME_DIR/asahi-cliphist/skip` before its Ctrl+C: store skips while it is < 2 s old. The store
  tests run on a scratch db (`CLIPHIST_DB_PATH`) + runtime dir with fake `wl-paste`/`hyprctl`.
- **Screenshots**: slurp + grim, no hyprpicker freeze. Super+F10/F11/F12 (window / smart / display)
  and Super+mute/vol-/vol+ — our own keys only, no macOS Cmd+Shift+3/4/5 duplicates. Clipboard only
  (`asahi-cmd-screenshot <mode> --clip`, nothing in ~/screenshots): Super+Ctrl+Shift+F10/F11/F12
  and top row, gallery "Copy" pill. OCR/QR:
  Super+Shift/Ctrl+F11. Color: Super+Shift+F12. Record: Super+Alt+F11 region, Super+Alt+F12
  display, Super+Alt+Shift+F12 + webcam (`asahi-webcam`; Super+Alt+ü/+ resize = `code:34/35`).
  Annotate (Screenshots pane: tile pencil, preview "Annotate" pill) = `asahi-screenshot-annotate` =
  `swappy -f shot` (Fedora; satty is not packaged; class `swappy` floats). Only Save (Ctrl+S / button) counts:
  `asahi/swappy/config` sends it to `~/screenshots/annotated-*.png` + `early_exit`; the script moves it over
  the shot when `magick compare -metric AE` sees changed pixels (else drops it) and re-copies it. No `-o`:
  swappy writes that on Esc / q / close too. Verified in nested Hyprland (Esc, empty Save, draw + Save). Gallery thumbs
  regenerate when older than the image (`-nt`); tile + preview Images are `cache: false` (same path).
  `screenshot` toasts (also OCR / QR) show under Do Not Disturb, silently: feedback for your own key.
  Test: `asahi/bin/asahi_webcam_test.sh`.
- **Browser screenshare**: camera/mic work. Chromium needs
  `CHROMIUM_USER_FLAGS=--enable-features=WebRTCPipeWireCapturer` in `env.lua` and
  `environment.d/90-asahi.conf` (Fedora ignores `chromium-flags.conf`). No Google Chrome; Fedora
  ships `hyprland-share-picker`. xdph never reconnects to PipeWire: after a pipewire restart its
  ScreenCast `Start` spins (~95% CPU) and every share hangs — drop-in
  `xdg-desktop-portal-hyprland.service.d/10-asahi-pipewire.conf` (`PartOf=pipewire.service`).
- **asahi-debug**: Fedora Asahi health (`asahi/bin/asahi-debug [--json]`). dnf/rpm,
  `wpa_supplicant`, asahi-audio, `speakersafetyd`, `kernel-16k`, HID, notch, sshd mask,
  no-hibernate (Wi-Fi radio switched off on purpose is PASS). Not pacman/iwd/SDDM. Test: `asahi/bin/asahi_debug_test.sh`. Not part of
  `make doctor`; must not flag Hyprland on generic Linux.
- **Night light**: Super+Ctrl+N → `asahi-nightlight` (hyprsunset). On = `hyprsunset.conf` 1500K;
  off = `hyprctl hyprsunset identity`. Identity profile so autostart tints nothing; autostart also drops the
  last session's `nightlight.json` (the chip showed on with no tint).
- **Bar notch**: cutout is a hole (`BarModel.notchRegionInset`), not a spacer. Height is geometry
  (3024x1964 → **74**), width is the real cutout (370/3024 of logical width + 12). Overflow is
  clipped at the wall; `ccuCompact` (reads compact-independent `fullWidth`, the widest provider's
  measured chip) is the only give: the countdown drops — the clock always shows weekday + date, both in the same size and
  colour. The usage chip has a fixed width (the widest provider's measured text + 8 px each side), text
  centred (a width that followed the text shifted the bar at every 10 s rotation; right-aligned text hit the mic).
  Chip pads are 6px, `barIconSlot` 26. Anything added to the
  right cluster eats that budget. Bar = `max(Style.barHeight 40, notch)` (notch is 37 logical at
  scale 2) — 40 fits the two-line media chip. Left cluster: workspaces → SysChip → BackupChip →
  media (gets the leftover, `maxChipWidth`). Bell (`Notifications.qml`): on the notched panel pinned
  to the right wall of the cutout (`notifNotch`), elsewhere the first right chip (`notifBlock`);
  counted in `rightOthers`. Clock stays rightmost; at the left the bell starved the media chip.
  SysChip adds the average SMC temperature (`tempAvg`: mean of macsmc_hwmon `temp*_input`, read
  in-process — no SoC die °C on Asahi) only while it fits (`showTemp`: with media playing the chip
  keeps ≥ 200 px; computed from `baseWidth` / `naturalWidth`, never the capped widths).
  Volume / Microphone chips: click = mute, wheel = step, right-click = Media quick pane.
- **Workspaces**: `monitors.lua` pins 1–5 to the live external and 6–10 to eDP-1 (clamshell: 1–5
  only); 1 / 6 are `default` + `persistent` so `Monitor:set_workspace` (keeps focus, existing
  workspaces only) can move a monitor off an empty stray id (a fresh external comes up on 11). No
  scratchpad / special workspaces. Bar `WorkspacesBlock`: this bar's monitor only
  (`Hyprland.monitorFor`), numbers in one tray; the active one is a sliding capsule with a state
  glyph instead of its number (fullscreen > maximized > pinned/PiP > floating > grouped > tiled; from
  `activeToplevel`, else lowest `focusHistoryID`) and one icon per app class (count badge, 4 + `+N`).
  Widths are computed, not measured: capsule, items and `chipMove` share 300 ms OutCubic, and
  `implicitWidth` is the final width. Click the active one = icons on every workspace, flag file
  `~/.local/state/asahi/bar-workspace-icons` (all bars, survives restarts). `ScriptModel`s keep
  items alive (a JS-array Repeater rebuilds them and kills the animations). `refreshHyprClients`
  calls `Hyprland.refreshMonitors()`: Quickshell applies `workspace` before `focusedmon`, so a
  cross-monitor switch left the old monitor's `activeWorkspace` wrong.
- **Bar tray**: `maxInline` 3, rest behind `+N` → `TrayPanel.qml`. Use `SystemTrayItem.NeedsAttention`
  (no `SystemTrayStatus`). Popups need `screen:` + `exclusionMode: ExclusionMode.Ignore`.
  Bar popups are one at a time: `BarHost.openPanel` ("sys", "rec", "media", "ccu", "tray"; the
  launcher, the calendar and the notification sheet clear it; keybind / IPC opens reach the focused bar's
  `requestPanel` through shell signals — no second open flag; not counters: a bar created later replayed them). Every bar popup (calendar and
  RecordPanel too) closes on Esc or click-outside: `HyprlandFocusGrab` whitelists the popup
  **and the bar window** (else the opening click counts as outside) — `QsWindow.window` needs
  `import Quickshell` (without it QsWindow is undefined and tray menus silently break); an Item is
  dropped. Esc is a `Qt.ApplicationShortcut` (the grab may focus the bar). App menus take their own
  popup grab: TrayPanel opens them via `QsMenuAnchor` and drops its grab until `closed`.
  `HyprlandFocusGrab` dies on `focusable: false`. Attention dot is static (a pulse redraws the bar
  every frame). Menu positions are window coords (`mapToItem(null, …)`).
- **Bar = click to act, event-driven**: chips appearing / vanishing slide their left-cluster
  neighbours (Row `move`/`add`, off for the first second); the right cluster, anchored right, only fades new chips
  in (`add`): `move` there animated from the old in-row x and the clock side jumped (REC chip). Hover tint (`HoverTint`),
  tooltip only on tray icons (and the Bluetooth chip's battery list),
  night-light chip only while on. The REC dot blinks on the elapsed tick (no animation). The mic glyph
  turns orange while an app records from it (`PwNodeLinkTracker`). Vol/mic
  (`AudioChip`, `input`) bind Pipewire (+`PwObjectTracker`), BT binds BlueZ,
  battery = `UPower.displayDevice` in QML (glyph and percent, no script or poll), network = `nmcli monitor` (+30 s
  signal poll), CPU/RAM/heatpipe in-process `FileView`; `asahi-cpu` (`{tooltip, cores}`) / `-memory` only while SysPanel is open. Stay-awake / night light
  / timer watch files (FileView's directory watch sees create/delete). Long-lived children get
  `setpriv --pdeathsig TERM` (a SIGTERMed qs orphans them). Chip clicks →
  `barHost.quickRequested(key)` → shell.qml (no `qs ipc` client per click). Wheel steps accumulate
  to 120, horizontal swipes ignored. Visualizers share one cava (`services/Cava.qml`, `hold()`);
  hidden items bound to it still repaint, so bars exist only while shown. One bar per screen, one
  fetch: stats, network, update checks and `hyprctl clients` live in `services/BarData.qml` and every
  bar binds to it (each bar polled on its own before: two dnf checks, two nmcli monitors, 2× forks per
  window event); BarHost re-exports them under the old names.
- **Media chip / popup**: chip = art thumb (accent ring while playing) + title/artist; title slides
  only on hover (no free-running marquee). Click = `MediaPanel` (compact serpantinum `MusicPopup`,
  checked against its source: blurred art + 0.55/0.72/0.90 wash, grooved vinyl 25 s/turn (0.9 when
  paused), `WavySeekBar` = upstream constants at 16 ms only while shown + playing, surface0
  transport 36/52/36 (popup 680 wide, disc 110), shuffle/loop if supported, cava ring around the disc),
  middle = play/pause, right = next. The card is `MediaCard.qml`, one row (disc | text + seek | transport),
  the same in the launcher Media pane (`fontScale`); it imports its sibling `WavySeekBar` qualified
  (`import "." as Components`): loaded via the pane's Loader path a bare one is "not a type".
  `Players.pinned` = source pill cycle (2+ players). Length = `Players.length` (0 = placeholder bar:
  `WavySeekBar.indeterminate`, a fainter ridge resting on the track — no fill, handle, seeking or times):
  Chromium passes the media element's duration — INT64_MAX µs while Infinity (`2562047788:00:55`), and
  for Apple Music web (gapless MSE) the buffered end, +10 s every 10 s, with the position counted from
  the album start (and the album's end once all is buffered; paused, nothing tells). So: < 1e6 s for
  every player, and Chromium's (`.chromium.` bus name) only after it held still through 12 s of playback
  of the track (`lengthHeld`; YouTube's seek bar shows after that) and while the clock restarted at the
  last track change (`clockRanOn`: position ≥ 15 s 5 s after it). Other players: shown at once, a track
  starting mid-way included. Verified on Apple Music (paused fresh shell, growth, 46 s playing: never shown)
  + a fake Chromium MPRIS. Firefox MPRIS usually has no length → placeholder bar. Seek holds the target 1 s (no jump back). An Item stays `visible`
  inside a hidden PopupWindow: gate per-frame work on the window (`WavySeekBar.live: root.visible` —
  without it the 16 ms wave repainted while closed, +1.4 % CPU; open popup ≈ 19 % of a core). IPC `media panel` toggles
  it on the focused screen (shell `mediaPanelRequested` → `BarHost.requestPanel`). Rounded content needs `ClippingRectangle`
  (`clip` is rectangular: the blurred art's corners showed past the card radius).
- **Apple Music app**: `asahi-apple-music` = Chromium `--app` on its own profile (own process → own MPRIS player,
 named via `/proc/<pid>/cmdline`, which Chromium space-joins). Widevine: copies the main profile's CDM hint (else
 previews only). `extension/clock.js` hands MusicKit's per-track clock to the Media Session. Linked into `~/.local/bin`
 (session PATH lacks `asahi/bin`). Shuffle / love / library bridge was tried and dropped (too much code).
- **Launcher quick panes**: one file each in `quickshell/remix/modules/launcher/panes/`;
  `LauncherWindow.qml` does `Panes.XPane { root: launcherSelf }` (`root` inside a pane is that
  property, not the launcher id). Shared M3 widgets in `modules/menu` — `MenuPill` / `MenuChip` /
  `MenuIconBtn` / `MenuLinkBtn` take `fontScale` (`MenuSwitch` has fixed size); a pane keeps its call sites with
  `component Pill: Menu.MenuPill { fontScale: root.uiFontScale }`. Selected = primary container +
  `menuSelBorder` hairline; hover = `m3stateHover` layer (`Qt.lighter` is invisible on light fills).
  A visible Quick tile **must have a pane** (`quickPaneKey` = the selected deck tile's `mode || key`);
  paneless actions go in `quickDeckHidden` (`wallpaper_carousel_test.js` derives that list).
  `openQuick` sets `quickStartIndex` before entering Quick (index 0 would build the Hub first). In Quick
  the hidden app list (`resultsList`) must not write `selectedIndex`: its model reset wrapped deck index 8+
  (Super+Ctrl+R / V opened Screenshots / Media instead of Backup / Clipboard; verified for all 11 panes).
  Typing on the root (it drills into Apps) also finds `quickActions` (panes, pickers; ranked just
  below apps on an equal score, no category bonus). A pane may
  define `handleEscape()` (Backup: subfolder → snapshot home) — LauncherWindow asks it first. Tab
  in Quick steps the rail; pane text fields swallow Tab (it leaked a Wi-Fi passphrase into the
  search). `=` is a scientific calculator (`calc_history.js`: own parser, no `eval` — a pasted expression reached launcher ids; radians, `30°`; `,` separates arguments, `.` decimals; ASCII constants only (`pi`, not `π`); `ans` = last copied result, a leading `*`/`/`/`^` continues from it; rows = result + the whole history (last 20, scrolls; saved with results + ans in `~/.local/state/asahi/calc-history.json`); ↑↓ walks it and selects the loaded row (Enter copies its result), a click loads, a second click copies; legend = `calcLegend` card at the bottom (`CalcHist.LEGEND` columns: caps label + lines, gaps split evenly; +3 rows budgeted, list clipped above it; empty state "Type an expression"); `log`/`root`/`round` default b=10 / n=2 / n=0; hex/bin/oct hint only for bases the input uses). `=` mode rows: result, 2 legend rows, last 8 history rows (↑↓ loads one, tinted; click loads it); hex/bin/oct hint only for bases the input uses. Any close keeps the pane alive (the next open
  destroys it): poll Timers, `SystemClock` and looping animations gate on `root.shouldShow`;
  countdowns (Monitors revert) and BT stop-retries must not. Must-finish actions run as
  `systemd-run --user --wait --quiet --collect` (exit code passes through — Wi-Fi band, BT
  pair/forget); `MonitorsPane` reverts on destruction. A failed connect deletes only a profile it
  just created with a typed passphrase. OWE ("Enhanced Open", nmcli `OWE`) connects without a password.
- **Recorder**: Super+Alt+R toggles `RecordPanel`. Bar REC chip only while recording (click =
  panel, right-click = stop). `asahi-cmd-record status --json` via `Recorder` singleton: at start, on the
  script's `ipc call recording refresh`, and 1 s while recording — idle, nothing polls. Webcam takes record
  the default source (voice); screen takes the default sink's monitor (wf-recorder takes one device). No pause
  (wf-recorder exits on SIGUSR1). IPC: `qs -c remix ipc call recording panel`.
- **Packages**: `PkgManager.qml` (launcher, bar updates chip → Updates tab) over `asahi-pkg` (dnf5 JSON).
  Update checks (chip every 30 min, Updates tab) run `dnf check-update` **without** `--cacheonly`: as a
  user that read the days-old `~/.cache/libdnf5`; offline (exit 1) they fall back to `--cacheonly`. Rows
  indented under "Obsoleting packages" are not updates. A new query first stops a busy one (`running = true`
  on a busy Process waits, delivers the old rows, then restarts). quickshell is excluded on the lionheartp copr
  (`dnf.sh` setopt; its newer build showed as an update and Upgrade all would install it). Install/remove/upgrade open Ghostty via `asahi-launch-tui` with `ASAHI_TUI_WAIT=1`
  (`--wait-after-command`: dnf's result stays readable). A query that crashes still prints `{error, packages: []}`
  (EXIT trap): the spinner stops and the status reads "Query failed: …". Test: `asahi/bin/asahi_pkg_test.sh`.
- **Wallpaper**: one picker, `WallpaperManager` (Super+Shift+W). `ipc: "wallpaper"` and
  `wallpaper: true` in `quickDeckHidden` — not a Quick tile; search still finds it. Browse:
  `WallpaperCarousel` (skewed window fan: centre 16:9, neighbours are leaning
  slices; ←/→, Ctrl+h/l, wheel, click a slice to select; ⏎/Apply/click the centre
  applies, Esc restores). The picker covers the windows with the wallpaper itself (blurred,
  crisp while Live). Live preview is **opt-in** (`WallpaperService.liveMode`, default off): Shift /
  Shift+←/→ / Live chip turn it on (Esc / the chip turn it off); ignore bare Shift in the search
  field. Live previews never reach hyprpaper (the picker and the fade overlay cover it); applies are
  one queued `apply`. Wheel/trackpad steps accumulate to 120. Debounce 70ms. Color index from
  cached thumbs → `wallpaper_colors.js`; filters on `WallpaperService.arranged(query)`. Test:
  `wallpaper_colors_test.js`.
- **Wallpaper span** (idea: omarchy-wallpaper-cutter): `asahi-wallpaper-span` cuts the current
  wallpaper across the live layout (logical px, cover over the bounding box, native-res slices in
  `~/.cache/asahi/wallpaper-span/`, only the live set kept). Bezel `gap` (default 0, one value for
  all seams; Monitors pane slider 0-128 px in 8 px steps, cut 400 ms after the drag rests): each
  seam of touching outputs becomes a strip, outputs past it move by `gap`. EDID mm are not used (LG
  reports 700x400). hyprpaper keeps per-monitor entries over the `,path` wildcard — every set
  (`apply` / `sync`) names each output; all `WallpaperService` desktop sets go through the script.
  `sync` puts the current wallpaper back on every output (cut while spanning; no-op and no state
  write when it already shows): on `WallpaperService.screenLayout` changes (Quickshell.screens
  geometry, 1.5 s debounce), at shell start, and after Super+Ctrl+Alt+P (hyprpaper starts on
  `~/.local/state/asahi/lock-wallpaper`, the current image; no slideshow). One output: no cut (plain set, `outputs` cleared); slices are written to
  `.tmp` and renamed. Monitors pane: the header fills the current layout mode (Mirror / Extend /
  External); Span is a switch in its own row (2+ displays, or while on), the gap row only while on;
  tiles show the slices. Picker previews stay uncut. Test: `asahi/bin/asahi_wallpaper_span_test.py`.
- **Autotheme**: Hyprland has no portal Settings — `portals.conf` pins Settings to gtk. Flavours
  `source content vibrant calm mono` (`FLAVORS` is the source of truth; saturation is a fraction of
  gamut room, never a multiplier). Every ANSI / named color stays in its hue family (`HUES`,
  `_family_hue`: red stays red on any wallpaper; red/orange lean only 25 % toward it, they mean critical vs
  warning); text ladders are WCAG-sized (subtext0 ≥ 4.5:1 on
  base, text on accent = crust). A bare run keeps the saved flavour (colors.json `variant`) and
  prefers `quickshell/wallpaper.conf`; runs hold `asahi-theme/.lock`. Writes
  `~/.local/state/asahi-theme/` (no colors.toml / Chromium policy any more). GTK ini is a real file,
  not a symlink. Unset portal `0` = light. Live: Ghostty `reload-config`, Quickshell `FileView`,
  Hyprland borders, btop SIGUSR2, Firefox. **GTK3 never repaints live** — do not add watchers.
  Tests: `asahi/theme/tests/test_palette.py`, `asahi/theme/smoke_test.sh` (no argument = the saved wallpaper
  and flavour: it rewrites the live state unchanged; it used to skip silently on a missing example).
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
- **Spell check = English + German everywhere**: flatpak `languages en;de` (`dnf.sh`; existing installs need
  `flatpak update` of the `.Locale` refs) — else the sandbox `de_DE.dic` is a dangling symlink. Host `hunspell-de`
  (Thunderbird links `/usr/share/hunspell`, Sonnet). Firefox + Thunderbird `spellchecker.dictionary` `en-US,de-DE` (user.js;
  per-site picks live in `content-prefs.sqlite`). nvim stays one language at a time: `<Space>ts` cycles en_us → de → off.
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
- **Notification images**: `localImage()` only `image:`/`file:`/`/…`, never `image://qsimage/` (image data dies
  with the Notification, which Quickshell frees right after `onNotification`: the card showed an empty box —
  app icon instead). `appLabel()`: app name, else the desktop entry's Name (Firefox / Ghostty send none).
  `stripMarkup` drops known tags only (`Jane <jane@…>` is text). Summary/body are
  `Text.PlainText` (no `<img src>`). Toasts top-centre (only `top` anchored → layer-shell centres
  them under the notch; they drop in from y −24), `ExclusionMode.Normal` + zone 0 (clears
  bar/notch). Bar popups and toasts share `Style.popupBorder` (overlay1 @ 0.6, `popupBorderWidth` 2 px) — without it
  they vanished against dark windows; in-sheet history cards keep the hairline. History persists to `~/.local/state/asahi/notifications.json` (0600, non-atomic
  writes keep the mode). History sheet hangs top-right (toasts are top-centre, no overlap). Hyprland draws
  layer popups (all bar popups) above the overlay layer, so an open one covered the toasts: each BarHost reports
  its popup's half (`setPopupSide`, from the chip) and toasts take the far top corner (`popupSide`). Its trash
  needs two clicks within 3 s ("Clear all?") — one stray click used to wipe everything; Esc / click outside closes it (focus grab; the bell click that ends
  the grab is ignored for 300 ms). Load never writes the file back (only real changes save); Do Not
  Disturb is saved there too (a QML save reloads qs and used to turn it off). Critical cards carry a
  static red tint (a pulse repainted every frame while an alert stayed up). Bell
  badge = unread since the sheet last opened/closed. Toasts: `ListView` over
  `ScriptModel { values: root.toasts }` (keeps cards — a Repeater on the array rebuilt them and
  restarted every timer); enter/leave animate `fade`, not `opacity` (swipe binds it); the window keeps
  its height 260 ms after a change (`toastHold`: contentHeight drops at once and clipped the leave
  animation). Timeout: critical never, app `expire` (ms, the raw `notify-send -t`) else 6 s, paused on
  hover / drag; swipe past 18 % dismisses; one "Asahi Battery" toast at a time (its critical alert
  repeats every minute); low urgency (0) stays low;
  times relative ("now", "N min ago"); an identical repeat (app + summary + body) within 100 ms is
  dropped, different ones arriving together are kept. Super+comma `dismissOne` closes the newest popup;
  Super+Shift+comma `dismissAll` clears popups and the saved list (popups only looked broken: they time out).
  Sheet and bar popups (calendar: shell.qml; sys / rec / media: BarHost) close each other; the sheet's
  focus grab arms 200 ms after opening (an unmapping popup would clear it at once). Toast window
  lingers 260 ms after the last toast so its leave animation plays. History groups per day by app
  (`historyGroups`, built only while the sheet is open — day labels stay fresh past midnight): 2+ from
  one app collapse to the newest card + header (count, Show all, ✕ group). Opening the launcher closes
  the sheet (its focus grab kept the launcher's keys). Click = focus sender by
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
- **Volume keys**: `asahi-media-control output-volume raise|lower|+1|-1` unmutes the sink (Media pane
  output slider too) **only if it is muted** — a `set-mute 0` on every step clicked the speakers
  (`unmute_if_muted`); the mic is never unmuted by a level change. Launcher Logout / Restart / Shutdown
  carry `confirm: true` (Data.js): first Enter arms for 3 s (OSD "Again to confirm"), second runs.
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
- **Bluetooth monitor** (port of uBruckhaus/omarchy-bluetooth-monitor): `asahi-bluetooth-monitor` (stdlib Python) is one
  long-lived child of `services/BtMonitor.qml` (bar chip + Bluetooth pane): Logitech HID++ over hidraw (receiver slots;
  wired / Bluetooth direct, long-only nodes get long reports: type, battery, DPI, SmartShift, wheel, Fn swap),
  `upower --dump`, BlueZ `GetManagedObjects` (both off with "Other Bluetooth devices"); one JSON line per scan, JSON
  commands on stdin (`open closed refresh set thresholds options`). Rescans on `upower --monitor` peripheral lines (the
  laptop battery / AC every 30 s do not count), HID++ `0x41`, a failing (unplugged) node and commands, else 60 s
  (10 s while the pane is up; the pane resets `paneOpen` on destruction — a Loader drop skips the Binding restore).
  A receiver's node also carries every DJ input report: after a wake-up without a notice the nodes sit out 1 s.
  It alone writes `~/.local/state/asahi/bluetooth-monitor.json` (thresholds 25/10 %, other devices, language,
  bar tooltip, HID++ settings per wpid — reapplied when a device seen gone (asleep, unplugged, out of range)
  answers again; a first sighting keeps its own, as upstream). Errors (`message_code` / `message_args`) last one
  snapshot. While hidraw is denied, UPower's `hidpp_battery` rows (the kernel driver) stand in, a denied direct node takes
  the one with its name. No hiding of
  devices (dropped: little use, much UI). The pane merges BlueZ rows with monitor devices by address (one row per
  address), the rest are "USB & receivers" (40 rows per section); a UPower battery on a cable reads `usb` via
  sysfs (upstream: wireless). Receivers show 6 slots (upstream). Bar chip (upstream's batteryAlert): the first
  online device at the worst level, a mouse at that level takes over → its kind glyph, orange / red;
  right-click = rescan; its tooltip (per-device batteries, upstream) is on by default, off in the pane.
  Strings: `services/bt_i18n.js` = upstream's English + German tables (its other six dropped: nobody here checks
  them) + the pane's own keys (incl. `lvl_*` level words);
  language = pane setting, else LC_ALL / LC_MESSAGES / LANG. hidraw is root-only: "Allow access" →
  `pkexec asahi-logitech-access` writes its inline rule to `/etc/udev/rules.d/42-asahi-logitech-hidraw.rules`
  (`KERNELS=="0003:046D:*"` / `0005:046D:*` → uaccess, the device's own vendor; opt-in, not in the installer;
  revoking needs a replug or `setfacl -b`). Pane scan = a `bluetoothctl --timeout 300 scan on` process (BlueZ ends
  discovery with its client), restarted after 5 s without `Discovering` (with `--timeout` it never exits on a failed
  StartDiscovery). Forget = two clicks within 3 s. A headset / speaker connected from the pane becomes
  `Pipewire.preferredDefaultAudioSink` (sink by MAC or name, 8 × 500 ms). Esc / Backspace step back (settings, an
  open device only while shown; `handleBackspace` hook in LauncherWindow, no other pane defines it).
  Verified live (2026-10-16): wired G502 HERO = HID++ 4.2, getDeviceType 3, 0x2201 DPI 100–25600/50, writes
  take effect. Tests: `asahi/bin/asahi_bluetooth_monitor_test.py` (incl. an emulated Bolt receiver on a socket,
  unplug EIO, replug reapply), `services/bt_monitor_test.js`, `services/bt_i18n_test.js`.
- **zram**: only swap. `asahi-system` installs zstd (`zram-generator.conf.d`) +
  `sysctl.d/99-asahi-zram.conf` (swappiness 150, page-cluster 0, watermark boost 0 / scale 125).
- **Wi-Fi scans refused (2026-10-16)**: Networks list shows only the connected AP; kernel `brcmf_cfg80211_scan: Scanning
  suppressed: status (4)`, wpa_supplicant `CTRL-EVENT-SCAN-FAILED ret=-11`, `nmcli … --rescan yes` still exits 0. Cause: a
  DHCP restart on an already-activated link (the Proton VPN app's `device-reapply` of `ipv4.routes`): NM sends nl80211
  `CRIT_PROTOCOL_START` (DHCP) but `…_STOP` only on activation, and brcmfmac clears its scan-suppress bit only on STOP
  (it ignores the 5 s duration). A plain `nmcli device reapply wld0` does not help; `nmcli connection up id "<ssid>"`
  (reconnect, a few seconds, Proton's tunnel survives) does. Proper fix would be kernel-side (`~/linux-fairydust`).
- **Wi-Fi band**: `asahi-wifi-band [status|auto|2.4|5]` pins the profile's band (the AP band-steers
  between its 2.4/5 GHz BSSIDs), reverts if the reconnect fails; Network pane "Band" pill cycles
  auto → 5 → 2.4. BCM4388 resume fix (omarchy-mac) not ported: post-resume rejects recover in
  6–30 s. Test: `asahi/bin/asahi_wifi_band_test.sh` (fake nmcli).
- **Kernel**: self-built `fairydust` (USB-C DP alt mode) in `~/linux-fairydust`, 16k pages;
  `asahi-debug` accepts `*fairydust*`. Local fixes live only in `~/linux-fairydust` (never in this
  repo): brcmfmac `roam_delta` init (`WLC_SET_ROAM_DELTA error (-52)`), dcp HPD re-sample on resume
  (HDMI-on-resume untested), dcp atomic_check passes a CRTC that stays off, j414s DTS disabling AVD + its DART (no avd-fw on Fedora; the failed
  probe keeps `avd_sys` powered — needs `make dtbs && sudo make dtbs_install && sudo update-m1n1`).
  USB-C display = `card2-DP-1`; no `ddc` link on DP or HDMI. The roam fix (and
  `appledrm.ko` with the two dcp fixes) is in `/lib/modules/7.1.13-fairydust+/updates/`, which depmod prefers: delete it on the next full rebuild.
- **m1n1 DTB pin**: m1n1 `boot.bin` carries ONE device-tree set. On each kernel add/remove grubby's
  `10-devicetree.install` re-points `/boot/dtb` to the newest Fedora `dtb-*` and
  `15-update-m1n1.install` rebuilds `boot.bin` — fairydust then boots without DP alt mode (no
  `/proc/device-tree/aliases/dcpext1`). `asahi-system` (before dnf) links `/boot/dtbs/fairydust` →
  the running release, sets `DTBS="/boot/dtbs/fairydust"` in `/etc/sysconfig/update-m1n1` and
  `UPDATEDEFAULT=no` in `/etc/sysconfig/kernel`; rerun after a new fairydust (`asahi-debug` WARNs
  `fairydust-pin`). Recovery: fix the pin, `sudo update-m1n1`; worst case swap `m1n1/boot.bin` and
  `boot.bin.old` on the ESP.
- **WM defaults**: `general.lua` — `dwindle.force_split = 2`,
  `allow_session_lock_restore`, `on_focus_under_fullscreen`, `initial_workspace_tracking = 0`,
  `anr_missed_pings = 3`, `group`/`groupbar` themed to the Catppuccin borders (Super+W groups),
  `hl.gesture` 3-finger workspace swipe (`scale 0.75`; `workspace_swipe_cancel_ratio = 0.25` in `input.lua`).
  Validate keys against `/usr/share/hypr/stubs/hl.meta.lua`, then
  `hyprctl reload && hyprctl configerrors` (`Hyprland --verify-config -c asahi/hypr/hyprland.lua` checks
  without reloading, but still runs the reload hooks — asahi-hdmi sync, monitor-scale/clamshell apply —
  against `$HYPRLAND_INSTANCE_SIGNATURE`; `HYPRLAND_INSTANCE_SIGNATURE=none` makes their hyprctl calls fail,
  but `asahi-hdmi sync` still bumps `$XDG_RUNTIME_DIR/asahi-hdmi.gen`: not during an HDMI settle). Lua dispatchers: `hyprctl dispatch 'hl.dsp.…({…})'`
  (legacy `dispatch <name> <args>` is dead). Float is its own call; maximized refuses resize+pin.
  Window-rule `opacity` multiplies with `inactive_opacity` — use `opaque = true` for media/PiP/
  webcam. Capture binds (screenshot/record/picker) must not be `locked` (recording from the lock
  screen keeps running after unlock). `suppress_event = "maximize"` for every class: apps that
  maximize themselves stay in their tile (Super+F still maximizes).
- **asahi/bin**: helpers in `asahi/bin/lib/common.sh`, sourced via
  `$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/lib/common.sh`. `asahi-launch` is the only
  `uwsm-app`/`setsid` site. Sibling paths through that dirname, not `$HOME/.dotfiles`.
  `components.sh` chmods `asahi/bin/*` and skips `lib/` (a dir) — keep sourced files there.
- **Untrusted text**: a `Text` showing outside strings (track titles, SSIDs, Bluetooth names, clipboard,
  tray titles, file names and previews, notification text) sets `textFormat: Text.PlainText`. The default
  AutoText renders `<img src=http…>`: a remote fetch without a click (omarchy PR #8397).
- **Quickshell launch**: never `qs -d` (EPIPE/`qFatal` if the parent is gone). `setsid -f qs -n -c
  <module>`. Bar vanished → `asahi-debug` coredumps first. qs reloads on save (log:
  `/run/user/$UID/quickshell/by-pid/<pid>/log.log`). `grim` blocks on a DPMS-off output — always
  `timeout`. zprofile unsets Lmod's `BASH_ENV` (13 ms → 1.2 ms per bash start).
- **Polkit**: `modules/system/PolkitAgent.qml` (Quickshell `PolkitAgent`) answers polkit — pkexec and GUI
  admin prompts had no agent and failed silently. One card on the focused screen; Enter submits, Esc cancels.
- **Stay awake**: one flag `$XDG_RUNTIME_DIR/asahi-stay-awake`, owned by `asahi-stay-awake`.
  hypridle listeners skip under it (`asahi-idle` checks `status`).
- **Idle (macOS-shaped)**: hypridle is a plain `exec-once`, **not** Fedora's `hypridle.service`: hyprlock, the
  saver and asahi-idle's loops would live in the unit's cgroup (a crash restart kills the lock screen →
  lockdead), and `qs ipc` matches instances by display string — the session's `QT_QPA_PLATFORM=wayland;xcb`
  reads as unknown, so a caller without it (systemd units, a bare shell) finds no shell unless it passes
  `--any-display`. Super+Ctrl+Alt+I = `asahi-restart-app hypridle` (→ `asahi-launch` → a uwsm-app scope:
  no Restart=, the session env is inherited). `hypridle.conf` fires `asahi-idle at <secs>` at 150/180/300/600; the
  step comes from the power source **at fire time** (unplug mid-idle still locks). Battery: dim +
  kbd 10% at 2.5 min → lock, DPMS off + kbd off at 5 min, no saver (longer than macOS's 2 min by
  choice; dim halfway like macOS). AC: saver 3 → dim 5 → off 10 min. Panel backlight is **not**
  zeroed; `off` itself suspends 60 s later. The hyprlock surface map is
  fake pointer motion (`simulateMouseMovement`): it fires on-resume and restarts every listener, so
  `off` ignores wakes while locking (`$XDG_RUNTIME_DIR/asahi-idle-locking`) and then watches DPMS —
  `key_press_enables_dpms` relights on input → `asahi-idle wake`. Saver skips while locked; a dim
  threshold while already locked (Super+Escape, then away) runs `off` instead (DPMS off, suspend a
  minute later): the lock screen no longer stays lit until the off threshold. Sleep skips while a
  running sink carries signal (`pw-record -P '{ stream.capture.sink = true }'` of its
  monitor — without that property pw-record falls back to the mic; the monitor is pre-volume, so
  muted playback counts, silent page streams don't) or an external output is enabled (`external_on` in
  `lib/common.sh`, shared with `asahi-clamshell`; Hyprland's `FALLBACK` placeholder is not one). `off` is
  single-instance (flock), polls input every 5 s, retries sleep every minute (a refused `systemctl
  suspend` keeps the loop alive) and flags locking *before* stopping the saver
  (its unmap fakes motion too); the flag is honoured ≤15 s; hypridle's wake burst coalesces (flock).
  Saver ~30 fps: one shared 33 ms tick drives every scene (the ascii scene's own timer doubled its
  frames; Life's recursive source is not `live` — it re-rendered at 120 Hz — and steps once per tick; a
  recursive texture costs one extra frame per update, so it renders ~60 fps).
  Saver keys need `focus: true` on its Loader (a focus scope) and no `focusable:` (it overrides
  `WlrLayershell.keyboardFocus`). `asahi-idle wake` stops the saver before the lid check.
  **Keyboard/trackpad cannot wake s2idle** (MTP DockChannel has no wakeup source); lid and power
  button (SMC) can. Manual sleep (Super+Ctrl+Alt+S, launcher Suspend) is `asahi-idle sleep`: refused
  with a notification while an external is on. Log: `~/.local/state/asahi/idle.log`. Test:
  `asahi/bin/asahi_idle_test.sh` (fake power supply via `ASAHI_PSY_DIR`, lock state via `FAKE_LOCKED`).
- **Time Machine**: `asahi-timemachine` = restic, one repo (`$TM_DIR` on the drive labelled `$TM_LABEL`)
  reached either locally (drive on this laptop → udisks mount, never unmounted: eject it yourself) or
  over SFTP (drive on the backup host). Host/path/port live **only** in
  `~/.config/asahi-timemachine/config` — never commit them. Own key `id_ed25519` there is
  `restrict,command="internal-sftp"` on the host (no shell, but full file access as that user — not
  a sandbox); ssh runs `-F /dev/null` + no agent (else the main key sneaks in and gets a shell).
  Password file beside it (copy in the password manager). Hourly timer, backs up only if last ok >
  `TM_MIN_AGE_H` (72); offline (also restic rc 10: host up, drive on it not mounted) = skip, not fail.
  A run dying on `refresh lock` (lid close) or an unreachable repo = `interrupted` (silent, retries);
  only a reachable repo failing is `failed` (critical, **once per error text** — the timer retries
  hourly). Start/interrupted/skipped notify only for `start` (`--force`). `last_success` is set as soon
  as the snapshot is saved (`housekeeping` flag → `status.cleaning` while forget/prune ≤ weekly,
  `check` 1% ≤ monthly (~20 s; damage = critical every run) and `stats` hold the repo). No success for
  `TM_WARN_D` (10) days → `.overdue` + one critical notification per stale `last_success`. `r unlock`
  before backup (a killed run's lock blocked prune). Excludes `*.o *.ko .*.cmd` (~28 GB of
  `~/linux-fairydust`), `~/.local/share/flatpak`, `~/.Trash` (`del`'s trash); `.nobackup` skips a dir.
  restic stderr is also copied to the journal: `asahi-timemachine log`. `stop` = `systemctl stop` (state
  left `running` reads `interrupted`). `IOSchedulingClass` alone is weak on mq-deadline — units also
  get `CPUWeight=idle` (`start` passes the same props).
  State `~/.local/state/asahi/timemachine.json` = flock + atomic `mv` (FileView follows renames;
  `status` only reads it and adds restic percent/ETA). `overview` caches snapshots + old rsync dirs +
  drive df (one SFTP session). Bar `BackupChip` (left of the notch, after SysChip) only while running /
  failed / check_error (red) / overdue (orange). Quick pane `backup` (Super+Ctrl+R): overview tiles,
  30-day strip, snapshots, browse (listings cached per snap|path; `ls` exit 4 = folder not in that
  snapshot), restore → `~/Restored/<date>-<id>[-HHMMSS]/<abs path>` (a re-restore gets a new folder —
  restic's default `--overwrite always`; nothing matched (non-UTF-8 `�` name) = exit 1; real path in
  `.last_restore`, since the transient unit runs **without** `--pipe` — a dead client would SIGPIPE
  it). Names/errors are `Text.PlainText`. The old rsync snapshots `fedora-home-backup-*` on that
  drive are `chattr +i` — never delete (2026-09-28 is the last full one). No sleep inhibitor (lid
  close must still suspend). After install: `asahi-timemachine init` (key, password, repo, timer).
  Test: `asahi/bin/asahi_timemachine_test.sh`.
- **Writing tools**: Super+Shift+E → `modules/writing/WritingTools.qml` (GlobalShortcut `writing-tools`).
  `asahi-writing-tools capture` copies the focused window's live selection (`send_shortcut` Ctrl+C behind a
  `--sensitive` marker, previous clipboard restored **always** `--sensitive` — a browser password has no
  hint and would land in cliphist; `; printf .` keeps a trailing newline): primary misses keyboard selections (Firefox Ctrl+A
  kept the last mouse word); terminals use primary (Ctrl+C = SIGINT). Plus
  `activewindow` + `cursorpos`; picker at the cursor (1/2/3 = Proofread/Rewrite/Concise) morphs into
  original/suggestion with a word diff + char marks inside one-word swaps (`writing_diff.js`, test
  `writing_diff_test.js`; capture: `asahi/bin/asahi_writing_tools_test.sh`). `run` = Anthropic API
  streamed (curl SSE → `{delta}`/`{stop}`/`{error}` lines),
  `claude-haiku-5-5`, `ANTHROPIC_API_KEY` from the session env, else `zsh -ic` (fd 3 only); curl gets it as a
  header file (`-H @<(printf …)`, never argv). Only `end_turn` is a result: a dropped stream or `max_tokens`
  is an error (Replace would drop the rest of the selection). `fitOutput` keeps fences the selection has.
  The card **never takes keyboard focus** (`WlrKeyboardFocus.None`) — QtQuick fields drop their
  selection on focus loss — so Replace is just `wl-copy` + `send_shortcut` Ctrl+V to the source address.
  Card keys = Hyprland submap `writing` (`bindings.lua`, no desc → not in the Keys panel; Escape also
  resets it; `catchall` swallows other keys so typing can't overwrite the selection); qs enters it on
  open, resets on every close and on destruction. Pane drag-select is its own MouseArea (`select()`),
  not `selectByMouse`: Qt's mouse selection claims primary and GTK then drops the source selection.
  Replace off for terminals and truncated (>20000 chars) captures.
- **Timers**: `asahi-timer add <dur> [label]` = transient `systemd-run --user --on-active`.
  Launcher `:timer 10m tea` (`arg_commands.js`, tested).
- **Window pop**: Super+O → `asahi-window-pop` (float/resize/center/pin/`pop`); second press
  retiles.
- **Display scale**: Super+Ctrl+plus/minus → `asahi-monitor-scale`. Legal scales are 1/120
  divisors (eDP-1: 1 / 1.333333 / 2). Saved per output name under `$XDG_RUNTIME_DIR`; HDMI-A-1 is
  reused by both sinks. Positions are **derived** (`anchor_offset` in `lib/common.sh`), never pinned.
- **Refresh rate**: eDP-1 stays 120 Hz (`monitors.lua`); a battery 60 Hz switch saved ~3 W only
  during video — do not re-add. Wi-Fi power save: no gain, stays off.
- **LAN devices** (idea: uBruckhaus/omarchy-wlan-monitor): Network pane tabs Networks / Devices (`panes/LanDevices.qml`,
  `lan_models.js`). The pane layout stays the same on both tabs (VPN card + tools always shown: hiding them made it jump).
  Scope he wants: who is on this LAN, find printers away from home — no map, no FRITZ!Box mesh / rates / signal (removed).
  `asahi-lan watch` (stdlib Python, `setpriv --pdeathsig`) runs **only while Devices is shown**; JSON line per change,
  commands as JSON lines on its stdin. No background timer, no toasts. Sources: `ip -j neigh`, PTR at the router, OUI
  (hwdata), mDNS on its own socket **bound to 224.0.0.251:5353 beside avahi** (SO_REUSEADDR; the group address, so avahi
  keeps its unicast answers): firewalld `public` drops legacy-unicast answers to an ephemeral port — no avahi-tools. A
  host heard only over mDNS (a printer) gets one unicast mDNS question so the kernel ARPs it (MAC → row). **Untrusted
  networks are never pinged**; Rescan there is "Refresh". Trust (SSID + router MAC) = one ping-socket sweep of the /24
  when the tab opens and on Rescan, NEW badges (first 10 min after Trust = known). Printers: model from TXT, admin page
  from the IPP `adminurl` (rebuilt on the device IP). Row actions: Ping (`ping -c 4`, on click), SSH (Ghostty `ssh <ip>`,
  stays open on failure), web, rename / pin; no settings menu, no hide, no Markdown copy (he cut them). Store `~/.local/state/asahi/lan.json` (flock, 0600; also the
  grouping), last tab `~/.local/state/asahi/network-tab`. A VPN that blocks the LAN → banner. Panes load via `Loader`
  source, so a pane imports siblings qualified (`import "." as Panes`). Test: `asahi/bin/asahi_lan_test.py`,
  `lan_models_test.js`.
- **Speed test**: `asahi-speedtest [--json]` — Cloudflare 50 MB down / 25 MB up (~20 s; 100 MB is
  403). Network pane button.
- **Wi-Fi QR**: `asahi-wifi-qr` → `$XDG_RUNTIME_DIR` mode 600; `nmcli -s` for the PSK.
- **Autostart**: `asahi/xdg-autostart/` (only a Hidden stub masking gnome-keyring-ssh) vs Hyprland
  `exec-once` in `autostart.lua`. Verify no `app-gnome\x2dkeyring\x2dssh@autostart.service` under
  the user generator.late.
- **Secrets**: `asahi/kwalletrc` disables kwallet. `gnome-keyring-daemon --components=secrets`
  only; SSH is keychain. Do not start gnome-keyring ssh. The login keyring password is the
  login password; `pam_gnome_keyring` in `/etc/pam.d/login` (`auth` optional, `session` optional
  `auto_start`, applied by `asahi-keyring-pam`) unlocks it at the tty1 prompt. Do not seed an
  empty-password or `[keyring]` text keyring (unencrypted; `asahi-debug` WARNs, never auto-delete:
  it may hold secrets). Flatpaks (Zotero) reach it only via the Secret portal —
  `portals.conf` pins `Secret=gnome-keyring` (its `.portal` is `UseIn=gnome`).
- **SSH / keychain**: Fedora's `/etc/profile.d/keychain.sh` prompts every key on tty1 — export
  `KEYCHAIN_DONE=1` from `zshenv`. `asahi-ssh-keychain`: no `--quick`, drop a stale pidfile
  without killing a reused PID, start an **empty** `--noask` agent. First `git`/`ssh` unlocks via
  `AddKeysToAgent yes`. `zshenv` unsets `SSH_AUTH_SOCK` when `ssh-add -l` cannot talk to the agent
  (exit > 1).

## Shared
- **CCU**: one core, `sketchybar/helpers/ccu_common.py`. `asahi-ccu` reuses the cost scan (every transcript, ~2–4 s CPU) for 10 min
  (`~/.cache/asahi/ccu.cost.json`, dropped at midnight): popup cost figures lag up to that. Front-ends: Lua literal (sketchybar) or
  `--json` (`asahi-ccu`). `ccu_cost.py` is JSON-only (reserved keys). Claude plan = credentials `subscriptionType` +
  `rateLimitTier` ("Team · Max 5x"), email from `~/.claude.json` (local reads, no API). Asahi chip (idea: dancik/limitbar):
  provider mark + % of the **binding** window (main, or the 5-hour session when fuller) + countdown, red badge on
  the mark = another window ≥ 90 % (no `wk`/`5h` superscripts: rejected; the countdown tells the window). Marks are `PathSvg` paths in `components/marks.js` filled by a `Shape` —
  no MultiEffect tint (a layer pass in an always-on bar; layered marks also stayed blank in the offscreen harness after a
  late source change). Popup: main window (weekly / monthly) kept as "N% of … limit used" + reset
  line over a full-width bar (preferred to a row); the other windows (session, Fable, Cursor pools) are
  2-column mini tiles (`subLimits`: name … %, 4 px bar, "Resets Oct 22, 3:20 PM · 2h 4m" — absolute date + countdown,
  only where `ownReset` (≠ main reset ± 5 min); red ≥ 90 %, "reset, awaiting update" once passed) — label | bar | % rows looked misaligned. Plan only as the popup pill
  (not in the chip: rejected), header click opens the usage page. Chip rotation = `chipSwap` (roll up + fade, `shownIndex` swaps halfway, mark scales in). Grok Bot `usagePercent` is 0–100 (the app labels 0 < x < 1 as "1%"; reading ≤ 1
  as a fraction showed 0.77 % as 77 %). Cursor pools carry `span_sec` (else they read "weekly"). Test:
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
