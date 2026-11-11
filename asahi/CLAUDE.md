# Apple Silicon Linux: Aurora Fedora Remix (aarch64)

Loaded when a session works under `asahi/`; shared rules live in the root `CLAUDE.md`.
Default OS = **Aurora Fedora Remix** (this Mac converted in place from Fedora Asahi Remix 44 on 2026-11-09; next fresh
install = Aurora Fedora Minimal). Install: `make aurora` (= `make asahi`, `./install.sh aurora`). The `asahi` names
(dirs, scripts, components) stay; Fedora Asahi Remix keeps working, with gaps (untested since the move): power key tap =
logind's default poweroff (no `50-aurora-sep.conf`; our drop-in no longer sets `ignore`), no keyboard ALS daemon, no mic
relabel filter.

## Documentation
- Aurora Fedora Remix: https://aurorasilicon.org, https://github.com/aurora-silicon/fedora-aurora; local docs in
  `/usr/share/doc/aurora-*` (`aurora-sep`: Touch ID, power button, authselect)
- Fedora Asahi Remix (legacy): https://asahilinux.org/fedora/
- Reference ports: omarchy (https://github.com/omacom/omarchy, branch `quattro`), omarchy-mac
  (https://github.com/omacom/omarchy-mac-pkgs, runs the Aurora kernel)
- Hyprland: https://wiki.hypr.land/
- hyprpaper / hyprlock / hypridle: https://wiki.hypr.land/Hypr-Ecosystem/
- Quickshell: https://quickshell.org/docs/

## Notes
- **QML singletons**: need `qmldir` (`singleton Name File.qml`) + module import, by name — else `pragma Singleton` is
  ignored and `import "File.qml" as X` silently falls back to white/black. Prefer Quickshell `Singleton` (reloadable);
  never `Foo {}` construct. One added while qs runs stays `undefined` across hot reloads: restart qs
  (Super+Ctrl+Alt+W).
- **Lock on boot**: tty1 getty = auth gate; no hyprlock at Hyprland start, no `agetty --autologin` (zprofile can fall
  through unauthenticated). `./install.sh asahi-getty` (also `comp_asahi_system`) removes leftover
  `/etc/systemd/system/getty@tty1.service.d/10-asahi-autologin.conf`. Never restart `getty@tty1` live (kills
  Hyprland). No display manager; Super+Escape / hypridle lock. Fedora 45 presets **kmscon** as `autovt@` (getty@
  disabled): it holds the display's DRM master (Hyprland: `Could not take device /dev/dri/card1: busy`, crash before
  any log line) and logs in on `pts/0` (zprofile's tty1 check skips Hyprland). `asahi-getty` disables + masks
  `kmsconvt@`, enables `getty@` (next boot; never stop kmscon live — it may host the shell).
- **Console**: `asahi/vconsole.conf` (`comp_asahi_system`): `KEYMAP="de-latin1-nodeadkeys"` (≙ `input.lua`
  `de`/`mac_nodeadkeys`), `FONT="ter-v32n"`. xkb-converted maps (`/usr/lib/kbd/keymaps/xkb/`) fail
  (`lk_add_key … keycode -1`); `mac-*` = ADB keycodes, scramble `hid_apple`. Check
  `loadkeys --mktable <name> >/dev/null`. Font here, not a setfont unit (loses to `systemd-vconsole-setup`).
- **Sleep / lid / HDMI**: s2idle only (zram is no resume image): no Hibernate row, drop-ins ignore hibernate keys;
  `systemctl suspend`. Power key (= Touch ID) = Aurora's `/usr/lib/systemd/logind.conf.d/50-aurora-sep.conf`: press =
  suspend, 5 s = poweroff, ~10 s = SMC force-reset (was `ignore` until 2026-11-09; Aurora suspend tested OK). It
  bypasses `asahi-idle`'s guards (external display, audio); touching the sensor is no press. Our
  `asahi/systemd/logind.conf.d/90-asahi-sleep.conf` sorts after it (the old `10-` name lost). Critical battery:
  `asahi/upower/90-asahi-critical.conf` → `CriticalPowerAction=PowerOff` at 2 % (UPower `Auto` = s2idle, drains ~48 min
  to the SMC cutoff; only acts while awake). gsettings `power-button-action` is a no-op. F6 = KEY_SLEEP (tap bypassed
  idle guards): `autostart.lua` holds a session `systemd-inhibit --what=handle-suspend-key` (polkit, no root); `XF86Sleep` → Do Not Disturb.
  `./install.sh asahi-logind` also installs udev rules (HDMI lid inhibit, BT wake) + inhibit unit; HUP logind, never
  restart it; never `udevadm trigger` drm (hotplugs HDMI). `InhibitDelayMaxSec=15` = hyprlock time on lid close.
  Lid = `Apple SMC power/lid events` (`locked = true` in `monitors.lua`). Never set `HandleLidSwitch` (laptop-only =
  logind `suspend`); docked = `HandleLidSwitchDocked=ignore` + `asahi-clamshell` turns eDP-1 off. Without a lit
  external (`external_up`: Hyprland-enabled **and** DRM `enabled` or DPMS-off — 2026-11-02 an unmodeset DP-1 hotplug
  under lock left zero lit outputs; `asahi/bin/asahi_clamshell_test.sh`) close is a no-op — never DPMS-blank eDP there
  (races s2idle, `8000000a`, hangs) — unless a block inhibitor (`asahi-hdmi`: cable in, output off) stops suspend:
  wait 5 s for the external, else blank + lock.
  HDMI-A-1 / DP-1..6 stay `disabled = true` (`monitors.lua`) until `asahi-hdmi` enables one; logind doesn't count it docked
  → `asahi-hdmi-lid-inhibit.service` holds `handle-lid-switch` while HDMI/DP reads `connected` (udev: the **card's**
  `HOTPLUG=1`, connectors get none; `systemd-run` re-check after 3 s, sysfs `status` stale until Hyprland probes;
  start/stop, never restart: gap lets logind suspend); drop-in sets `LidSwitchIgnoreInhibited=no`. `asahi-dpms` only
  flips Hyprland-enabled outputs in the other state (redundant enable flashes).
  Hangs (laptop-only close stuck in s2idle; live HDMI plug freezing DCP: `valid_mode:0` + eDP flip, then **do not
  close the lid**): hold power ~10s, wait ~15s, tap power. `after_sleep_cmd` also runs after a refused suspend. Never
  add `asahi-hdmi sync` to resume. Diagnose `journalctl -b -1` (`Lid closed.` → `Suspending...` → `PM: suspend entry`,
  no `suspend exit`), `-t asahi-clamshell` (each lid decision + output states), `-t hyprland` (autostart's
  `/run/…/hyprland.log` mirror; it waits for `hyprland.lock`: the start hook ran ~80 ms before the lock existed, tail
  quit on the empty `--pid` and the 2026-11-09 session had no mirror — check `pgrep -x tail` after the next start).
  Test: `asahi/bin/asahi_hdmi_test.sh`.
- **Sleep drain (AsahiLinux/linux#262)**: s2idle ~3 %/h (`slept …` in `idle.log`) = kernel floor; don't chase it in
  userspace. Gauge stale-high 30–90 s post-resume → logged ~90 s after wake minus awake draw (AC sleeps uncorrected).
  No S3 / hibernate / RTC `wakealarm`. AOP ALS wakes ~3.6/s (#638): blacklist / PM notifier no help; lid-angle stream
  unstoppable. j314s #262 hangs = out-of-tree SEP Touch ID + `fprintd` (SEP is on since Aurora: suspect it if s2idle hangs
  return); ours were DCP.
- **Failed suspend**: fairydust: `apple-drm … failed to suspend: error -22` ← USB-C unplug with DP-1 on (clear-swap
  timeout set `dcp->crashed`). Aurora: the timeout only warns (`iomfb_poweroff_*: clear swap timed out`), the -22 path
  is untested there; Aurora's `thunderbolt_apple` also refuses sleep with a display on a TB tunnel. A key press /
  trackpad click while suspending aborts the entry with `-16` (EBUSY, `/sys/power/suspend_stats/last_failed_errno`):
  no fault — `asahi-idle` (`suspend_failed`) and `asahi-suspend-failed` (`ExecCondition`) ignore it.
  logind re-suspends every `HoldoffTimeoutSec` → `systemd-suspend.service` `OnFailure=asahi-suspend-failed.service`
  blocks `handle-lid-switch` until lid open; `asahi-idle` skips sleep while it's failed (one critical "Sleep disabled"
  notification per boot, else SoC silently awake). `asahi-idle wake` (after_sleep) keeps panel dark under a closed lid
  (outside clamshell; `asahi-clamshell open` relights). Stay-awake doesn't gate lid suspend.
- **Lock guard**: every lock path (hypridle `lock_cmd`, Super+Escape, launcher Lock, `asahi-clamshell` blocked-lid
  close — direct, not `loginctl lock-session`: works without hypridle) runs `asahi-lock` = hyprlock restart loop
  (flock, 30 tries, stderr → `~/.local/state/asahi/hyprlock.log`): exit 0 only on unlock / `finished` after `locked`;
  crash / `killall -9` → retry (else lockdead, no way in), `allow_session_lock_restore` retakes. Never auto-run
  `hl.clear_crashed_lockscreen()` (unlocks without password). hypridle `inhibit_sleep = 3` explicit (mode 2 needs
  `hyprlock` in `lock_cmd`); logind caps the wait at `InhibitDelayMaxSec`. Super+Escape must be a `locked` bind
  (others are dead on lockdead): fresh hyprlock once the guard is out of retries; asahi-lock exits if one runs (flock
  / `hyprlock_running`: this session's only, by `WAYLAND_DISPLAY`, never a nested preview's; asahi-idle, keyboard auto
  use it too). Nested Hyprland: `send_shortcut` drops modifiers, test with a plain key. TTY escape (`Fn+Ctrl+Alt+F3`):
  `pkill -f asahi-lock; killall hyprlock`.
- **Lock look**: row `[uptime/battery] [password] [clock/date]`; hostname on a top fade PNG (`lock-fade-top.png`,
  `write_hyprlock_conf`) with `halign = left` (hyprlock mis-centers images wider than the monitor; `rotate` shifts
  them). Sizes = framebuffer px (no scale): row must fit the Dell 2560. Label shadows don't help. Three input-fields
  share the input: thin ring; dots/text (hyprlock pads dots only `(h - dot)/2` — one field ran them under the `de`
  label; 13 dots max); thick caps ring (outline is static, drawn outside). Caps Lock = border only, no fill. Thick
  ring check/fail clear (else a failed password draws it without Caps: a fail replaces the caps color for
  `fail_timeout`; the thin ring shows `$lock_fail` / `$lock_check`). `$lock_caps` comes from `write_hyprlock_conf`;
  never assign it after the `source` lines (wallpaper color loses). Dots keep `$lock_fg` (`swap_font_color`, caps
  color `$lock_fg`) so the box never fills; their check/fail stay real (else "Checking…" / "Failed" blank).
  `asahi-lock-caps`: CAPS label opposite `de`, polls the kbd-capslock LED (hyprctl only without LED node). Never
  `$lock_fail` for the caps color. Touch ID hint: `asahi-lock-touchid` (`cmd[update:200]`, builtins only, fprintd
  asked ≤ 1/min, cached in `$XDG_RUNTIME_DIR`) = breathing 󰈷 above the pill (smoothstep alpha 30–100 %, 3.2 s) only
  while a finger is enrolled; placeholder "Password or Touch ID". Touch ID line: hyprlock shows nothing when the claim
  fails and maps Aurora's `verify-lockout` / `verify-password-required*` to "unknown status" → `asahi-lock` turns its
  `fprint:` log lines into `$XDG_RUNTIME_DIR/asahi-lock-touchid.note` (`<until epoch> <text>`, 0 = until
  `started verifying`), printed in the glyph's place: "No match" (2 s; the 4th = hyprlock's 3 retries used up → "Too many
  failed attempts"), lockout, "Enter password to enable Touch ID" (SEP password clock: 48 h without an unlock),
  "Touch ID unavailable" (claim / start failed, disconnected), "Not read · touch again" (retry statuses, 2 s). Span
  size must be absolute (`28pt`): hyprlock adds a scale-1 attribute over the label, so `size='40%'` rendered at 70.
  Finger on the sensor: the label passes `"$FPRINTPROMPT"`, `present_message = reading` → glyph solid at 84pt until
  the result (hyprlock sets it on fprintd's `finger-present`, logs nothing; unverified that Aurora's driver reports
  it — if not, nothing changes). Order: staying note > reading > timed note > breathing. Clamshell: libfprint hides
  the reader under a closed lid (`fprintd-list`: "No devices available") → no glyph; `asahi-touchid`, doctor and
  `asahi-debug` skip the finger check then (it read as "no finger enrolled" and tried to enrol).
  Preview without locking: nested `Hyprland -c <min.lua>` + `hyprctl output create headless` + hyprlock + grim; type
  via live `hl.dsp.send_shortcut` to `class:^(aquamarine)$` (never Enter: PAM). Whole `asahi-lock` nested: own
  `XDG_RUNTIME_DIR` (else it holds the live session's flock: a real lock is skipped) + absolute
  `WAYLAND_DISPLAY=/run/user/$UID/wayland-N`, a fake `qs` first in `PATH` (no live intro), end with `kill -USR1`.
- **Lid + DPMS**: Hyprland DPMS off = aquamarine output disable → sysfs `enabled` reads `disabled`; logind counts a
  closed lid docked only while an external reads `enabled` (re-checked every event-loop wakeup) → DPMS-blanked
  external in clamshell = laptop-only lid → suspend (no new `Lid closed.`; lockdead on open, hang on re-close).
  Guards: `asahi-clamshell` holds a `handle-lid-switch` block inhibitor while its flag lives;
  `asahi-hdmi-lid-inhibit.service` enabled at boot behind `ExecCondition` on HDMI/DP `status` (`--why` one token:
  `--why=HDMI connected` ran `connected`, no inhibitor). External may DPMS off in clamshell (HPD survives).
  `./install.sh asahi-logind` after touching the unit.
- **Clamshell / outputs**: never zero outputs — enable the external (`disabled = false`) before eDP-1 goes dark.
  `asahi-clamshell apply` (`config.reloaded` / `monitor.removed`) relights eDP if the external vanishes; 10 s later
  drops the flag (→ logind suspends) unless external back or lid open. `external_on` must not count Hyprland's enabled
  `FALLBACK` (kept a closed lid awake for hours). `hl.on("monitor.added"/"removed")` passes **userdata**: read
  `.name`; unknown name = no-op (`asahi-hdmi` no-arg = HDMI-A-1). Mirroring `HDMI-A-1` strands workspaces 1–5. Mirror
  eval **only** `mirror = <source>` (no `mode` / `position`); source must be enabled. Undo: Mirror pill, Extend,
  `Super+Ctrl+Alt+R`, Monitors pane 15 s auto-revert (unless Keep). Mode pill icons white + alpha (`panes/icons/`;
  `MultiEffect` tints one color); greyed laptop-only (Extend's reload blinks eDP-1), not for a plugged disabled
  external. Drag-arrange: **position-only** `hl.monitor` (partial rules merge with live mode/scale); revert
  re-evaluates old positions (reload re-modesets HDMI / DP). Keep → `asahi-hdmi save` →
  `~/.local/state/asahi/monitor-layout.json` (per sink desc + scales; `layout_fields` prefers it); Extend →
  `asahi-hdmi reset` + reload. No primary display; eDP-1 = mirror source + 0,0 anchor. USB-C `DP-n` are gated like
  HDMI-A-1 (`gated` list in `monitors.lua`; last named rule wins: reverse scan). Aurora's DTB gives each USB-C port its
  own output: DP-1..3 (expected Left Back / Left Front / Right — check per port), DP-4..6 = a dock's second stream;
  fairydust's DTB had one (DP-1, Left Front). `asahi-hdmi added`/`sync` enable after the settle (gen file per
  output); `place` re-derives position (desc rules assume eDP at its `monitors.lua` scale, 2 since 2026-11-09; the scripts'
  fallback is `edp_scale` in `lib/common.sh` — one value, `asahi_hdmi_test.sh` keeps both in step: a stale 4/3 brought
  eDP back at 4/3 after clamshell and put the Dell 491 px low) only on an eDP scale change (HDMI too, not
  mirrors). `config.reloaded` runs `asahi-hdmi sync <n>` for each gated connector the DT has. Hyprland 0.57 fires no
  `monitor.added` for an output its rule disables (`onConnect` returns first): `gated_plugs` starts `asahi-hdmi added` on
  `monitor.layout_changed` from the connector's sysfs disconnected → connected edge (a Monitors-pane disable keeps the
  cable in, stays off; test `asahi/hypr/monitors_test.lua`, run by `asahi_hdmi_test.sh`). `asahi-hdmi removed` writes
  `disabled = true`, re-arming the gate (the enable eval replaced the rule: same name). fairydust's crashed-DCP guard
  (`dcp_crashed`, journal parsing) is gone: on Aurora a crashed DCP ("DCP has crashed" / "a reboot is required")
  reads `disconnected` and the settle's sysfs check keeps it off; a clear-swap timeout only warns. Thunderbolt: DT
  machines get security `user` — DP and USB3 tunnels need no approval, a TB3 dock's USB / Ethernet (PCIe) does: `bolt`
  (dnf.sh) — new device once: `boltctl list`, `boltctl enroll --policy auto <uuid>` (boltd then authorizes it on every
  plug); sleep with a display on a TB tunnel is refused by the kernel.
- **Notch / fnmode**: `comp_asahi_system` writes `asahi-notch.conf` (`show_notch=1`) + `hid_apple fnmode=1`, then
  `dracut -f`; reboot. Live: `/sys/module/hid_apple/parameters/fnmode`.
- **Charge limit**: SMC is CHLS (90 reads back 90; CHWA would read 80): end 10–99 holds, start = end − 5 (start writes
  ignored), end < 100 sets the force-discharge bit (battctl: drains on AC; not seen). `asahi-charge-limit` clamps
  60–100; 100 = no limit, ≤ 99 = hold (also `asahi-battery`). One saved copy `/var/lib/asahi/charge-limit` (dir
  root:wheel 2775, temp + rename), written only after the SMC took it; boot applies it. Battery pane (Super+Ctrl+P,
  Reapply on mismatch) reads it on open / after change, never polls. SMC keeps it across unplug + s2idle: no AC-plug /
  resume re-apply unless a replug drops it. Never read the limit from UPower (1.91.5 reads sysfs once at start, hwdb
  75/80 when it reads 100) nor toggle its `EnableChargeThreshold` (off writes 0/100: drops ours until boot).
- **Keyboard / display brightness**: kbd `XF86Search` / `XF86LaunchA`, display `XF86MonBrightness*` (Shift = fine).
  Ambient light = Aurora's `aurora-kbd-light.service` (root; `asahi-system` unmasks + enables it; our old
  `asahi-brightness-keyboard-auto` is gone): brightest at ≤ 2 lux, on below 60, off above 120, 10–50 %; tunables in
  `/etc/default/aurora-kbd-light` (README `/usr/share/doc/aurora-kbd-light`). Any other writer wins (keys, idle-off holds
  until turned on; restoring the last auto level resumes auto); off with the lid closed / all displays off. Run by hand
  as a user it can't open evdev ("lid switch not found" is harmless). Idle off/restore and keys share
  `$XDG_RUNTIME_DIR/asahi-idle-brightness.lock` (`brightness_lock` in `lib/common.sh`); a key while idled off / dimmed
  steps from the saved level. hypridle listener (`ignore_inhibit`) fades keys off; `asahi-idle keys` relights
  (not on the lock's fake motion / under a closed lid).
- **Keybinding grammar**: Super = window / navigate (+A/V/X universal clipboard: select-all, terminal-aware paste,
  cut — `send_key_state` down/up split, explicit mods, no window target so layer surfaces get it; Super+C stays Center);
  Super+B = next wallpaper; +Shift = inverse (move vs focus); +Alt = variant (focus→resize,
  capture→record). `Super+Alt+HJKL` moves the **shared split border** — label by direction, never grow/shrink.
  `Super+Ctrl+<letter>` = panel (A audio, B bluetooth, C calendar, D display, W network, P power, R backup, S
  screenshot gallery, T activity, I stay-awake, E emoji, V clipboard, M media, H hardware; night light is menu-only;
  keybinding overview = Super+K **held**, his pick). `Super+Ctrl+Alt`:
  R reload Hyprland, W/P/I restart Quickshell / hyprpaper / hypridle, S suspend, Z magnifier reset.
  `Super+Ctrl+plus/minus` = display scale; `Super+Ctrl+Z` / `+Shift+Z` / `+Alt+Z` = magnifier in / out / reset
  (`hl.config { cursor = { zoom_factor } }`, not `hyprctl keyword`). Panels: `quick()` in `bindings.lua`
  (`quickActions` in `LauncherWindow.qml`); same combo again closes (`openQuick`/`openCategory`). Esc peels one layer
  (Quick pane → home → close); shortcut-opened → closes (`openedByShortcut`). Workspaces: Super+N go, Super+Ctrl+N
  move, Super+Alt+N send w/o following, Super+Y back-and-forth. Super+Alt+F = fullscreen in tile (`fullscreen_state`
  client 2); Super+Alt+arrows join neighbour group; Alt+Tab cycles. Lock / media / lid binds in `submap_universal`
  (writing-tools submap's catchall swallowed them). Super+N/S free. **Every bind needs a `desc`**
  (`Data.parseHyprBinds` drops descless ones; `data_test.js`) — except lid switches + writing submap. `code:NN` needs
  `bindCombo` `codeNames`; labels are **de(mac_nodeadkeys)** (`code:34/35` = `ü`/`+`, not `[]`).
- **Monitor direction binds**: `Super+Ctrl+arrows` and `Super+Shift+Ctrl+HJKL` must `hl.get_monitor(dir)` first (nil
  laptop-only). Generated in `bindings.lua`.
- **Clipboard secrets**: `asahi-cliphist` watchers run `wl-paste --watch <self> store` so `store_unless_sensitive`
  drops `x-kde-passwordManagerHint` (`wl-copy --sensitive`; check with `asahi-cliphist types`). Every read under
  `timeout` (a never-closed pipe hung watcher + history). `start_watcher` pkills the old `--watch cliphist store`
  form. Proton Pass (extensions) sets no hint: password-shaped copies with Firefox focused are dropped; a 0-byte copy
  (auto-clear `""`) deletes the newest entry only if the previous copy was a *stored* browser copy
  (`$XDG_RUNTIME_DIR/asahi-cliphist/last-store`). `asahi-writing-tools` touches `$XDG_RUNTIME_DIR/asahi-cliphist/skip`
  before its Ctrl+C: store skips while < 2 s old. Tests: scratch `CLIPHIST_DB_PATH` + runtime dir, fake
  `wl-paste`/`hyprctl`.
- **Screenshots**: slurp + grim, no hyprpicker freeze. Super+F10/F11/F12 (window / smart / display),
  Super+mute/vol-/vol+; own keys only, no macOS Cmd+Shift+3/4/5 copies. Clipboard only
  (`asahi-cmd-screenshot <mode> --clip`, nothing in ~/screenshots): Super+Ctrl+Shift+F10/F11/F12 + top row, gallery
  "Copy". OCR/QR Super+Shift/Ctrl+F11; color Super+Shift+F12. Record: Super+Alt+F11 region, Super+Alt+F12 display,
  Super+Alt+Shift+F12 + webcam (`asahi-webcam`: Aurora's denoised PipeWire camera via `pw-v4l2` +
  `PIPEWIRE_V4L2_TARGET` = its `object.serial`, shareable with a browser call; raw `/dev/videoN` without
  `aurora-camera-denoise` (user service); `/dev/video0` = AVD decoder, skipped; Super+Alt+ü/+ resize = `code:34/35`).
  Annotate (tile pencil / preview pill) = `asahi-screenshot-annotate` = `swappy -f shot` (satty not in Fedora; class `swappy` floats). Only Save
  (Ctrl+S / button) counts: `asahi/swappy/config` → `~/screenshots/annotated-*.png` + `early_exit`; script moves it
  over the shot if `magick compare -metric AE` sees changes (else drops it), re-copies. No `-o` (swappy writes it on
  Esc / q / close too). Thumbs regenerate when older (`-nt`); tile + preview Images `cache: false` (same path).
  `screenshot` toasts (also OCR / QR) show silently under Do Not Disturb. Test: `asahi/bin/asahi_webcam_test.sh`.
- **Browser screenshare**: Chromium needs `CHROMIUM_USER_FLAGS=--enable-features=WebRTCPipeWireCapturer` in
  `env.lua` + `environment.d/90-asahi.conf` (Fedora ignores `chromium-flags.conf`). No Google Chrome; Fedora ships
  `hyprland-share-picker`. xdph never reconnects to PipeWire (after a restart `Start` spins, shares hang) — drop-in
  `xdg-desktop-portal-hyprland.service.d/10-asahi-pipewire.conf` (`PartOf=pipewire.service`).
- **asahi-debug**: Aurora / Fedora Asahi health (`asahi/bin/asahi-debug [--json]`; also root on LUKS, no disk key / header
  copy on `/boot`, xART guard on with SEP `matching` not `blocked` (`unverified` = steady state under the guard: PASS),
  no Thunderbolt device awaiting bolt approval; dnf, `wpa_supplicant`, not
  pacman/iwd/SDDM; Wi-Fi radio off on purpose = PASS). Test: `asahi/bin/asahi_debug_test.sh`. Not in `make doctor`; must not flag
  Hyprland on generic Linux.
- **Night light**: menu-only (Launcher > Actions → `asahi-nightlight`, hyprsunset); on = `hyprsunset.conf`, off =
  `hyprctl hyprsunset identity`. Identity profile so autostart tints nothing; autostart drops stale `nightlight.json`
  (chip showed on, no tint).
- **Bar notch**: cutout is a hole (`BarModel.notchRegionInset`), not a spacer; height from geometry (3024x1964 →
  **74**), width = real cutout; overflow clipped at the wall. Right side: bell, usage ring, mic + volume, network, BT,
  battery, clock always; the rest is granted while it fits, whole or not at all (`BarModel.rightGrants` →
  `BarHost.grants`, `bar_model_test.js`): REC → timer → stay awake on → night light → tray's one icon / `+N` pill →
  idle cup → updates box → more tray icons → words (usage countdown → VPN name → VPN uptime → network name; VPN name+
  only without notch; never past the first misfit; external gets all). A width fed to the budget is what the part
  costs shown or not, from `Text` / metrics: a hidden layout keeps its last width (the hidden bell twin counted no
  badge: 22 px too much room, the tray icon was cut at the bell). Left side the same idea: icons on every workspace
  only while the block fits `WorkspacesBlock.maxWidth` (10 workspaces pushed the CPU chip under the wall), media chip
  → thumb only under 104 px → hidden. Row `add` + `move`: `chipMove` also animates opacity to 1 (a chip displaced
  while fading in stayed at 0: an empty slot). Clock always weekday + date, same size/colour.
  Usage chip: fixed width, text centred (text-following width shifted the bar; right-aligned hit mic). Glyphs:
  `barFontGlyph` / `barFontGlyphTall` (tall ones), same ink. Right-cluster additions eat the notch budget. Bar =
  `max(Style.barHeight 40, notch)` (40 fits two-line media chip). Media chip gets the left leftover (`maxChipWidth`);
  notched panel: title runs to the cutout wall. Bell (`Notifications.qml`): notched panel = cutout's right wall
  (`notifNotch`), else first right chip (`notifBlock`); in `rightBase`; clock rightmost (bell at left starved media).
  No trays ("strip, spaced"): groups by spacing, chips touch inside — right: `[tray · status]` `[usage]`
  `[mic · volume]` `[Wi-Fi · BT · battery]` `[clock]`; `rightBase` excludes tray + grants. SysChip avg
  SMC temp (`tempAvg`, macsmc_hwmon `temp*_input`; no SoC die °C on Asahi) only while it fits (`showTemp`: media
  keeps ≥ 200 px; from `baseWidth` / `naturalWidth`, never capped widths). Vol / mic: click mute, wheel step,
  right-click Media pane.
- **Workspaces**: `monitors.lua` pins 1–5 to external, 6–10 to eDP-1 (clamshell: 1–5); 1 / 6 `default` + `persistent`
  so `Monitor:set_workspace` (existing only) can move a monitor off a stray id (fresh external comes up on 11). No
  scratchpad / special workspaces. `WorkspacesBlock`: own monitor only (`Hyprland.monitorFor`); active = sliding
  capsule with state glyph (`activeToplevel`, else lowest `focusHistoryID`). Widths computed, not measured (capsule,
  items, `chipMove` share one curve); `implicitWidth` = final width. Click active = icons on all workspaces (flag
  `~/.local/state/asahi/bar-workspace-icons`). `ScriptModel`s keep items alive (JS-array Repeater rebuilds, kills
  animations). `refreshWorkspaceIcons` calls `Hyprland.refreshMonitors()` (Quickshell applies `workspace` before
  `focusedmon`: stale `activeWorkspace`).
- **Bar tray**: ≤ 3 inline while they fit (`BarHost.trayInline`, from `rightGrants`), rest `+N` → `TrayPanel.qml`.
  Attention = `Status.NeedsAttention` (`SystemTrayItem.NeedsAttention` / `SystemTrayStatus` undefined). Popups need
  `screen:` + `exclusionMode: ExclusionMode.Ignore`. One bar popup at a time (`BarHost.openPanel`; launcher, calendar,
  notification sheet clear it); keybind / IPC opens reach the focused bar's `requestPanel` via shell signals — no
  second flag, no counters (later bars replayed them). Every bar popup (calendar, RecordPanel too) closes on Esc /
  click-outside: `HyprlandFocusGrab` whitelists popup **and bar window** (else the opening click is outside);
  `QsWindow.window` needs `import Quickshell` (else tray menus silently break); Items are dropped. Esc =
  `Qt.ApplicationShortcut` (grab may focus the bar). App menus: TrayPanel opens via `QsMenuAnchor`, drops its grab
  until `closed`. `HyprlandFocusGrab` dies on `focusable: false`. Attention dot static (pulse = per-frame redraw).
  Menu positions are window coords (`mapToItem(null, …)`).
- **Bar = click to act, event-driven**: left-cluster chips slide neighbours (Row `move`/`add`, off first second);
  right cluster only fades in (`add`; `move` made the clock side jump). Hover = `HoverTint`; tooltips only on tray
  icons (+ BT battery list); night-light chip only while on. REC dot blinks on the elapsed tick (no animation). Mic
  orange while recorded (`PwNodeLinkTracker`). Sources bind, not poll: Pipewire (`AudioChip` + `PwObjectTracker`),
  BlueZ, `UPower.displayDevice`, `nmcli monitor` (+30 s signal poll), in-process `FileView`; `asahi-cpu` / `-memory`
  only while SysPanel open; stay-awake / night-light / timer files watched (dir watch sees create/delete). Long-lived
  children get `setpriv --pdeathsig TERM` (SIGTERMed qs orphans them). Chip clicks → `barHost.quickRequested(key)` →
  shell.qml (no `qs ipc` per click). Wheel accumulates to 120, horizontal ignored. One cava (`services/Cava.qml`,
  `hold()`); hidden bound items still repaint, so visualizers exist only while shown. All bars bind one
  `services/BarData.qml` (stats, network, updates, `hyprctl clients`; no per-bar polling); BarHost re-exports it.
- **Media chip / popup**: title slides only on hover (no marquee). Click = `MediaPanel` (serpantinum `MusicPopup`,
  checked against source), middle = play/pause, right = next. Card = `MediaCard.qml`, shared with launcher Media pane
  (`fontScale`); imports `WavySeekBar` qualified (`import "." as Components`; via the pane's Loader bare = "not a
  type"). `Players.pinned` = source pill cycle. Length = `Players.length` (0 = `WavySeekBar.indeterminate`). Chromium
  sends INT64_MAX µs for Infinity; Apple Music web (gapless MSE) the growing buffered end, position from album start.
  So: < 1e6 s for all; Chromium's (`.chromium.` bus name) only once held still 12 s of playback (`lengthHeld`) and the
  clock restarted at the track change (`clockRanOn`); others at once. Firefox usually lacks length → placeholder. Seek
  holds target 1 s (no jump back). Items stay `visible` in a hidden PopupWindow: gate per-frame work on the window
  (`WavySeekBar.live: root.visible`; else repainted while closed, +1.4 % CPU). IPC `media panel` → focused screen
  (`mediaPanelRequested` → `BarHost.requestPanel`). Rounded content needs `ClippingRectangle` (`clip` is rectangular).
- **Apple Music app**: `asahi-apple-music` = Chromium `--app`, own profile (→ own MPRIS player, named via
  `/proc/<pid>/cmdline`, space-joined). Widevine: copies main profile's CDM hint (else previews only).
  `extension/clock.js` feeds MusicKit's per-track clock to Media Session. Linked into `~/.local/bin` (session PATH
  lacks `asahi/bin`). Shuffle / love / library bridge dropped (too much code).
- **Launcher quick panes**: one file each in `quickshell/remix/modules/launcher/panes/`; `LauncherWindow.qml` does
  `Panes.XPane { root: launcherSelf }` (`root` in a pane = that property). Shared M3 widgets in `modules/menu` take
  `fontScale` (`MenuSwitch` fixed; `component Pill: Menu.MenuPill { fontScale: root.uiFontScale }`). Hover =
  `m3stateHover` layer (`Qt.lighter` invisible on light fills). A visible Quick tile **must have a pane**
  (`quickPaneKey` = tile's `mode || key`); paneless actions go in `quickDeckHidden` (`wallpaper_carousel_test.js`
  derives it). `openQuick` sets `quickStartIndex` before entering Quick (else Hub builds first). In Quick hidden
  `resultsList` must not write `selectedIndex` (its reset wrapped deck index 8+). Root typing also finds
  `quickActions` (below apps on equal score). Pane `handleEscape()` is asked first. Tab in Quick steps the rail; pane
  text fields swallow Tab (leaked a Wi-Fi passphrase into search). Close keeps the pane alive (next open destroys it):
  Timers, `SystemClock`, looping animations gate on `root.shouldShow`; countdowns (Monitors revert) and BT
  stop-retries must not. Must-finish actions (Wi-Fi band, BT pair/forget):
  `systemd-run --user --wait --quiet --collect` (exit code passes through); `MonitorsPane` reverts on destruction.
  Failed connect deletes only a profile it just created with a typed passphrase; passphrase via nmcli stdin (`--ask`),
  never argv. OWE (`OWE` / `OWE-TM`) needs no password.
- **Calculator** (`=` in launcher): `calc_history.js`, own parser, no `eval` (a pasted expression reached launcher
  ids); radians, `30°`; `,` args, `.` decimals; ASCII constants only (`pi`, not `π`); `ans` = last copied result,
  leading `*`/`/`/`^` continues it. History in `~/.local/state/asahi/calc-history.json`. Legend = `CalcHist.LEGEND`.
- **Recorder**: Super+Alt+R toggles `RecordPanel`; REC chip only while recording (click = panel, right-click = stop).
  `Recorder` singleton runs `asahi-cmd-record status --json` at start, on the script's `ipc call recording refresh`,
  1 s while recording; idle nothing polls. Webcam takes record default source; screen takes default sink's monitor
  (wf-recorder: one device). No pause (wf-recorder exits on SIGUSR1). Stop = SIGINT, SIGKILL only after 15 s (MP4
  index written last). IPC: `qs -c remix ipc call recording panel`.
- **Packages**: `PkgManager.qml` over `asahi-pkg` (dnf5 JSON). Update checks run `dnf check-update` **without**
  `--cacheonly` (as user it read days-old `~/.cache/libdnf5`); offline (exit 1) → `--cacheonly`. Rows under
  "Obsoleting packages" are not updates. New query first stops a busy one (`running = true` on a busy Process delivers
  old rows). quickshell excluded on lionheartp copr (`dnf.sh` setopt; Upgrade all installed its build). Install /
  remove / upgrade: Ghostty via `asahi-launch-tui`, `ASAHI_TUI_WAIT=1` (`--wait-after-command`: result stays
  readable). Crashing query still prints `{error, packages: []}` (EXIT trap). Test: `asahi/bin/asahi_pkg_test.sh`.
  `dnf.sh` brings node + luac (for `make test-asahi`). Grok Bot = Cursor's AppImage feed (`grokbot.sh`; icons linked
  into `~/.local/share/icons` for `BarHost`).
- **Wallpaper**: one picker, `WallpaperManager` (Super+Shift+W); `ipc: "wallpaper"` + `wallpaper: true` in
  `quickDeckHidden` (not a Quick tile; search finds it). `WallpaperCarousel`: ←/→, Ctrl+h/l, wheel select; ⏎ applies,
  Esc restores. Live preview **opt-in** (`WallpaperService.liveMode`, default off; Shift / Shift+←/→ / Live chip);
  ignore bare Shift in the search field. Live previews never reach hyprpaper (picker + fade overlay cover it); applies
  = one queued `apply`. Wheel accumulates to 120. Colors: cached thumbs → `wallpaper_colors.js`; filter
  `WallpaperService.arranged(query)`. Test: `wallpaper_colors_test.js`.
- **Background intros** (omarchy): `modules/wallpaper/WallpaperIntro.qml` plays `<wallpaper dir>/intros/<stem>.mp4`
  once on every output (one `MediaPlayer` per output; Bottom layer `asahi-wall-intro`, above hyprpaper, below windows;
  muted; span on = each output its slice of one canvas, `wallpaper_intro_geom.js`, node-tested against
  `asahi-wallpaper-span` crops), then fades out over the last 420 ms onto the still (hyprpaper keeps the still
  throughout). Until playback position leaves 0 its window shows a **cover**: the clip's first frame
  (`~/.cache/asahi/wallpaper-intro/<stem>.png`, extracted on scan; a local `Image`, decoded synchronously in `arm()`, so
  the window's first buffer has it). Why: nothing presents while hyprlock holds the session, unlock shows what was on
  screen when the lock engaged; the cover makes that frame 0 whatever the decoder holds. `play` runs from
  `onMediaStatusChanged` (`kick`), never from a `ready` binding: that binding looped, Qt dropped it, and `pause()`
  on the new source held the cover on frame 0 (2026-11-09, switching wallpapers). The kick is deferred
  (`Qt.callLater`): `setSource()` first stops the old clip (Loaded + Stopped at 0, `go` still true), a kick inside it
  `play()`s the clip being replaced, `playbackState` stays Playing and the next clip never starts — frame 0 held until
  the failsafe on every wallpaper change after a finished intro or during one (2026-11-10; offscreen harness:
  `qml` + `QT_QPA_PLATFORM=offscreen` around the verbatim player block; unlock was fine, the hold's `pause()` resyncs). The flash he saw (2026-11-09)
  was hyprlock's grey fade-out + the late `play` (below); a stale-buffer flash did not reproduce nested.
  `asahi-lock`: `wallpaperIntro arm` → polls `ready` (each output swapped the cover twice:
  `cover.Window.window` `frameSwapped`; ≤ ~0.4 s; each call under `timeout 1`: a hung qs
  must not stop the lock) → hyprlock → `play` on hyprlock's `Unlocked, exiting!` line, again at its exit (no-op: once per
  arm, `played`); go after `unlockDelayMs` 400. hyprlock lingers ~2–3 s after a Touch ID unlock (its pending password
  PAM attempt fails, then the failure delay): `play` at exit alone started the video ~3.3 s after unlock. hyprlock
  `fadeOut` 0: the fade dims the lock image to grey for 0.5 s before the desktop pops in (read as a jump to the darker
  last frame and back). Nested A/B 2026-11-09 (wf-recorder per frame): lock → frame 0 directly, motion at +0.63 s.
  `FrameAnimation` is no "window rendered" signal (the animation driver falls back to a timer). 15 s failsafe ends a
  stalled clip (a held arm has none: `asahi-lock`'s EXIT trap calls `play` on every exit — unlock, out of retries,
  the TTY escape's pkill). `ready` live 2026-11-10: false, false, true ~220 ms after `arm` (the cover png loads
  synchronously; no cover = no wait); a static cover swaps once per `update()`, so `onFrameSwapped` asks for the second
  (a re-arm of a held cover stayed not ready for all 10 polls).
  qs log: `intro: arm` / `play` / `video on <output>`. IPC via `qs -c remix ipc --any-display`
  (Hyprland-spawned callers lack the shell's `QT_QPA_PLATFORM`). Triggers: login once per boot
  (`$XDG_RUNTIME_DIR/asahi-wallpaper-intro-boot`), `WallpaperService.wallpaperSet` (picker, Super+B), every unlock.
  hyprlock's background = `lock-screen` link → the clip's first frame (`WallpaperService.linkLockScreen`; the still
  without a clip), so unlock plays forward (eyes open). **Animated wallpapers only** (2026-11-09): `~/Pictures/wallpaper`
  = omarchy's theme intros (minus lumon, retro-82: 16)' end stills (`<theme>-<bg>`) + `intros/<theme>-<stem>.mp4`,
  fetched by `comp_asahi_wallpapers`; the old still collection (mylinuxforwork checkout) was moved once to
  `~/Pictures/wallpaper-backup`. Picker centre window loops its clip muted only while the picker is shown
  (`WallpaperCarousel` `Video`, `playing`: hidden, it kept decoding at ~50 % of a core; `WallpaperService.introClip`).
  Decode is software (QtMultimedia → ffmpeg-free: H.264 via OpenH264, VP9, AV1);
  ffmpeg-free cannot *encode* H.264 (`libopenh264` can). No clip = nothing happens. qs hot reload missed a replaced
  file once (2026-11-09): restart qs (Super+Ctrl+Alt+W) when a change does not show.
- **Wallpaper span** (idea: omarchy-wallpaper-cutter): `asahi-wallpaper-span` cuts the wallpaper across the live
  layout (logical px; slices in `~/.cache/asahi/wallpaper-span/`, only live set kept). Bezel `gap`: one value, all
  seams. EDID mm unused (LG reports 700x400). hyprpaper keeps per-monitor entries over the `,path` wildcard — every set
  (`apply` / `sync`) names each output; all `WallpaperService` desktop sets go through the script. `sync` (no-op, no
  state write if already shown) runs on `WallpaperService.screenLayout` changes, shell start, after Super+Ctrl+Alt+P
  (hyprpaper starts on `~/.local/state/asahi/lock-wallpaper`; no slideshow). One output: no cut, `outputs` cleared.
  Slices written to `.tmp`, renamed. Span switch in Monitors pane. Picker previews stay uncut. Test:
  `asahi/bin/asahi_wallpaper_span_test.py`.
- **Autotheme**: Hyprland has no portal Settings — `portals.conf` pins Settings to gtk. Flavours
  `source content vibrant calm mono` (`FLAVORS` = source of truth; saturation = fraction of gamut room, never a
  multiplier). ANSI / named colors stay in their hue family (`HUES`, `_family_hue`; red/orange lean less: critical vs
  warning); text ladders WCAG (subtext0 ≥ 4.5:1 on base, text on accent = crust). Bare run keeps saved flavour
  (colors.json `variant`), prefers `quickshell/wallpaper.conf`; runs hold `asahi-theme/.lock`. Writes
  `~/.local/state/asahi-theme/`. GTK ini is a real file, not a symlink. Unset portal `0` = light. Live: Ghostty
  `reload-config`, Quickshell `FileView`, Hyprland borders, btop SIGUSR2, Firefox. **GTK3 never repaints live** — do
  not add watchers. Tests: `asahi/theme/tests/` (`test_palette.py`, `test_apply.py`), `asahi/theme/smoke_test.sh`
  (no arg = saved state, rewrites live state unchanged; not in `make test-asahi`).
- **Flatpak GL**: `aurora-flatpak-gl` (dnf.sh, Aurora only) = system `GL.aurora`; it serves `--user` Flatpaks too
  (Flathub's GL.default has no `aurora_dri.so`). mpv `hwdec=vaapi-copy` (AVD VA-API; ffmpeg-free decodes VP9 only;
  `libva-v4l2-request-avd` + `avd-fw`: `aurora-platform(-core)` requires them, dnf.sh names them too; without the driver
  mpv falls back to software).
- **Firefox (Flathub flatpak)**: addon signing enforced (`MOZ_REQUIRE_SIGNING`), so live theme = signed AMO
  **CaelestiaFox** (`caelestiafox@caelestia.org`) + native host `caelestiafox` = `asahi-firefox-theme` (streams
  `firefox.json` from `write_firefox_scheme`; ignore Firefox's args). Sandbox can't run host scripts:
  `xdg-native-messaging-proxy` (dnf) + `flatpak override --talk-name=org.freedesktop.NativeMessagingProxy`; host
  manifest in `~/.config/mozilla/native-messaging-hosts/`. `asahi/firefox/user.js` **symlinked** into the profile
  (`~/.var/app/org.mozilla.firefox/config/mozilla/firefox/`; `flatpak override --filesystem=$DOTFILES/asahi/firefox:ro`,
  sandbox sees nothing else of `$DOTFILES`); sets `widget.use-xdg-desktop-portal.native-messaging-proxy = 1`.
  `BROWSER=org.mozilla.firefox` (needs `~/.local/share/flatpak/exports/bin` on PATH). Test:
  `asahi/bin/asahi_firefox_theme_test.sh`.
- **Spell check = English + German everywhere**: flatpak `languages en;de` (`dnf.sh`; old installs: `flatpak update` the
  `.Locale` refs), else sandbox `de_DE.dic` dangles. Host `hunspell-de` (Thunderbird links `/usr/share/hunspell`,
  Sonnet). Firefox + Thunderbird `spellchecker.dictionary` `en-US,de-DE` (user.js; per-site picks in
  `content-prefs.sqlite`). nvim: one language, `<Space>ts` cycles en_us → de → off.
- **Firefox wake locks**: flatpak override `MOZ_WAKE_LOCK_TYPE=WaylandIdleInhibit` (`comp_asahi_desktop`). Default
  portal path (gtk → `org.freedesktop.ScreenSaver.Inhibit`) stays open without media: hypridle skips every listener
  (idle.log silent). Wayland inhibitors die with the window (`inhibitingIdle` in `hyprctl clients`). Find D-Bus ones:
  `busctl --user tree org.freedesktop.impl.portal.desktop.gtk` (`request/<sender>/t/*`; owner
  `busctl --user status :1.N`), release `busctl --user call … org.freedesktop.impl.portal.Request Close`. Verify:
  `MOZ_LOG=LinuxWakeLock:5,sync`.
- **sshd**: Fedora enables it; disable + mask `sshd.service` + `sshd.socket` + systemd-ssh-generator's
  `sshd-unix-local.socket` (`/run/ssh-unix-local/socket` is 0666), drop firewalld's `ssh` service (`asahi-sshd`).
  Re-check after a release upgrade. Kernel hardening sysctls (`asahi/sysctl.d/99-asahi-hardening.conf`): Fedora's
  defaults the Aurora kernel lacks (unprivileged BPF off, `legacy_tiocsti` 0). AsahiLocker's `luks-fetch-cache.timer`
  (root `luksDump` of every LUKS disk, USB too, for fastfetch) is disabled by `asahi-system`.
- **Notification images**: `localImage()` only `image://icon/`/`file:`/`/…`; never `image://qsimage/` (history outlives
  the object: empty box; app icon instead), never `?path=` (icon provider reads that file), never `/proc`, `/sys`,
  `/dev` — also as `image://icon//…` and as an absolute app icon (QIcon opens a path as a file) (resolve `..` /
  %-escapes first; a FIFO froze the shell; one elsewhere, e.g. `/tmp`, still blocks: no stat from QML, local processes
  only). `appLabel()`: desktop entry Name fallback (Firefox / Ghostty send none). `stripMarkup` drops known tags only
  (`Jane <jane@…>`, `<a.smith@…>` are text: a tag name ends at a space, `/` or `>`); summary `Text.PlainText`. Body
  markup + hyperlinks are on: the body is `NotificationModel.richBody` StyledText (b/i/u/s, br, `<a href>` passing
  `safeHttpUrl`, which also refuses loopback names: `*.localhost`, `localhost.localdomain`; no img; unknown tags stay
  text, same tag-name rule: `<s.mueller@…>` is no `<s>`; tags read from the raw body, entities decoded only in text /
  href, so an escaped `&lt;b&gt;` stays text; lookups by own key: `<constructor>`; ports of omarchy 4.5
  Markup/Security.js; test `notification_model_test.js`). A body without a rich copy (history with codes, old entries)
  is plain already: `textRich` escapes it, never parses it again (that turned an escaped `&lt;b&gt;` into bold).
- **Toasts** (omarchy 4.5 decks): one deck per sender (`group` = `appLabel` lowercased), collapsed = front card + 2
  slivers (10 px peek, 3.5 % shrink, back cards at the front card's height, content hidden, also while leaving); hover
  opens the deck under the pointer (imperative `HoverHandler`: a binding looped through the layout), pauses every
  countdown (one shared 250 ms `toastTick`, remainders kept) and holds arrivals in `held` (30 s cap); a lower deck opens
  only if it stays under the pointer (opening it collapses the one above); an open deck that lost its last card closes
  next tick (`dropStaleDeck`, deferred: openDeck feeds deckLayout). Max 4 decks, 5 cards a deck (a spread deck must fit
  the laptop; rest expire). Top-right under the bar: anchors top+bottom, fixed width, `mask: Region { item: deckArea }`
  (the surface never resizes; its top edge is the bar floor, so cards drop out from under the bar), `ExclusionMode.Normal`
  + zone 0; pinned to the monitor focused at the first card until empty. Layer popups draw above the overlay layer: a
  right bar popup (`setPopupSide`) sends them top-left; hidden, countdowns paused, while the sheet is open (it masks
  codes: the code toast is back to copy once it closes); opening it clears `openDeck` (the unmapped window sends no
  hover-leave: held cards waited). Repeater over `ScriptModel { objectProp: "key" }` (entry swaps keep delegates), y
  from `Model.layout` + Behaviors; a delegate's Behaviors already animate in `onCompleted`: landing spot as the initial
  value, `settled` next tick (`Qt.callLater`), height Behavior off until then (76 px guess); each closing card stays
  220–320 ms (a 100 ms poll) from its own start (`leaving` holds the time: one restarted timer never fired under a
  flood) and rises 24 px. Animate `fade`, not `opacity` (swipe binds it).
  Bar popups + toasts need `Style.popupBorder` (vanished on dark windows). No pulse on critical cards.
- **Notification objects**: shown and held toasts are tracked (`refs[key]`, a plain map): `closed` removes the card; a
  replaces_id update changes the object in place, one signal per property (summary, body, actions, urgency, image,
  timeout): rebuilt once next tick (`updating`). Our close calls `expire()` (timeout, overflow, a superseded copy) /
  `dismiss()` (you); `release` drops the ref first, so the echoed `closed` is ignored. `keepOnReload: false` (a reload
  re-emitted them: duplicate history). Buttons on live toasts only: codes (`detectCodes`, omarchy Detect.js; a keyword
  naming a 1–3 digit number, "exit code 2", opens no window; `#4821` is no code) → `wl-copy --sensitive` on stdin,
  cleared after 60 s if still there; sender actions minus `default` and settings; labels are sender text (`MenuPill` is
  PlainText: AutoText fetched an `<img>`), cut at 24 chars (Flow cannot wrap one wide pill). No "Open" pill (rejected:
  an invented label for an unlabelled action, ahead of the real ones): a click on a live card runs the sender's
  `default` action (spec: the click), then raises the sender: Quickshell sends no xdg-activation token, so the app's own
  present() fails (Ghostty: refused by its `focus_on_activate = false`, only `urgent`; Firefox: no token to ask with) —
  focus the window that turns urgent within 500 ms if its appId (`Hyprland.toplevels` `wayland.appId`) is the sender's,
  else the most recent window of the class (the rawEvent Connections only listens while a raise waits). Without a
  `default` (and on history cards) a click focuses the sender's most recent window by class (never-focused
  `focusHistoryID` -1 last). A toast goes either way; no other action runs from a click. History masks codes
  (`maskCodes`: the code tokens only, a false hit loses a number, not the message; no image). A capitalised "Code"
  after a possessive / article / login word ("Your Code:", "Ihr Code lautet") is no product name ("VS Code"); German
  compounds (Bestätigungs-, Sicherheits-, Anmeldecode …) and TAN (capitals: "Mr Tan" is a name) open a window. Under
  Do Not Disturb a card toasts, silently, only with an unambiguous login phrase (`isLoginCode`: verification, OTP, 2FA,
  login code, "your code" / "Ihr Code" only right before the code, German compounds …; not "confirm" / "(your) code
  review"), like `screenshot` and one-at-a-time "Asahi Battery". An identical repeat of a live card = ×N (one history
  entry, fresh timer; the card comes to the front, in place while a deck is open); repeats within 100 ms dropped,
  unless the sender closed the first. `expire` is ms (raw `notify-send -t`). A sender with `-A` must not pass `-t`:
  notify-send stops listening at its own timeout while the card pauses on hover (`asahi-cmd-screenshot` Open/Annotate
  waits under `setsid -f`).
- **Notification sheet**: history `~/.local/state/asahi/notifications.json` (0600, non-atomic writes keep the mode),
  never written on load; holds Do Not Disturb (a QML save reloads qs). Trash = two clicks within 3 s (stray click wiped
  all). Super+comma `act` (click / one button / dismiss); Super+Alt+comma `dismissOne`; Super+Shift+comma
  `dismissAll` also clears the saved list (so does IPC `clear`).
  Sheet and bar popups close each other; sheet focus grab arms 200 ms late (an unmapping popup clears it); the bell click
  ending the grab is ignored; the launcher closes the sheet (grab kept its keys). `historyGroups` built only while open
  (day labels fresh past midnight). shell.qml id is `notifCenter` — `notificationCenter: notificationCenter` self-binds
  to null.
- **bash 5.3 / trailing `&&`**: EXIT trap or function ending in `[[ -n $x ]] && …` returns 1 when `$x` is empty;
  `set -e` then kills the script (`asahi-network` lost JSON). End traps on `|| true` / `if`; optional tail lines in `if`
  blocks. Interactive zsh helpers without `set -e` are fine.
- **Apple HID race**: dockchannel-hid binds `hid-generic` first; `asahi/dracut.conf.d/10-asahi-hid.conf` force-loads
  `hid_apple` + `hid_magicmouse` (a module on Aurora, built in on Fedora Asahi). Verify `/sys/bus/hid/drivers/` +
  `readlink -f /sys/bus/hid/devices/*/driver`. Live trackpad recovery:
  `sudo udevadm trigger --action=add /dev/input/eventN` (input node, not drm).
- **Volume keys**: `asahi-media-control output-volume raise|lower|+1|-1` (and Media pane slider) unmutes the sink **only
  if muted** (`unmute_if_muted`; unconditional `set-mute 0` clicked the speakers); never unmutes the mic. Launcher
  Logout / Restart / Shutdown: `confirm: true` (Data.js), second Enter within 3 s runs.
- **Audio**: Aurora ships the stack (`aurora-audio`, keeps the `/usr/share/asahi-audio` paths) — don't port omarchy's
  Apple audio.sh. RT check is the **thread**: `ps -eLo comm,rtprio,cls | grep data-loop` → `20 RR`. Mic
  `effect_output.j414-mic` is MONO since aurora-audio 4.1-5 (old asahi-audio: 1ch `AUX0`, stereo recorders left only;
  our relabel filter `asahi-mic.conf` / `asahi_mic` is gone, the installer drops its link). Never override the audio
  package's node scripts (a `software-dsp.lua` overlay hung WirePlumber). The unplugged "Built-in Audio Headphones"
  sink is always listed (never default: no available route). speakersafetyd restarts "hot" (Aurora
  `50-aurora-warm-restart.conf`: attenuated until its model cools). 96 kHz playback can lock speakersafetyd
  (`Speaker volumes locked`): `sudo systemctl reset-failed speakersafetyd && sudo systemctl start speakersafetyd`.
- **Trackpad**: `tap_to_click = true`. No touchpad toggle. Pointer feel = `hl.device` curve on `apple-mtp-multi-touch`
  in `input.lua` (libinput ignores `sensitivity` under a custom profile). `hyprctl reload` does **not** reset a device —
  keep the explicit rule, else a bad `hyprctl eval 'hl.device({…})'` survives till reboot; `hl.device` checks names, not
  values. Ghostty `scroll_touchpad = 0.2` rule in `rules.lua` is also the global factor — keep it. DWT: Hyprland default
  + stock `50-system-apple.quirks` — no local quirk.
- **Bluetooth off**: `asahi-bluetooth-power`: `bluetoothctl power off` (blocks until BlueZ confirms), then
  `rfkill block` — blocking a live BCM43xx radio can wedge it until reboot.
- **Bluetooth monitor** (port of uBruckhaus/omarchy-bluetooth-monitor): `asahi-bluetooth-monitor` (stdlib Python), one
  long-lived child of `services/BtMonitor.qml`; sole writer of `~/.local/state/asahi/bluetooth-monitor.json`. HID++ over
  hidraw: long-only nodes get long reports. Rescans on `upower --monitor` peripheral lines (not laptop battery / AC),
  HID++ `0x41`, a failing node, commands, else a timer (pane resets `paneOpen` on destruction: a Loader drop skips the
  Binding restore). Receiver nodes carry every DJ input report: sit out 1 s after an unannounced wake-up. HID++ settings
  per wpid reapplied on first sighting and when a gone device answers. Short HID++ replies zero-pad to long (cut pairing
  register = empty slot). Validated: stdin size, JSON booleans, regular own state file; bad DPI (never snapped) /
  SmartShift mode refused. hidraw denied → UPower `hidpp_battery` rows stand in. Cabled UPower battery = `usb` via sysfs
  (upstream: wireless). No device hiding (little use, much UI). Strings `services/bt_i18n.js`: English + German only.
  hidraw is root-only: "Allow access" → `pkexec /usr/local/libexec/asahi-logitech-access` (root-owned installer copy) writes
  `/etc/udev/rules.d/42-asahi-logitech-hidraw.rules` (`KERNELS=="0003:046D:*"` / `0005:046D:*` → uaccess; opt-in, not in
  installer; revoke: replug or `setfacl -b`). Pane scan = `bluetoothctl --timeout 300 scan on` (BlueZ ends discovery
  with its client), restarted after 5 s without `Discovering` (with `--timeout` it never exits on a failed
  StartDiscovery). Connected headset / speaker → `Pipewire.preferredDefaultAudioSink`. Backspace: `handleBackspace` hook
  in LauncherWindow (only this pane). Tests: `asahi/bin/asahi_bluetooth_monitor_test.py`, `services/bt_monitor_test.js`,
  `services/bt_i18n_test.js`.
- **zram**: only swap. `./install.sh asahi-system` installs zstd (`zram-generator.conf.d`) +
  `sysctl.d/99-asahi-zram.conf`.
- **Wi-Fi scans refused**: list shows only the connected AP; kernel
  `brcmf_cfg80211_scan: Scanning suppressed: status (4)`, `CTRL-EVENT-SCAN-FAILED ret=-11`, `nmcli … --rescan yes` still
  exits 0. Cause: a DHCP restart on an active link (Proton VPN's `device-reapply` of `ipv4.routes`): NM sends
  `CRIT_PROTOCOL_START` but `…_STOP` only on activation; brcmfmac clears scan-suppress only on STOP. Fix:
  `nmcli connection up id "<ssid>"` (Proton tunnel survives), not `nmcli device reapply wld0`. Still in Aurora's
  brcmfmac (suppress cleared only by `crit_proto_stop` / link down); the proper fix is kernel-side.
- **Wi-Fi band**: `asahi-wifi-band [status|auto|2.4|5]` pins the profile's band (AP band-steers), reverts if the
  reconnect fails. Connected card: `asahi-network`'s tooltip (without `--bar` it describes Wi-Fi even with a cable up) +
  `iw link` (dBm only `^-?[0-9]{1,3}$`). Open, Enhanced Open, WEP = public, 802.1X = sign-in; no extra probe. BCM4388
  resume fix (omarchy-mac) not ported: post-resume rejects recover in 6–30 s. Tests:
  `asahi/bin/asahi_wifi_band_test.sh`, `asahi/bin/asahi_network_test.sh`.
- **Captive portals** (omarchy 4.5): `asahi-connectivity.conf` gives NM a plain-HTTP probe (GNOME's documented pair;
  never an HSTS host); `asahi-network` reports the cached state (`full/limited/portal/none/unknown`); the bar chip
  tints (`Style.connectivityColor`: red portal, orange limited); the pane shows Sign-in required/Limited + a
  Sign-into-network pill → `asahi-captive-portal <url>` (flock, xdg-open, C-locale `nmcli check` wait; no window
  close — never kill the browser). Pane URL == probe URI, test-enforced; rescan re-polls, no extra timer.
- **Kernel (Aurora)**: `kernel-aurora-core` (16k pages): USB-C DP alt mode (`typec_displayport`, `phy-apple-atc`,
  appledrm `typec_follow_crtc`), USB4/Thunderbolt, SEP, AVD with `avd-fw`. `asahi-debug` accepts `*asahi*` / `*aurora*`.
  The self-built fairydust kernel (`~/linux-fairydust`, gone) is retired; its local fixes on Aurora: brcmfmac
  `roam_delta` fixed (no `-52`); DCP HPD re-sample on resume and the lit-USB-C-unplug crash reworked (`clear swap timed
  out`, unplug of a powered-off Type-C output ignored) — whether suspend `-22` is gone is untested; AVD runs. Outputs:
  `card1` = DCP (`card1-eDP-1`, `card1-HDMI-A-1`, `card1-DP-1..6`), `card2` = GPU render-only (DRM name `aurora`,
  `62-aurora-gpu-render-only.rules`); no `ddc` link. `userpages 4k` needs `user4k=on` on the cmdline (Aurora's install
  sets it; a manual `kernel-install add` rebuilds the entry from `/etc/kernel/cmdline`).
- **Aurora boot chain**: Stage 1 m1n1 (stock v1.5.2, APFS stub) loads ESP `m1n1/boot.bin` = aura Stage 2 + the board
  DTBs of the **default** kernel (`/boot/dtb` → `dtb-<ver>`) + U-Boot; the kernel gets that DT. Aura hands SEP its
  `local-policy-manifest` via the DTB's `sep` alias and keeps the j414s `fingerprint@0` node; stale DTBs (2026-11-09:
  the old fairydust pin `DTBS=/boot/dtbs/fairydust`) → `apple_sep … 'local-policy-manifest' missing`, `aurora-sep`
  fails after 120 s, `aurora-touchid-setup`: "no Touch ID sensor in its device tree". `update-m1n1` (also kernel-install's
  `15-update-m1n1.install`) refuses while a kernel without `/usr/lib/modules/<v>/dtb-abi` (generation 0: fairydust,
  `kernel-16k`) is installed — and that aborts `kernel-install add` of new kernels (no `/boot/vmlinuz-*`).
  `asahi-system` (before dnf) resets `DTBS="/boot/dtb"`, `UPDATEDEFAULT=yes`, `DEFAULTKERNEL=kernel-aurora-core` (else
  20-grub.install never makes an `.aurora.` kernel the default), adds `user4k=on` to `/etc/kernel/cmdline` + grubby,
  and — only when booted into an Aurora kernel (the fallback) — `dnf remove --no-autoremove 'kernel-16k*'`,
  `kernel-install remove` + `rm` of `*fairydust*` (+ `fairydust-typec.conf`), Fedora Asahi leftovers
  (`asahi-platform-metapackage-*`, `asahi-battery`: second charge-limit store), re-runs `kernel-install add` for
  the **newest** Aurora kernel when it lacks a `/boot` image or initramfs (hostonly initramfs; never an older one: every
  add becomes the GRUB default and Stage 2's DTB source — `bootchain.py` `becomes_default`, 20-grub `NEWDEFAULT`), then
  `update-m1n1`. `asahi-scripts` stays (update-m1n1
  mounts the ESP with it). Stock Stage 1 = no `aura-try` trial: boot.bin replaced directly, `boot.bin.old` kept
  (conversion copy `boot.bin.pre-aurora`); worst case swap them on the ESP from macOS. Check:
  `/proc/device-tree/aliases/sep` (`asahi-debug` `stage2-dtb`). Converted, still on a pre-Aurora kernel: `update-m1n1` refuses and `make aurora`
  stops there → boot an Aurora kernel (GRUB) and rerun; if none has a `/boot` image (its `kernel-install add` aborted),
  `sudo M1N1_UPDATE_DISABLED=1 kernel-install add <v> /usr/lib/modules/<v>/vmlinuz` first (update-m1n1 honours the
  variable; the old Stage 2 boots it; dnf will not remove the running kernel).
  Conversion built a `--no-hostonly` initramfs: no `/etc/modprobe.d` (fnmode 3,
  `show_notch` N) until a hostonly rebuild.
- **WM defaults**: `general.lua` `on_focus_under_fullscreen = 1` (window focused under fullscreen takes over).
  Hyprland-default values stay out (`hyprctl descriptions -j`; `tap_to_click` kept on purpose). Window rules match the
  whole class / title; monitor `desc:` is a prefix match (make + model, no serials). Validate keys against
  `/usr/share/hypr/stubs/hl.meta.lua`, then `hyprctl reload && hyprctl configerrors`.
  `Hyprland --verify-config -c asahi/hypr/hyprland.lua` still runs the reload hooks (asahi-hdmi sync,
  monitor-scale/clamshell) against `$HYPRLAND_INSTANCE_SIGNATURE`; `HYPRLAND_INSTANCE_SIGNATURE=none` fails their
  hyprctl calls but `asahi-hdmi sync` still bumps `$XDG_RUNTIME_DIR/asahi-hdmi.gen.<output>` — not during a settle.
  Dispatch: `hyprctl dispatch 'hl.dsp.…({…})'` (legacy `dispatch <name> <args>` dead). Float is its own call; maximized
  refuses resize+pin. Rule `opacity` multiplies with `inactive_opacity` — `opaque = true` for media/PiP/webcam. Capture
  binds must not be `locked` (lock-screen recording kept running after unlock). `suppress_event = "maximize"` for every
  class (self-maximizing apps stay tiled; Super+F still maximizes).
- **asahi/bin**: helpers in `asahi/bin/lib/common.sh`, sourced via
  `$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/lib/common.sh`; sibling paths via that dirname, not
  `$HOME/.dotfiles`. Apps launch via `asahi-launch` (binds, scripts, Hyprland's `launch()`; launcher prefixes `.desktop`
  execs with `uwsm-app --` itself); scripts detach helpers with `setsid`. Reuse its helpers (`on_ac`, `live_pid`, …).
  `components.sh` chmods `asahi/bin/*`, skips `lib/` (a dir) — keep sourced files there.
- **Untrusted text**: a `Text` showing outside strings (titles, SSIDs, BT names, clipboard, file names, notifications)
  sets `textFormat: Text.PlainText`: AutoText renders `<img src=http…>` = remote fetch without a click (omarchy #8397).
  Only exception: the notification body (StyledText from `NotificationModel.richBody`, an allowlist; `href` written raw:
  StyledText keeps `&amp;` in it).
- **Quickshell launch**: never `qs -d` (EPIPE/`qFatal` if the parent is gone); `setsid -f qs -n -c <module>`
  (`asahi-restart-quickshell`). Bar vanished → `asahi-debug` coredumps first. qs reloads on save (log
  `/run/user/$UID/quickshell/by-pid/<pid>/log.log`). `grim` blocks on a DPMS-off output — always `timeout`. zprofile
  unsets Lmod's `BASH_ENV` (13 → 1.2 ms per bash).
- **Polkit**: `modules/system/PolkitAgent.qml` (Quickshell `PolkitAgent`) is the agent (else pkexec / GUI admin
  prompts fail silently); one card on the focused screen.
- **Touch ID (Aurora)**: `apple_sep` module (loaded by `aurora-sep.timer` once root is up) + Aurora libfprint / fprintd
  on `/dev/sep-bio`; needs current Stage 2 DTBs (see Aurora boot chain). `make aurora` runs `comp_asahi_touchid`
  (`./install.sh asahi-touchid`; after the desktop, before doctor: its failures exit 1 and must not block the
  desktop): `sudo aurora-touchid-setup` (per-Mac calibration from the iBoot System Container,
  idempotent), authselect `with-fingerprint`, and `fprintd-enroll -f right-index-finger $USER` on a tty when no finger
  is enrolled; skips (warns) before the reboot onto Aurora DTBs and on Macs without a sensor node. Also installs +
  enables `aurora-fido` (Touch ID as a FIDO2 key: passkeys / WebAuthn, `ssh-keygen -t ecdsa-sk`; pam_u2f would work, not installed; `sealed` key
  store until the kernel has `/dev/sep-key`; `aurora-fido status`, `sudo aurora-fido disable [--forget]`).
  `pam_aurora_touchid` (system-auth) re-arms Touch ID after a password; `/etc/aurora/touchid.conf`
  `require_password_after_boot` (password before the first Touch ID, `aurora-touchid-boot`) needs the kernel's Touch ID
  wait ioctl: this kernel has none, so Touch ID works from the first login.
  `aurora-sep-ready` turns on authselect `with-fingerprint` (Aurora's vendor `local` profile: sudo, polkit and
  `fingerprint-auth` only; tty1 `login` stays password = keyring unlock).
  hyprlock `fingerprint:enabled` (fprintd D-Bus beside PAM, no label); the polkit card shows
  PAM's finger prompt (`supplementaryMessage`). Diagnose `aurora-xart status`, `journalctl -u aurora-sep -u
  aurora-sep-ready`; start over `sudo aurora-xart reset-touchid`, reboot, enrol again (it refuses while the keybag works; also after a root
  rollback or reinstall: they bring back an
  older / empty xART owner list, `/var/lib/aurora-sep-xart-owned.bin`, and the guard refuses the Linux records;
  `/usr/share/doc/aurora-sep/XART-SAFETY.md`). Risk (omarchy-mac manual 04-security): the SEP anti-replay state is shared
  with macOS; written wrongly, FileVault macOS cannot unlock → DFU restore (erases); xART guard 1 (M2 default) refuses
  macOS's records (`xart_guard_refusals`, Hardware pane); README tells him to keep a macOS backup. **No fprintd restart on
  resume** (omarchy's
  `system-sleep/fprintd-resume`, for Quickshell's PamContext lock): hyprlock 0.9.7 keeps one claim across sleep
  (PrepareForSleep(false) only re-runs VerifyStart on the cached proxy) and never re-claims after fprintd restarts
  (no NameOwnerChanged) — a restart kills Touch ID for that lock; Aurora's fprintd handles sleep itself. Gap: Aurora's
  libfprint removes the reader while the lid is closed (`Lid closed; removing …`) → a lock taken before the close
  gets `verify-disconnected` (password still works). If that shows (`grep fprint: ~/.local/state/asahi/hyprlock.log`),
  fix it in the locker (fresh hyprlock claim on lid open via the asahi-lock guard; never SIGTERM/USR1 = unlock).
  **Wedged fprintd** (2026-11-09 13:38 → dead for a day, silently): power key (= the sensor, pressed instead of
  touched) during a polkit / sudo finger prompt → suspend mid-verify → pam_fprintd's Release fails "still busy" →
  fprintd drops the claim but keeps the reader open → every Claim: `Open failed … already been opened` (lock, sudo,
  polkit; `fprintd-verify` shows it). Only a restart clears it: `asahi-lock` restarts fprintd on that claim error
  (`asahi/polkit/49-asahi-fprintd-restart.rules`, installed by `asahi-touchid`: wheel may restart `fprintd.service`);
  that lock stays password-only (hyprlock never claims again), the next one has Touch ID.
- **Touch ID prompt** (idea: omarchnix's touchid plugin): `modules/system/TouchIdPrompt.qml` = a card under the notch
  while something waits for a finger without a prompt of its own (sudo / su in a terminal, `aurora-fido`: passkeys and
  ssh `ecdsa-sk`, `fprintd-verify`); lock screen and polkit card draw their own (suppressed: `hyprlock` / a
  `polkit-agent-he*` process alive). Feed: `asahi-touchid-monitor` (stdlib + gi, `setpriv --pdeathsig`): fprintd's
  device signals are broadcast (`VerifyFingerSelected` = start, `finger-present`, `finger-needed` false *before*
  `VerifyStatus`), who asked is guessed from /proc at start (newest own sudo, its terminal's Hyprland window: click
  focuses it; fido: newest ssh / git < 120 s). aurora-fidod's own notification (app name `Touch ID`, "Touch ID to sign in
  to <site>", closed when the request ends) is routed by `NotificationCenter` into the card (no toast / history /
  sound; tracked, else freed at once). State machine `touchid_model.js` (`touchid_model_test.js`; monitor:
  `asahi_touchid_monitor_test.py`). Preview: `qs -c remix ipc --any-display call touchid feed '<event json>'`. Never test
  with a killed `fprintd-verify`: fprintd reported that as `verify-no-match` (may count toward the SEP lockout).
- **SSH on Touch ID** (2026-11-11, his pick): `asahi-touchid-ssh` makes `~/.ssh/id_ecdsa_sk` (aurora-fido, one touch,
  no passphrase, not resident: no PIN). `setup HOST…` = create + `authorize` (appends the pubkey over the old key,
  BatchMode) + `default` (Touch ID key before id_ed25519 in `Host *` of the untracked `~/.ssh/config`, backup
  `.bak-touchid`; id_ed25519 out of the running agent: the agent offers its keys first, in the order added) + `test`
  (sk only, no agent: a touch per host). `retire HOST…` drops id_ed25519 from a host's authorized_keys inside a login
  that only the Touch ID key could make. Host names / addresses live only in `~/.ssh/config` and the command line, never
  in the repo; a password / GSSAPI-only host offers no publickey at all: no key works there. id_ed25519 stays the local
  fallback (a host without the new key: passphrase via keychain as before). ForwardAgent hosts: a forwarded sign needs a
  touch here. Sealed store: make a new key once `/dev/sep-key` shows (watch list). A test notification with app name
  `Touch ID` lands in the card, not as a toast. Firefox (Flatpak, `devices=all`) reaches aurora-fido's hidraw (uaccess,
  `ID_SECURITY_TOKEN`; a CTAPHID INIT from inside the sandbox answers); **Proton Pass intercepts WebAuthn** (passkeys
  go to Proton, aurora-fido sees nothing): he keeps it so. `fido2-tools` (asahi-touchid) lists / deletes passkeys.
- **Stay awake**: one flag `$XDG_RUNTIME_DIR/asahi-stay-awake`, owned by `asahi-stay-awake`; hypridle listeners skip
  under it (`asahi-idle` checks `status`).
- **Idle (macOS-shaped)**: hypridle = plain `hl.exec_cmd` in `autostart.lua`'s `hyprland.start` hook, **not**
  `hypridle.service` (its cgroup: a crash restart kills hyprlock / saver → lockdead; `qs ipc` matches by display
  string, session `QT_QPA_PLATFORM=wayland;xcb` → callers without it need `--any-display`). Super+Ctrl+Alt+I =
  `asahi-restart-app hypridle` (uwsm-app scope, no Restart=). `hypridle.conf` → `asahi-idle at <secs>`; step from the
  power source **at fire time** (unplug mid-idle still locks). Battery: dim + kbd 10 % 2.5 min → lock, off 5 min,
  no saver (2.5, not macOS's 2: by choice); AC: saver 3 → dim 5 → off 10 min. Backlight **not** zeroed; `off`
  suspends 60 s later. hyprlock's surface map fakes pointer motion (restarts every listener) → `off` ignores wakes while
  locking (`$XDG_RUNTIME_DIR/asahi-idle-locking`), set *before* stopping the saver (its unmap fakes motion too), then
  watches DPMS (`key_press_enables_dpms` → `asahi-idle wake`: stops the saver before the lid check). Dim while locked
  runs `off`. Sleep skips while a sink carries signal (`pw-record -P '{ stream.capture.sink = true }'` on its monitor,
  else it records the mic; pre-volume: muted counts) or an external is on (`external_on` in `lib/common.sh`;
  `FALLBACK` is not one). `off`: flock single-instance (coalesces wake bursts), retries a refused suspend. Saver: one
  shared tick, no per-scene timers; Life's recursive source not `live`. Saver keys need `focus: true` on its Loader
  and no `focusable:` (overrides `WlrLayershell.keyboardFocus`).
  **Aurora: a key or trackpad click wakes s2idle** (dockchannel-hid wakeup source; touches don't; no lid check, logind
  re-suspends a closed lid after `HoldoffTimeoutSec`); lid, power button and, on AC, BT input
  (`asahi/udev/99-asahi-bt-wake.rules`; untested on BCM4388 — drop it on spurious wakes) too. Manual sleep
  (Super+Ctrl+Alt+S) = `asahi-idle sleep`, refused while an external is on. Log `~/.local/state/asahi/idle.log`. Test
  `asahi/bin/asahi_idle_test.sh` (`ASAHI_PSY_DIR`, `FAKE_LOCKED`).
- **Time Machine**: `asahi-timemachine` = restic, one repo (`$TM_DIR` on drive `$TM_LABEL`), local (udisks mount,
  never unmounted) or SFTP (drive on the backup host). Host/path/port live **only** in
  `~/.config/asahi-timemachine/config` — never commit them. Own key `id_ed25519` there
  (`restrict,command="internal-sftp"` on host); ssh `-F /dev/null`, no agent (else the main key is offered). Password
  file beside it (copy in password manager). Hourly timer, runs if last ok > `TM_MIN_AGE_H`; offline (incl. restic rc
  10) = skip. `refresh lock` death (lid close) / unreachable repo = `interrupted` (silent); only a reachable repo
  failing = `failed` (critical, **once per error text**). Start/skip notify only on manual `start` (`--force`).
  `last_success` set at snapshot save, then `housekeeping` → `status.cleaning` (check damage = critical every run).
  No success for `TM_WARN_D` days → `.overdue`, one critical per stale `last_success`. `r unlock` first (a killed run's
  lock blocked prune). Excludes `*.o *.ko .*.cmd`, `~/.local/share/flatpak`, `~/.Trash`; `.nobackup` skips a dir.
  `asahi-timemachine log` = journal. `stop` = `systemctl stop`. Units (and `start`) add `CPUWeight=idle`
  (`IOSchedulingClass` alone weak on mq-deadline). State `~/.local/state/asahi/timemachine.json`: flock + atomic `mv`
  (FileView follows renames); `status` only reads it. `BackupChip` only when running / failed / check_error / overdue.
  Quick pane `backup` (Super+Ctrl+R): browse (`ls` exit 4 = not in snapshot); restore →
  `~/Restored/<date>-<id>[-HHMMSS]/<abs path>` (new folder each: restic `--overwrite always`); real path in
  `.last_restore` (transient unit runs **without** `--pipe`: a dead client would SIGPIPE it). Old rsync copies = tars
  tagged `legacy-rsync` (`restic dump <id> /<name>.tar | tar -x <path>`); `forget` only `--tag asahi`. No sleep
  inhibitor (lid close must suspend). Setup `asahi-timemachine init`. Test `asahi/bin/asahi_timemachine_test.sh`.
- **Snapper**: AsahiLocker's stock configs (`root`, `home`) used plain-number limits → `FREE_LIMIT` never freed
  (`snapper cleanup` prints "quota not working (qgroup not set)" per config: no btrfs qgroups by design, so
  `SPACE_LIMIT` is ignored; `FREE_LIMIT` (statvfs) and the ranges still apply. Expected in every `make aurora`.)
  anything (acts on **ranges** only). `./install.sh asahi-snapper`: short ranged retention, no monthly/yearly (restic
  keeps history), `home` `ALLOW_USERS`. Nested subvolumes (not snapshotted) only for restic-excluded dirs (caches,
  Flatpak, Nextcloud): restic's `--one-file-system` skips them. Never stage big temp files in `~` or `/`: hourly
  snapshots pin them.
- **Writing tools**: Super+Shift+E → `modules/writing/WritingTools.qml` (GlobalShortcut `writing-tools`).
  `asahi-writing-tools capture`: `send_shortcut` Ctrl+C behind a `--sensitive` marker, old clipboard restored
  **always** `--sensitive` (browser passwords carry no hint → cliphist); `; printf .` keeps a trailing newline. Not
  primary (misses keyboard selections); terminals use primary (Ctrl+C = SIGINT). Tests `writing_diff_test.js`,
  `asahi/bin/asahi_writing_tools_test.sh`. `run` = streamed Anthropic API (curl SSE), `claude-haiku-5-5`;
  `ANTHROPIC_API_KEY` from session env, else `zsh -ic` (fd 3); curl gets it via header file (`-H @<(printf …)`),
  **never argv**. Only `end_turn` is a result (dropped stream / `max_tokens` = error: Replace would lose text).
  `fitOutput` keeps fences the selection has. Card **never takes keyboard focus**
  (`WlrKeyboardFocus.None`; QtQuick fields drop their selection on focus loss) → Replace = `wl-copy` + `send_shortcut`
  Ctrl+V to the source address; off for terminals and truncated captures. Card keys = Hyprland submap `writing`
  (`bindings.lua`, no desc); `catchall` swallows keys so typing can't overwrite the selection; left click needs its
  `non_consuming` no-op bind (else clicks eaten); qs enters it on open, resets on every close and destruction. Pane
  drag-select = own MouseArea, not `selectByMouse` (Qt claims primary → GTK drops the source selection).
  **Look Up**: Super+Shift+D (GlobalShortcut `lookup`), same capture / card (phase `lookup`); `run define` (own
  prompt, not `$common`) → `key: value` lines (`lookup.js`, test `lookup_test.js`); definition in German for
  German, else English, translation en↔de; links (submap W/D/T/K) via
  `asahi-launch xdg-open`; body `LookupView.qml`. Launcher `:def` / `:lookup <word>` (`ArgCommands.parseLookup`) →
  `lookUpInLauncher()` (`writingTools` injected by shell.qml; no popup / submap); closing the launcher stops the run.
  No tool use on purpose (web search: ~1 s → seconds + fee).
- **Timers**: `asahi-timer add <dur> [label]` = transient `systemd-run --user --on-active`; launcher `:timer 10m tea`
  (`arg_commands.js`, tested).
- **Window pop**: Super+O → `asahi-window-pop` (float/resize/center/pin/`bring_to_top`/tag `pop`: follows every
  workspace, omarchy's pop); second press retiles.
- **App grid** (Launchpad, omarchy Super+Alt+Space): `modules/launcher/AppGrid.qml`, IPC `launcher apps`; every app A–Z,
  type to filter (name start > word start > anywhere), arrows / Enter / click, Esc clears then closes. Reuses the
  launcher's hides, icons (`resolveIconUrl`) and `launchDesktopEntry` (sets `launcherWorkspaceId` first). Opening the
  launcher closes it and vice versa; opening it also closes the calendar, notification sheet and bar popups (their focus
  grab kept its keys). Hover selects only after a real pointer move (`pointerMoved`, the launcher's rule: a cell rebuilt
  under a resting cursor took the selection, Enter launched it). No dock / pins / uninstall (omarchy's). omarchy's Super+K overview = Super+K **held**
  past the key-repeat delay (300 ms; `long_press` bind; Super+Ctrl+K dropped, his pick): a tap stays focus up, a hold also
  moves focus once. Nested virtual-keyboard test: 80/150 ms → focus only, 700/900 ms → focus + overview.
- **Hardware pane** (Super+Ctrl+H, quick key `hardware`): `panes/HardwarePane.qml` over `asahi-hardware` (sysfs / procfs /
  DT as the user; `--live` = CPU clocks, GPU, ports, sensors every 2 s while shown; the live merge keeps static fields
  like the GPU core count). **Only what no sibling shows** (the first versions repeated them; `hub_test.js` and the
  script's test refuse them back): power rails → Battery, fans → Temperatures, SSD → Storage, OS / chip / memory →
  Dashboard (its Host / Kernel / CPU / GPU rows open this pane, `ffPanes`; Display, Disk, IP, Bat and the Storage /
  Battery gauges open theirs). The kernel row is the one overlap, his pick (it heads the boot chain in System). Hero: model, SKU · board · part, serial chip (click copies; the icon is the feedback, a
  "Copied" label resized the chip). Tiles: CPU (`cpu_mhz` per cpufreq policy; E = the clusters with the lowest top
  clock, P = the fastest of the rest, governor), GPU, last sleep (`/sys/power/suspend_stats` + the last `slept` line of
  `idle.log`: W, or "+Wh" / "on AC"), Health (`asahi-debug --json`, ~0.7 s per open: count + the ids that did not
  pass; click = the report in a terminal — a list card did not fit beside a busy dock). Cards 2 × 2 (Ports | Sensors,
  Touch ID | System): it must fit the laptop pane (767 × 636) without scrolling, docked too (three busy ports just
  fit — a new row needs room first; a fourth device behind one port scrolls). Ports: typec `connector/label` minus "USB-C ";
  the unlabelled PD controller (`usb-pd@3a`) = MagSafe; "DP alt mode" = the partner's `ff01` alt mode is active, not
  a lit output; `pd` = `power_operation_mode`; `data` only for a port with a USB controller; its devices = the USB
  devices whose sysfs path runs through that controller (the port's `supplier:platform:<addr>.usb` link), hubs left
  out; a lone device without a PD identity names the row. Light / lid sensors by IIO `name` (`aop-sensors-als` /
  `-las`): the `iio:deviceN` index swaps between boots. jq: `0` is truthy (0 lux shows). GPU cores from the kernel log
  (cached per boot). Tuned profile / boost are not shown (no effect, see Power profiles). Test
  `asahi/bin/asahi_hardware_test.sh` (`ASAHI_SYS_ROOT` fake tree, `XDG_STATE_HOME` for `idle.log`).
- **Launcher preview** (no live popup): copy `remix`, a shell with only the `LauncherWindow` Loader + an IpcHandler
  (shell.qml's imports, else `LookupView` is "not a type"; drop `asahi-cliphist watch` from the copy: it restarts the
  live watcher), `qs -n -p <copy>/x.qml` in a nested Hyprland with a headless output (as for the lock), `qs -p … ipc
  --any-display call`, `grim -o`. `hl.dsp.cursor.move` sends the layer no motion: hover / clicks need a
  `zwlr_virtual_pointer_v1` client. Bar the same way: `BarHost` per output + a stub notification centre; never the
  real `BarData` / `BtMonitor` services in the copy (dnf check, `nmcli monitor`, the helper's state file):
  stubs bound to one JSON case, set over IPC (battery, audio, tray, status, usage …), headless `eDP-1` at 3024x1964
  (scale 2 / 1.333 / 1) + an external, `XDG_STATE_HOME` = a scratch dir with another `asahi-theme/colors.json` per
  palette. `hyprctl dismissnotify` clears the nested "started without start-hyprland" banner.
- **Display scale**: Super+Ctrl+plus/minus → `asahi-monitor-scale`. Legal scales = 1/120 divisors (eDP-1: 1 / 1.333333
  / 2). Saved per output name under `$XDG_RUNTIME_DIR` (HDMI-A-1 shared by both sinks). Positions **derived**
  (`anchor_offset` in `lib/common.sh`), never pinned.
- **Refresh rate**: eDP-1 stays 120 Hz (`monitors.lua`); battery 60 Hz saved ~3 W only in video — do not re-add.
  ProMotion / VRR: eDP-1 has `vrr = 1`, dormant — Aurora's appledrm has VRR code but marks j414s eDP-1 and the LG
  `vrr_capable` 0 (aquamarine "crtc is incapable of vrr"; Aurora enabled it on J616s only, 2026-11). Monitors pane
  shows the state read-only (`vrr` in `monitors -j`). LG `cm = "edid"` lives in `asahi-hdmi lg_fields` (its enable eval
  replaces the desc rule; monitors.lua alone did not stick).
  Wi-Fi power save: no gain, stays off.
- **Aurora extras (2026-11-09 interview)**: launcher "Restart into macOS" = `pkexec asahi-bless --set-boot-macos
  --next -y && systemctl reboot` (one boot only).
  `asahi-pkg tui-upgrade` runs under `systemd-inhibit --what=sleep` (not `idle`: the screen must still lock)
  then `asahi-boot-check` (newest `kernel-aurora-core` has `/boot/vmlinuz-*` + `initramfs-*.img`, `/boot/dtb` → its `dtb-*` =
  Stage 2 built from it; Stage 2 follows the GRUB default, unreadable without root, so the remedy is `grubby
  --set-default` + `update-m1n1`; "Restart needed" on a new kernel or a deleted Hyprland / qs binary). Faster shutdown: `DefaultTimeoutStopSec=10s`
  (system + user, `asahi/systemd/{system,user}.conf.d`), fprintd `TimeoutStopSec=3s`. abrt masked (coredumpctl +
  asahi-debug instead). Keyboard light at the LUKS prompt: `asahi/udev/90-asahi-kbd-backlight.rules` (128 if 0) +
  `pwm_apple` in the initramfs (`leds_pwm` is built in). mpv `vo=gpu` + OpenGL (omarchy-mac CPU numbers). LG
  UltraFine `cm = "edid"` (wide gamut). `asahi-debug` / doctor check Aurora services + an enrolled finger. Kept
  `user4k=on`. Declined: FEX/Steam, speaker no-suspend, headset-mic priority, audio watchdog, 6 GHz guard, crash toast,
  dictation.
  File sharing (2026-11-09): **LocalSend** Flatpak (iPhone app, same LAN); receives on 53317 tcp/udp, opened by `asahi-sshd` in
  firewalld's `home` zone only (`nmcli connection modify <name> connection.zone home` for a trusted network). Not
  launched in tests: it announces itself on the LAN.
  Declined 2026-11-09: AirPlay (his Devices-tab store for the trusted home network lists no AirPlay receiver; he left them declined when asked;
  `pipewire-config-raop` = only `50-raop.conf` discover, the RAOP sender then needs inbound UDP; `shairport-sync` is a
  listening daemon), Force Click → Look Up (`hid_magicmouse haptic_deep_keycode` is 0444: load-time only, the module is
  in the initramfs → dracut + reboot; no "Force Click" input device today; untested on j414s; Look Up = Super+Shift+D).
- **Aurora watch list (what comes after, 2026-11-09)** — revisit when upstream moves: `asahi-debug` `check_watch`
  reports `/dev/sep-key`, `aurora-sep-cryptenroll` and eDP-1 VRR on its own (SKIP absent, WARN / PASS when there);
  public Aurora downloads (site says "Coming soon"; README points at the alpha installer) → README link; `/dev/sep-key`
  in the kernel → `aurora-fido` leaves the `sealed` store (re-enrol passkeys); `aurora-sep-cryptenroll` for the root
  volume → Touch ID unlocks LUKS; Touch ID wait ioctl → `require_password_after_boot` works; j414s VRR (eDP-1 `vrr = 1`
  waits); a boost-aware power profile → selector in the Battery pane;
  hyprlock re-claiming fprintd (lid-close reader drop; 0 `verify-disconnected` in 8 Touch ID unlocks, 2026-11-09) → Touch
  ID after lid open; DCP `-22` suspend
  with a lit USB-C display (untested on Aurora); `agx_stats` `temperature_raw` documented → GPU °C in the Hardware pane.
- **Power profiles**: Aurora requires `tuned` (active, profile `balanced`: schedutil; `tuned-adm active` says "not running"
  without D-Bus, e.g. sandboxed). Its per-policy `boost=1` gets EINVAL: global `cpufreq/boost` is 0 (mainline default since
  6.15), so the P-cores' top states (3360–3504 MHz) never run. No PPD / tuned-ppd / selector (decided 2026-11-09): every
  profile keeps schedutil, power-saver only turns Wi-Fi power save on + 15 s writeback, performance (`aurora-performance`)
  only dirty-ratio / readahead; omarchy's PPD boost toggle had "no effect" on an M2 Pro (#17609). Measured 2026-11-09
  (`tuned-adm profile`, no auth for the active session): SHA-256 single-thread 3.2–3.3 GB/s and system power equal
  within noise in balanced / powersave / aurora-performance; under load (2 rounds each, power sampled during the run)
  12-thread 24.7–25.8 GB/s at 42–46 W in every profile. Boost states 3360/3408/3504 MHz exist
  (`scaling_boost_frequencies`), never used (`time_in_state`). Boost tested 2026-11-09 (he set global `boost` 1):
  `scaling_max_freq` 3504 MHz, yet schedutil never picks 3360–3504 — pinned 100 % single-thread on cpu4 and cpu8
  stayed at 3264 MHz, boost `time_in_state` 0, same speed and power. No effect on this kernel: nothing to integrate. The one real lever =
  global boost (`echo 1 | sudo tee /sys/devices/system/cpu/cpufreq/boost`, until reboot; ~7 % peak clock, power cost
  unmeasured) — benchmark before wiring it. UPower (Aurora fork: time estimates only) never writes thresholds (`ChargeThresholdEnabled=false`).
- **LAN devices** (idea: uBruckhaus/omarchy-wlan-monitor): Network pane tabs Networks / Devices
  (`panes/LanDevices.qml`, `lan_models.js`); same layout on both (hiding VPN card / tools made it jump). Scope: who is
  on the LAN + printers; no map, FRITZ!Box mesh / rates / signal, settings, hide or Markdown copy (all cut).
  `asahi-lan watch` (stdlib Python, `setpriv --pdeathsig`) runs **only while Devices is shown**; no background timer,
  no toasts. mDNS on its own socket **bound to 224.0.0.251:5353 beside avahi**
  (SO_REUSEADDR): firewalld drops unicast answers to ephemeral ports; no avahi-tools. mDNS-only host gets one unicast
  question so the kernel ARPs it. Sockets SO_BINDTODEVICE the LAN iface (failed bind sends nothing; not the VPN TCP
  check); unprivileged bind works once → fresh sockets on iface change / no-route gap (bind holds the ifindex).
  **Untrusted networks are never pinged**; trust = SSID + router's **current** neighbour MAC; /24 ping sweep only on
  tab open + Rescan. Printer admin page = IPP `adminurl` rebuilt on the device IP. Copy → `wl-copy` stdin. Stored
  devices per network key: a blank look keeps them, a vendor OUI never replaces a saved kind; IP-only / "Kind
  (Vendor)" names not stored. Unpinned drop 10 min after going quiet (`SLEEPING_KEEP`). Hardening: stdin line > 64 KiB
  dropped whole; a bad command never ends the watcher (narrow excepts, no `except Exception`); store
  `~/.local/state/asahi/lan.json` (flock, 0600) read only as our own regular file; 64 MiB cap fits a full store (else
  defaults overwrite it). Last tab `~/.local/state/asahi/network-tab`. Panes load via `Loader` source → import
  siblings qualified (`import "." as Panes`). Test: `asahi/bin/asahi_lan_test.py`, `lan_models_test.js`.
- **Speed test**: `asahi-speedtest [--json]` — Cloudflare 50 MB down / 25 MB up (100 MB is 403). Network pane button.
- **Wi-Fi QR**: `asahi-wifi-qr` → `$XDG_RUNTIME_DIR` mode 600; `nmcli -s` for the PSK. Code sits inside the Wi-Fi card
  (layout reserves its width; a raw width painted over the LAN card).
- **Autostart**: `asahi/xdg-autostart/` (only a Hidden stub masking gnome-keyring-ssh) vs Hyprland's `hyprland.start`
  hook in `autostart.lua`. Verify no `app-gnome\x2dkeyring\x2dssh@autostart.service` under the user generator.late.
- **Secrets**: `asahi/kwalletrc` disables kwallet. `gnome-keyring-daemon` = Fedora's user unit (`pkcs11,secrets`;
  fallback `--components=secrets,pkcs11`), **never** `ssh` (SSH is keychain). Login keyring password = login password;
  `pam_gnome_keyring` in `/etc/pam.d/login` (via `asahi-keyring-pam`) unlocks it at tty1. Never seed an
  empty-password or `[keyring]` text keyring (unencrypted; `asahi-debug` WARNs, never auto-delete: may hold secrets).
  Flatpaks (Zotero) reach it only via the Secret portal: `portals.conf` pins `Secret=gnome-keyring` (its `.portal` is
  `UseIn=gnome`).
- **SSH / keychain**: Fedora's `/etc/profile.d/keychain.sh` prompts every key on tty1 → `zshenv` exports
  `KEYCHAIN_DONE=1`. `asahi-ssh-keychain`: no `--quick`, drop a stale pidfile without killing a reused PID, start an
  **empty** `--noask` agent; first `git`/`ssh` unlocks via `AddKeysToAgent yes`. `zshenv` unsets `SSH_AUTH_SOCK` when
  `ssh-add -l` cannot talk to the agent (exit > 1).

