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
- hyprpaper / hypridle: https://wiki.hypr.land/Hypr-Ecosystem/ (hyprlock: removed 2026-11-22)
- Quickshell: https://quickshell.org/docs/

## Notes
- **QML singletons**: need `qmldir` (`singleton Name File.qml`) + module import, by name — else `pragma Singleton` is
  ignored and `import "File.qml" as X` silently falls back to white/black. Prefer Quickshell `Singleton` (reloadable);
  never `Foo {}` construct. One added while qs runs stays `undefined` across hot reloads: restart qs
  (Super+Ctrl+Alt+W).
- **Lock on boot**: tty1 getty = auth gate; no lock at Hyprland start, no `agetty --autologin` (zprofile can fall
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
  restart it; never `udevadm trigger` drm (hotplugs HDMI). `InhibitDelayMaxSec=15` = the lock's time on lid close.
  Lid = `Apple SMC power/lid events` (`locked = true` in `monitors.lua`). Never set `HandleLidSwitch` (laptop-only =
  logind `suspend`); docked = `HandleLidSwitchDocked=ignore` + `asahi-clamshell` turns eDP-1 off. Without a lit
  external (`external_up`: Hyprland-enabled **and** DRM `enabled` or DPMS-off — 2026-11-02 an unmodeset DP-1 hotplug
  under lock left zero lit outputs; `asahi/bin/asahi_clamshell_test.sh`) close only starts `asahi-lock` (2026-11-22, omarchy-system-lid-close: a lid sleep locks even without hypridle's
  before_sleep_cmd; with it, `inhibit_sleep = 3` releases at once for an already locked session — lid close → suspend
  entry stays ~1.3 s; the 15–17 s waits seen 2026-11-17 / 11-22 were logind's 30 s `HoldoffTimeoutSec` after a
  resume, not the lock) —
  never DPMS-blank eDP there (races s2idle, `8000000a`, hangs) — unless a block inhibitor (`asahi-hdmi`: cable in, output off) stops suspend:
  wait 5 s for the external, else blank + lock (block gone within the wait, lid still shut: lock, as above).
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
- **Locker = the Quickshell lock**, the only one (2026-11-20 his pick after a nested prototype; Touch ID and password
  unlocks verified live; **hyprlock removed 2026-11-22**, his call — omarchy quattro dropped it too: no fallback, no
  conf, no `asahi-lock-touchid`, not installed by `dnf.sh` (he uninstalls it by hand), the installer drops its state files). `quickshell/remix/lock.qml`
  run by `asahi-lock` (`qs -p`, a separate instance; no `-n`: it exits 0 while any instance of the path runs, a nested
  preview's too, which the guard read as done; a crash of the shell never unlocks). Layout = the old hyprlock screen
  (hostname under the cutout; bottom row uptime / battery · Touch ID orb over the password pill · clock with accent
  seconds / date; the theme's `lock-fade-{top,bottom}.png`, from `write_lock_fades`): **nothing attaches to the
  notch** (his call: the notch-island card was rejected). Rises in, hyprconf's shake on a wrong password. Unlock =
  **lift-off** (2026-11-22, his pick): the orb's check lands (250 ms), the UI drops out, then the wallpaper fades and
  grows 3 % over 380 ms onto the live desktop, then the lock lets go. `misc:session_lock_xray` draws the desktop under
  the lock surface: switched on by `hyprctl eval` only after PAM said yes, off again at release and at every lock's
  start (nested: a live toggle takes effect; Hyprland's crashed-lock screen stays opaque with it on). Rejected unlock
  styles: video over windows, blur, the notch island. PAM from `quickshell/lockpam` — `fingerprint` (pam_fprintd
  max-tries 3, timeout 600, re-armed every 5 s after a timeout / suspend / lid close) beside `password` (pam_unix
  `requisite`, then `-auth optional pam_aurora_touchid.so` as system-auth runs it: a password ends a Touch ID
  lockout — review 2026-11-23, without it a lockout outlived the unlock; not the whole system stack: its pam_fprintd
  would hold a typed password 30 s). Aurora's lockout lines ("Too many failed fingerprint attempts…", "Your password
  is required…") end Touch ID for that lock (red orb). It prints "Session locked" once Hyprland confirmed the lock
  (`secureStateChanged`; 0.4 s nested, displays on or off) and "Unlocked, exiting!" when PAM says yes (the guard and
  the intro key on them). State IPC only with `LOCK_DEMO=1` (screenshots); `LOCK_IPC_SUBMIT=1` =
  a test submit that still needs PAM. Never test wrong passwords against the real finger context (a touch in between
  unlocks: it did once). The orb does not breathe on the lock (`breathe: false`; measured nested 50 + 37 → 3 + 1 ms/s
  qs + compositor): states change colour and shape, results pop; keys add printable text only (Delete, Tab, Ctrl
  combos sent control chars); `PamResult.MaxTries` ends Touch ID; a failed fingerprint run restarts fprintd once per
  lock (the wedged-reader fix; seen working 2026-11-20 after a suspend). Touch ID pacing (2026-11-22, after omarchy
  quattro's lock): an attempt that never reached the reader (lid shut: libfprint drops it; a refused claim) backs
  off 5 → 10 → 20 → 40 s (was every 5 s all lock long, e.g. docked with the lid shut); one that ran out waiting for a
  finger re-arms after 1 s; a key (once per long backoff), the end of the blank (motion / key) or a display arriving
  (`Quickshell.screens`: lid open while docked) tries again at once. Nested with a fake PAM stack (`pam_exec` logging +
  `pam_deny`): attempts at 0 / 5 / 15 / 35 s, a display added at 38 s → 38 / 43 s. No pause while the displays are
  off (tried, then dropped in the 2026-11-23 review: a lid-open wake lights the panel without input, so Touch ID stayed
  off until a key). Displays off 30 s after the last input on the
  lock (`IdleMonitor`, `respectInhibitors: false`, `asahi-dpms off`; idea: omarchy quattro; a key / motion relights, a
  Touch ID unlock in the dark runs `asahi-dpms on`; `LOCK_BLANK_S` for tests; off in demo mode).
  Look rules kept from the 2026-11-18 redesign (his ask: vibrant + see Touch ID work): background = the clip's first
  frame, sharp (a blurred / saturated copy was rejected); **no glow** ("blurry green fog"); accents =
  `lock_accents()` (the wallpaper accent pushed vivid: dark L ≥ 0.74, light ≤ 0.55, + its +40° neighbour) →
  colors.json `lock_accent` / `lock_accent2` = `Style.vivid` / `vivid2`; the orb = a hairline ring + glyph in the
  state's colour, a **solid** disc once something happens (his pick of nine styles; a bold ring "looks cheap", a
  rounded square was rejected: "I like it round").
- **Lock guard**: every lock path (hypridle `lock_cmd`, Super+Escape, launcher Lock, `asahi-clamshell` lid close
  without a lit external — direct, not `loginctl lock-session`: works without hypridle) runs `asahi-lock` = lock restart loop
  (flock, 30 tries, output → `~/.local/state/asahi/lock.log`): exit 0 only on release / `finished` after `locked`;
  crash / `kill -9` → retry (else lockdead, no way in), `allow_session_lock_restore` retakes. A crash **after** the
  `Unlocked, exiting!` line counts as unlocked (a retry would lock right after the password); if it came before the
  release Hyprland stays locked (fails closed). The reader writes `unlocked` / `eof` to
  `$XDG_RUNTIME_DIR/asahi-lock.reader`; the guard waits ≤ 1 s for either (`$!` is empty for an output process
  substitution after an external command). A lock that runs but sends no "Session locked" within 10 s
  (`ASAHI_LOCK_SECURE_TICKS`) is killed, and any attempt that ends without ever engaging (that, or a crash at start: a
  QML error makes `qs -p` exit at once, rc 255) warns once ("Lock screen failed", critical) while the loop retries —
  before, 30 silent retries and an open session. Never auto-run `hl.clear_crashed_lockscreen()` (unlocks without
  password). hypridle `inhibit_sleep = 3` explicit; logind caps the wait at `InhibitDelayMaxSec`. Super+Escape must be
  a `locked` bind (others are dead on lockdead; `dont_inhibit`: it also fires while an app inhibits shortcuts,
  Chromium keyboard lock / a VM viewer): a fresh lock once the guard is out of retries; asahi-lock exits if one runs
  (flock / `lock_running`: the `qs -p …/remix/lock.qml` process of this session only, by `WAYLAND_DISPLAY`, never a
  nested preview's, and never a loose pattern: it matched an editor with lock.qml open; asahi-idle and keyboard auto
  use it too). `asahi-lock` holds `$XDG_RUNTIME_DIR/asahi-locked` while it runs (EXIT trap drops it): the bar pauses
  its polling (`BarData.locked`). Touch ID under the lock: `asahi-touchid-monitor` classifies the lock's `qs -p`
  process as kind `lock` (suppress: the notch card stays hidden; it only knew hyprlock until 2026-11-22). TTY escape
  (`Fn+Ctrl+Alt+F3`): `pkill -f asahi-lock; pkill -f remix/lock.qml`, then (a killed lock leaves Hyprland's
  crashed-lock screen) `hyprctl --instance 0 eval 'hl.clear_crashed_lockscreen()'` typed on the TTY.
- **Lock preview without locking**: nested `Hyprland -c <min.lua>` + `hyprctl output create headless` + disable the
  nested `WAYLAND-1` output (`hl.monitor { output = "WAYLAND-1", disabled = true }`: its window sits on a hidden live
  workspace and presents nothing — frame swaps never come). `LOCK_DEMO=1 qs -n -p remix/lock.qml` (no PAM), states
  via `qs -p <lock.qml> ipc call lock state typing|reading|wrong|unlock|caps`, `hyprctl dismissnotify` before shots.
  Motion (the lift-off): `wf-recorder -o <output>` + `ffmpeg -vf fps=30` frames (grim takes ~200 ms a shot); a
  stand-in desktop = a Background-layer `Image` + two `FloatingWindow`s + a top `PanelWindow` as bar. Whole
  `asahi-lock` nested: own `XDG_RUNTIME_DIR` (else it holds the live session's flock: a real lock is skipped) +
  absolute `WAYLAND_DISPLAY=/run/user/$UID/wayland-N`. A `kill -9`ed nested lock leaves its crashed-lock screen:
  `hyprctl eval 'hl.clear_crashed_lockscreen()'` there. Never `pkill -x wf-recorder` for a nested recording (it stops
  a live take too): kill its pid. Nested Hyprland: `send_shortcut` drops modifiers, test with a plain key.
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
- **New-display prompt** (2026-11-25, idea: surface-dots MonitorPrompt): `modules/system/DisplayPrompt.qml`. `asahi-hdmi
  added` (after its enable) calls `qs ipc call display plugged <n>` once per plug: `$XDG_RUNTIME_DIR/asahi-hdmi.seen.<n>`,
  dropped by `off_hdmi` only while sysfs reads disconnected (then `display unplugged`) — a reload's fresh Lua state
  runs `added` again for every connected output, a Monitors-pane disable keeps the cable in: neither counts.
  `asahi-hdmi recall <n>` → `{name, label (EDID model), mode}`; no mode = four tiles on eDP-1 (else the external),
  Overlay, exclusive keys: Extend · Mirror · Laptop only · External only (1–4, ←/→ + Enter, click; Esc / 30 s idle
  close, nothing saved). A pick runs `asahi-hdmi mode <n> <m>` on 10 s Keep / Revert (silence / Revert = `mode extend`);
  Keep → `asahi-hdmi remember` = `"mode"` in the screen's `monitor-layout.json` entry (key = Hyprland `description`:
  make + model + serial, beside `key` / `pos`; `save` / `reset` keep it). Extend needs no probation. Known mode: applied
  at once + 5 s card "<model> · Mirror  change ▸" (click = tiles). Not remembered: Monitors-pane changes, reloads
  (`added` re-runs but never re-announces). `mode`: extend = clamshell `open` (lid open) + unmirror by reload (the
  pane's) or `on_hdmi`, waits for it; the others only from extend (the card runs extend first): mirror / laptop need
  eDP-1 enabled (never zero outputs), external waits ≤ 6 s for DRM `enabled` then `asahi-clamshell close` (an unlit
  external takes close's lid-shut lock path). Test: `asahi_hdmi_test.sh` (fake `qs` / clamshell: never the live shell).
- **Notch / fnmode**: `comp_asahi_system` writes `asahi-notch.conf` (`show_notch=1`) + `hid_apple fnmode=1`, then
  `dracut -f`; reboot. Live: `/sys/module/hid_apple/parameters/fnmode`.
- **Charge limit**: SMC is CHLS (90 reads back 90; CHWA would read 80): end 10–99 holds, start = end − 5 (start writes
  ignored), end < 100 sets the force-discharge bit (battctl: drains on AC; not seen). `asahi-charge-limit` clamps
  60–100; 100 = no limit, ≤ 99 = hold (also `asahi-battery`). One saved copy `/var/lib/asahi/charge-limit` (dir
  root:wheel 2775, temp + rename), written only after the SMC took it; boot applies it. Battery pane (Super+Ctrl+P,
  Reapply on mismatch) reads it on open / after change, never polls. SMC keeps it across unplug + s2idle: no AC-plug /
  resume re-apply unless a replug drops it. An apply takes ~60 ms: its "Applying N%…" line and the dimmed steppers show only after 400 ms
  (`limitSlow`; as a row that came and went for two frames it moved the whole hero). Never read the limit from UPower (1.91.5 reads sysfs once at start, hwdb
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
  keybinding overview = Super+K **held**, his pick). M = the bar's media popup, or the launcher's Media pane while
  no player shows its chip (it did nothing). T = btop in Ghostty (`asahi-sysmon` → `asahi-launch-or-focus-tui`: an open
  one is focused; two same-class launches in quick succession were seen to close each other after 2–8 s). `Super+Ctrl+Alt`:
  R reload Hyprland, W/P/I restart Quickshell / hyprpaper / hypridle, S suspend, Z magnifier reset.
  `Super+Ctrl+plus/minus` = display scale; `Super+Ctrl+Z` / `+Shift+Z` / `+Alt+Z` = magnifier in / out / reset
  (`hl.config { cursor = { zoom_factor } }`, not `hyprctl keyword`). Panels: `quick()` in `bindings.lua`
  (`quickActions` in `LauncherWindow.qml`); same combo again closes (`openQuick`/`openCategory`). Esc peels one layer
  (Quick pane → home → close); shortcut-opened → closes (`openedByShortcut`). Workspaces: Super+N go, Super+Ctrl+N
  move, Super+Alt+N send w/o following, Super+Y back-and-forth. Super+Alt+F = fullscreen in tile (`fullscreen_state`
  client 2); Super+BackSpace = this window opaque (toggle; inactive_opacity 0.9 washed out photos / video); Super +
  pinch = live magnifier zoom; Super+Z = Thunar in the focused Ghostty's folder (`asahi-files-here`: Ghostty's
  shell-integration title at the prompt, else home); Thunar's "File Operation Progress" floats; Super+Alt+arrows join neighbour group; Alt+Tab cycles. Lock / media / lid binds in `submap_universal`
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
  Super+Alt+F10 / Super+Alt+mute = camera only (`asahi-cmd-record camera` runs `asahi-webcam record-args`: ffmpeg from
  the same camera, libopenh264 1080p30 + mic, `recording-*-camera.mp4`; panel tile "Camera only"; pid = ffmpeg naming
  our file, SIGINT stop; the pinned overlay = preview only, started once the MP4 header exists — the denoised node is
  shared, a raw exclusive V4L2 device loses the preview, not the take; a watcher drops the overlay + REC chip when the
  recorder dies on its own, else the next toggle started a new take — only while `asahi-webcam.pid` still names its
  overlay: a quick new take restarts it before its recorder is up; its args are read before `&`, a child reads them
  late; ffmpeg fails late (inputs open after the 0.4 s check): `settle` waits for the header or its exit, then retries),
  Super+Alt+Shift+F12 + webcam (`asahi-webcam`: Aurora's denoised PipeWire camera via `pw-v4l2` +
  `PIPEWIRE_V4L2_TARGET` = its `object.serial`, shareable with a browser call; raw `/dev/videoN` without
  `aurora-camera-denoise` (user service); `/dev/video0` = AVD decoder, skipped; Super+Alt+ü/+ resize = `code:34/35`).
  slurp's `selection` layer has `no_anim`: faded out over 0.5 s, grim caught its border as a 1–2 px grey frame on every
  region shot (measured, omarchy's rule). Colour pick (Super+Shift+F12) = `asahi-cmd-colorpick`: copies the hex, a
  `screenshot` card with a swatch (`$XDG_RUNTIME_DIR/asahi-colorpick-<HEX>.png`: named by colour, Qt caches by path)
  + rgb() / hsl() re-copy; Esc = nothing (idea: serpantinum; test `asahi_colorpick_test.sh`).
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
- **Night light**: menu-only (Launcher > Actions → `asahi-nightlight`, hyprsunset); on = the last temperature (else
  `hyprsunset.conf`'s), off = `hyprctl hyprsunset identity`; the bar chip's wheel = `warmer` / `cooler [n]` (250 K a
  notch, 1000–6000 K, kept while off): the chip sums a gesture and sends one run 250 ms after the wheel stops, and the
  script holds a flock (`flock -w 10`; a hyprsunset it starts gets `9>&-`, else the daemon held the lock for good —
  review 2026-11-23, test checks fd 9) (2026-11-23: a run per notch raced — the runs set their own temperature in turns, the screen
  flickered and each run's check saw the other's value: a "Night light failed" card each; test runs three at once). Identity profile so autostart tints nothing; autostart drops stale `nightlight.json`
  (chip showed on, no tint).
- **Bar notch**: cutout is a hole (`BarModel.notchRegionInset`), not a spacer; height from geometry (3024x1964 →
  **74**), width = real cutout; overflow clipped at the wall. Right side: bell, usage ring, mic + volume, network, BT,
  battery, clock always; the rest is granted while it fits, whole or not at all (`BarModel.rightGrants` →
  `BarHost.grants`, `bar_model_test.js`): REC → screen share → timer → stay awake on → night light → tray's one icon / `+N` pill →
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
  `[mic · volume]` `[Wi-Fi · BT · battery]` `[clock]`; `rightBase` excludes tray + grants. SysChip temp =
  the SoC die (`BarData.tempIsDie`: macsmc "SoC Die Temperature", Aurora kernels; one read per 3 s) else the SMC
  average (`tempAvg`) only while it fits (`showTemp`: media
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
  `Qt.ApplicationShortcut` (grab may focus the bar). App menus = `TrayMenu.qml` (idea: caelestia), one per bar in
  `SystemTray`: the app's DBusMenu drawn in our look (rows, hairline separators, check column, app icons, submenus in
  place with Back; Esc backs out, then closes — TrayPanel's own Escape is off meanwhile: two enabled Escape
  shortcuts are ambiguous and Qt fires neither), opened by the inline icons (right-click / menu-only items) and
  TrayPanel's menu button (TrayPanel pauses its grab until `menuClosed`). One `QsMenuOpener` per level (three):
  re-pointing a single opener at a submenu released the parent menu and with it the submenu entry (empty list).
  `entry.triggered()` clicks. Tested on a private bus with a fake SNI + dbusmenu (check, separator, submenu, disabled). `HyprlandFocusGrab` dies on `focusable: false`. Attention dot static (pulse = per-frame redraw).
  Menu positions are window coords (`mapToItem(null, …)`).
- **Bar = click to act, event-driven**: chips answer a press at once (`HoverTint { down: …pressed }`,
  `Style.barStripPress`); CPU / RAM / temp / mic / volume / battery values carry a 2 px level bar (his pick from the
  2026-11-20 variants Terminal / Dots / Levels: Levels only, layout kept; renders in
  `~/screenshots/quickshell-bar-variants-*-2026-11-20.png`); left-cluster chips slide neighbours (Row `move`/`add`, off first second);
  right cluster only fades in (`add`; `move` made the clock side jump). Hover = `HoverTint`; tooltips only on tray
  icons (+ BT battery list); night-light chip only while on. REC dot blinks on the elapsed tick (no animation). Mic
  orange while recorded (`PwNodeLinkTracker`). Screen-share chip (red 󰹑, nothing to click) while a PipeWire node
  `xdph-streaming-*` exists (xdph's stream: an app shares a screen / window; the camera has its LED, our recorder and
  screenshots use screencopy, not xdph; bound to `Pipewire.nodes`). While locked (`BarData.locked`) the 3 s stats,
  30 s network script, Ccu's 5 min refresh and 10 s chip roll pause (under the lock Hyprland still sends frame callbacks:
  a looping test layer cost 17 ms/s; `QT_WAYLAND_FRAME_CALLBACK_TIMEOUT=0` measured no change, not used). The bar clock
  is no poller, but Qt timers stand still through s2idle: `SystemClock` showed the time from before a sleep for up to
  a minute after wake. `BarData.clockEpoch` (the unlock, and `asahi-idle wake` touching `$XDG_RUNTIME_DIR/asahi-idle-wake`
  at every resume / return from idle) re-enables it: re-reads the time at once (offscreen-tested). Low / critical
  battery cards = `modules/system/BatteryAlerts.qml` on UPower signals (`battery_alerts.js` + test; replaced the
  `asahi-battery-alertd` bash loop waking every 30 s; same `notify-send` cards; the installer stops and removes the
  old unit); the charger chimes on plug / unplug (freedesktop power-plug / -unplug, `paplay`; the first reading only
  sets the baseline). Sources bind, not poll: Pipewire (`AudioChip` + `PwObjectTracker`),
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
  Lyrics strip (`services/Lyrics.qml`; Apple Music player, record title + artist = MPRIS ones): 3 fixed rows under the
  row, kept through a track change (no jump), gone for a track without lyrics; tick 250 ms while synced; click = seek;
  corner toggle → `~/.local/state/asahi/media-lyrics` (`on|off`).
- **Apple Music app**: `asahi-apple-music` = Chromium `--app`, own profile (→ own MPRIS player, named via
  `/proc/<pid>/cmdline`, space-joined). Widevine: copies main profile's CDM hint (else previews only).
  `extension/clock.js` feeds MusicKit's per-track clock to Media Session. Linked into `~/.local/bin` (session PATH
  lacks `asahi/bin`). Shuffle / love / library bridge dropped (too much code). Lyrics: `extension/lyrics.js` (MAIN)
  fetches once per track through MusicKit's own client (`mk.api.music` `/v1/catalog/<sf>/songs/<catalog id>/lyrics`,
  else `syllable-lyrics`), TTML → `{t, text}` lines → `relay.js` → `background.js` (`sendNativeMessage`, one-shot) →
  `asahi-apple-music-lyrics` → `$XDG_RUNTIME_DIR/asahi-apple-music-lyrics.json` (a record per track, no lines = none).
  The launcher rewrites `<profile>/NativeMessagingHosts/asahi.apple_music_lyrics.json` each run; manifest `key` pins
  the extension id. E2E-checked headless (fake music.apple.com via `--host-resolver-rules`); the real fetch is not.
- **Look tokens** (`Style.qml`, 2026-11-20 polish pass): fonts in one block — `fontUi` Adwaita Sans (launcher, panes,
  bar popups, sheet, toasts, OSD), `fontBar` Noto Sans (bar strip only, converged), `fontMono` Cascadia NF (glyphs);
  digits that tick add `font.features: Style.fontTabular` (Adwaita has `tnum`; Noto is tabular by default). Light
  palettes run crust > mantle > base, so there `m3surface(Solid)` = mantle and cards step down (`m3container` = mantle
  tinted by base@0.8, `m3containerHigh` = base); dark unchanged; `popupBorder` stays 0.6 (≈ 3:1 on a light window;
  0.3 measured 1.6:1). Motion: bar popups, sheet, tray, app grid enter with `Menu.MenuPopIn` (fade + 0.96 → 1
  spring from the edge they hang from); bar popups, sheet, tray leave with `Menu.MenuPopOut` (150 ms, `menuExit` = M3 standard: moving at once):
  `visible: open || popOut.running`, and the focus grab, its arm timer and Esc follow `open`, never `visible` (a
  closing popup must not grab; real-click tested: inside keeps, outside closes, reopen mid-exit ends open). App grid
  unmaps at once. Launcher / `MenuCard` / backdrop leave on `MenuAnim { exit }`; a pane switch
  slides 16 px, no fade (none under reduceMotion; from opacity 0 each swap blanked the pane for a frame). Hover on a filled button = `Qt.tint(fill, Style.m3stateHover)`, never `Qt.lighter`. Section
  captions = tracked caps (`fontPx(8)` DemiBold, 1.2). Floating cards radius Lg, nested cards Md; `MenuCard` has a
  `menuHairline` rim. No `Text.NativeRendering` in the bar (SysChip's drew thinner than its neighbours at 1.875×).
  Popup text sizes = `Style.type{Caption 10, Body 11, Lead 12, Title 13, Display 22}` (bar popups, calendar, sheet,
  toasts, OSD; glyphs keep their own). Card headers = `Menu.MenuGlyphTile` (22 px tinted square); pane hero tiles 36 ×
  `uiFontScale`; pane roots `spacing: 12`; scrolling lists stop short of the scrollbar (`width: … - (bar.overflow ?
  bar.implicitWidth + 4 : 0)`); charging = green everywhere. `Style.reduceMotion` (UPower: on battery < 20 %): spring
  0, fades 100 ms, no bell swing / usage-chip roll / readout fades; Hyprland's blur, animations and inactive
  translucency go off too (`asahi-compositor-saver on|off|reload`, from `shell.qml`; restores the values it saved;
  monitors.lua's `config.reloaded` re-applies it; measured nested with an inactive window redrawing −1.3 to −1.7 W,
  idle no difference). Theme change: `BarHost.barForeground` /
  `barBackground` ease 300 ms (one Behavior each; every chip binds them). Big readouts that tick (SysPanel tiles,
  Battery / Temps heroes) = `Menu.MenuFadeText` (fade on text change, only while its window is shown — SysPanel
  lives in every bar and faded its closed tiles every 3 s; never in the bar; the owner must not bind
  `opacity`). Polish 2 (2026-11-23): `fontData` = Adwaita Mono for machine strings (IPs, BSSID, kernel, serial, paths,
  the launcher's `$ command` line, versions; not where it elides real data: the Hardware System card stays sans);
  `fontTabular` on numbers only (Adwaita's `tnum` widens `-` `:` `.`: "firefox - bin", "Session (5 - hour)").
  Overflowing lists get `Menu.MenuEdgeFade` (gradient in the surface under the list, top / bottom, only while more lies
  past that edge; `parent:` the flickable so it does not scroll; no layer). Shared pills / icon buttons / chips: pressed
  layer `m3statePress` + scale 0.97 (0.92 icon buttons; none under reduced motion). Card shadows = `RectangularShadow`
  (`cached`), not a MultiEffect blur (re-rendered every frame of a size animation). Quick rail: one selection pill
  slides between entries (snaps while the card opens); tiles tint only their disc. Glyph ≈ 0.6 of its tile (fact /
  device tiles were 0.45). Launcher nav rows: prefix keys as keycaps (`fontData`), chevron in the same slot. Layout
  gotchas: a RowLayout never re-reads an explicit `width` (launcher icon slot: rows built before a screen change kept
  the old size) — use `Layout.preferred*`; a nested ColumnLayout with `Layout.fillWidth` grows only through a filling
  child, else the row centres it (writing tools titles staggered); a row whose tile fills height needs
  `Layout.fillHeight: false` on itself (Backup tiles). His picks from the ideas (2026-11-23; declined: slider value in
  the handle — the % is shown already —, all-mono UI, port watts): **rail status dots** (`LauncherWindow.railBadges`
  → `MenuHudTile.badge`; VPN green / portal orange, die ≥ 75 °C red = the bar's red, charging green / < 20 % red,
  BT connected blue / BtMonitor low-critical, playing, recording red, backup running / a day past due orange — the
  state file is replaced by rename, so it is read on every open, not watched); **E / P per-core groups** in SysPanel
  (`asahi-cpu` cores carry `kind` from the lowest `cpuinfo_max_freq`; `Sys.coreGroups`; no kind = one row);
  **notification progress** (`value` hint → `Model.progressHint`, slim bar + % on live toasts; `hintsChanged` joins the
  replace update so `notify-send -r` moves it; history drops it). App grid: the desktop is dimmed, not blurred
  (`rules.lua` `quickshell-appgrid` ignore_alpha 0.6 over its crust@0.5 scrim = 128/255).
  Reference / motion rounds (2026-11-23, picked from before / after sheets and videos in `~/screenshots/`): notification
  **pictures fill the icon tile** (image-path hints arrive as `image://icon//<path>`; `localImage` still guards them) with
  the sender's icon as a badge (`appIconFor`: senders without an icon get their desktop entry's via `heuristicLookup`
  of the app name; our own `screenshot` / `record` senders match none: no badge). Declined: meters with a gap + stop
  dot, OSD pill, see-through launcher panels, date-picker calendar, slider value in the handle, all-mono, port watts.
  Motion (each once per open, off under `reduceMotion`, nothing loops): SysPanel **unfolds from its chip** (container
  transform: `ClippingRectangle` chip-wide → card on `Style.menuEnter`, content laid out for the full card and faded in
  past a third; the other bar popups keep `MenuPopIn`); launcher **open cascade** (result rows and rail entries rise in
  12 / 10 ms apart, 200 ms each, no lead pause; `openGen` / `cascadeNow()`: only within 250 ms of the open, never while typing; selection pill and
  highlight follow their item's `enterT`); **shared-axis** pane switch (`paneDir` from `selectDeckIndex`: 16 px from the
  direction of travel on the 200 ms effects curve, no fade; panes build in a background slot); app grid **ripple** from the centre
  (25 ms per cell step, 200 ms OutCubic, no bounce; cells rebuilt by typing just appear); Dashboard gauges **sweep**
  together, on the launcher's open only (a pane switch shows values at once).
  Motion review (2026-11-26, his ask "snappy, no fluff"; sheets + clips `~/Downloads/quickshell-pass5/motion/`): a
  Behavior picks `exit` from its own `targetValue` (bound to the owner's state, e.g. `chromeReveal < 1`, it was read
  stale: the launcher opened on the exit curve, <10 % visible after 110 ms); `MenuSpring` spring 12 / damping 0.7
  (90 % ~110 ms, trailing ~180 ms, settled ~320 ms; was 225 / 352 / 650); SysPanel unfold = `menuSpringFastMs`;
  ripple 300 + 200 ms; bar workspace icons 15 ms apart, no OutBack. Quick pane keyboard steps froze ~0.4 s under load
  (the pane was built in one frame, pill + fade ran out inside it): two Loader slots, the next pane builds
  asynchronously in the hidden one and they swap in one frame (one async Loader blanked the pane while it built: a
  flicker per step, his report); the first pane after entering Quick loads at once, in place (no body fade: the growing
  card reveals it; card width / height on the effects curve — the spring overshot ~4 px and settled for ~0.45 s);
  `MenuHudDial` values landing in its first 0.4 s snap (gauges swept 0 → value on every Dashboard build).
  A pane builds hidden: never `forceActiveFocus()` at construction (it takes focus while invisible); `quickPaneComp` is
  null until `quickPaneKey` is set (entering Quick built the placeholder first, then swapped).
  It also sees `visibleChanged` false at build and true at the swap: no `onVisibleChanged: refresh()` in a pane (it
  would refresh on every switch). A value assigned in `Component.onCompleted` of an inline delegate animates (the
  Behavior is live): seed through a binding or gate it; `released` fires before `pressedChanged`.
  Flicker rules (2026-11-26 hunts): an animation's curve / duration / direction never binds to the state that moves the
  property (its anim is built on the first write, bindings then read stale): use `<behaviorId>.targetValue` or latch
  in `on<Target>Changed` (handlers run before bindings); a Behavior on data runs only while its window / `live` shows
  and its first value snaps (`primed`: MenuMeter, MenuSlider, Ccu ring, MenuHudDial's first 0.4 s); an Image whose
  source changes keeps the old frame (`retainWhileLoading`); ticking digits are tabular with a fixed box; bar
  animations skip the first second (`BarHost.chipAnim`, tray too); shared derived data (cover colours) lives in the
  service, not per card. Quick panes keep their last data (`LauncherWindow.paneCache`, `paneKeep` in a pane's
  `onDestruction`, `paneSeed` first in its `onCompleted`): a revisit arrives complete, the fresh read only updates
  (Temps, Battery — first % from the macsmc sysfs capacity, UPower read ~4 % off —, Backup from `tmStatus`, Displays,
  Hardware, Network LAN); lines that wait for data stay laid out with " "; `MenuFadeText` snaps while hidden. Left: rows built when data
  lands (Temps / Servers 50–85 ms, Hardware 30–50 ms).
  Polish 3 (2026-11-24, refs caelestia / end-4 / Gren-95 / surface-dots; sheets `~/screenshots/quickshell-all-windows-
  2026-11-24.png`, `…-polish3-…`): **optical size** — Adwaita Sans is variable (`opsz` 14–32, Inter Display at 32) and
  Qt draws every size with the 14 cut; big readouts / titles take `font.variableAxes: Style.opsz(<size expr>)` (never
  `font.pixelSize`: binding loop). Selection pills (launcher results, Quick rail) = `Menu.MenuStretchPill`: leading
  edge on the spring, trailing 1.5× (stretches toward the target). `MenuSwitch` handle 10 off / 14 on / 16 held;
  `MenuPill` / `MenuChip` / `MenuIconBtn` square off while held (radius `menuRadiusSm` / Md). Scrollbars hide at rest
  (show while scrolling / hovered, fade 0.6 s after); lists without `MenuEdgeFade` set `autoHide: false`.
  `MenuFadeText` rises 3 px with its fade. Battery: the launcher caret blinks by Timer (a looping sine fade kept the
  animation driver running while the launcher sat open), `WavySeekBar` repaints at 30 fps, SysPanel history = `Shape`
  `PathPolyline` + gradient fill (no Canvas raster per sample). Tried and dropped: hiding the empty LAN card (the
  Wi-Fi card then stretched with an empty half). His picks from the ideas sheet (`~/screenshots/quickshell-ideas-
  2026-11-24.png`; declined: per-process net, reading-mode shader, Material Symbols): `MediaCard.accent` from the cover
  (`ColorQuantizer` depth 2, once per track in `Services.Players.artColors` for every card, most vivid of 4, HSL lightness 0.72 dark / 0.34 light; theme accent without art); lock
  password dots spring in, accent → ink (fixed 24-slot Repeater: a count model rebuilt every dot on each key);
  `Menu.MenuRipple` on pill / chip / icon button (declared under the label; built only while it runs); **hold to
  confirm** on `confirm` rows (Enter, keypad Enter or the pointer, 1.2 s; early release drains and says "Hold to
  confirm"; Ctrl+L still takes the old two-press arm); Clipboard kind chips (All / Text / Links / Code / Paths /
  Colours / Images, counts; "All" holds the total) + per-kind glyph + colour swatch (Qt parses no `rgb()` / `hsl()`
  strings, and CSS `#rrggbbaa` is Qt `#aarrggbb`); OSD speaker glyph by level, display sun turns 0–180° and grows.
  Harness copies patch the System rows to `exec: "true <verb>"` so a hold can never restart the Mac.
  Pass 5 (2026-11-25, his picks, sheets `~/screenshots/quickshell-pass5-*`): **look knobs** `Style.uiScale` (type tokens,
  launcher geometry `launcherLayout({ look })`, menu widgets' `fontScale` default) / `radiusScale` (menu radii, Full stays) /
  `motionScale` / `fontFeatures` + the three families, live from an optional `~/.config/asahi/look.json` (`ASAHI_LOOK` path;
  no file / not an object = defaults; `Style.knob` clamps uiScale 0.5–2, radiusScale 0.25–3, motionScale 0.25–4, and
  `MenuSpring` stops at 0.75: a stiffer spring overshoots at its damping, a tiny one never settled); tokens `typeHeadline 16`, `typeHero 28`, `menuRadiusXs 4`. **Concentric radii** `Style.inset(outer,
  pad)` = max(Sm, outer − pad): launcher 28 → pane cards / heroes / gauges `menuPaneRadius` 16 → nested 12 → rows
  `menuRowRadius` 8 (a thumb / tile in a row ≤ 8); results, rail pill, calc legend `menuSelRadius` 12. Pane metrics
  `menuHeroPad 14` / `menuHeroGap 16` / `menuCardPad 12` (Hardware + Servers keep their tight hero: 767 × 636, no scroll).
  Lists: `LauncherWindow.listSlot` (one leading slot) / `listRowH`, values right-aligned tabular with `Layout.minimumWidth`
  (preferredWidth elided "100%"); clipboard image rows keep the thumbnail first (his pick). Pane fields `fieldH` / `fieldHSm`
  (= `Style.fieldHeight 40` / `fieldHeightSm 30` on the laptop, scaled on the 4K); one focus ring (`focusRing`, width 2).
  Popups `popupPad 14` / `popupGap 12`, header `MenuGlyphTile` + DemiBold title (usage stays "AGENT USAGE": his call;
  RecordPanel's tile turns solid red while recording). `MenuDivider` = one device px (Item + 1/dpr line), `hairline(dpr)`, `rim(dpr)` (dark card rim),
  no `menuSep`; OSD border `popupBorder`. Widgets: `MenuCaption` (panes pass `fontPx(8)`), `MenuMeter` (4 px,
  value eases, width snaps, never grows from 0), `MenuSegmented` (one stretching handle), `MenuBadge`, `MenuKeycap` (Keys
  overview, two-tone modifiers), `MenuRunner` (2 px, only busy && visible), `MenuEmptyState { quiet }`, `MenuGlyph` (ink
  height, tile × `glyphRatio` 0.6) only on off-ratio tiles (Packages, toast fallback, now playing, empty disc, Writing /
  Lookup; launcher rows, rail, Dashboard, hero tiles keep their glyphs). `menuSpringFast` (350 ms, `MenuAnim { fast }`):
  switch edges stretch + height eases + hover layer, no check mark. `MenuSlider`: one eased `pos` (drag 1:1), wheel 1/20,
  ←/→ once the pointer moved over it (a pane built under a resting pointer took the rail's ←), ±10 px hit, `detents`; `fontScale` 4/3 = popup size. Tooltips 470 ms, warm 600 ms (`tooltip_warm.js`).
  Review fixes (2026-11-26): `MenuSlider.wheelSteps: false` inside scrolling lists (Media streams, HID++: the wheel
  scrolled their values); `MenuMeter`'s first value snaps (`primed`: data landing after the build grew bars from 0);
  `MenuRunner` sweeps only while its window shows; a component's own `value` shadows the owner's (SysPanel tiles:
  qualify by id). Round 3: `MenuMeter` eases only while its window shows (SysPanel tiles ticked every 3 s on every
  bar); `MenuStretchPill` latches its direction on `targetTop` change and `MenuSwitch` on `checked` change (a
  binding on the edges read stale at a move's start: they stretched once only); `MenuSlider.stepSize` (BT DPI choices:
  1 / (n − 1)), a `detents` step lands on the 5 % grid; `MenuSpring` epsilon 0.25 (no sub-pixel tail).
  `MenuScrollBar.overflow` is synced after `size` settles (`Qt.callLater`) and the launcher's `resultCount` is written
  deferred: bound, both looped while leaving Windows / Files mode (rows kept a 9 px scrollbar reserve). Window
  inspector: a failed capture drops the ScreencopyView context (0.2.1); no frame yet → the source is re-set once. Motion (his picks, M3 / M4): pill / chip / icon-button press on `MenuAnim { fast }`; lock dots: each 18 px slot grows /
  closes on the fast spring (the row glides, a deleted dot shrinks + fades; demo IPC `lock state add|del`);
  `Menu.MenuSpring` (velocity-keeping `SpringAnimation`, overdamped) on the selection pill edges and the OSD fill
  (stiffened in the 2026-11-26 motion review). Dark weights `wghtBody / wghtTitle` (variableAxes 450 / 550, dark only, never on StyledText). Bold → DemiBold; pill / chip
  `numeric` = tnum. Workspaces: capsule edges stretch (B1), static urgent dot (B2,
  `HyprlandWorkspace.urgent`, a qs restart forgets it). Declined: all of L13 (shadows),
  rim, mono-accent, instrument OSD, scope graphs, decode text, corner marks, lifetime line, selection tick, slider looks.
- **Round 4 features** (2026-11-25, his picks from the reference survey; sheet `~/screenshots/quickshell-round4-2026-11-25.png`):
  night light chip click = `NightLightPanel` (warmth slider 1000–6000 K in 250 K steps, `asahi-nightlight set <K>` 300 ms
  after the last move, presets, Off; right-click = off; the light going off while it is open (right-click, CLI) clears
  `openPanel` (else the next light-on popped it open, grab and all); QML reads `ASAHI_NIGHTLIGHT_STATE` like the script).
  `Osd.mode()` cards for night light / stay awake / DND on-off (3 s settle; temperature changes stay quiet). Timed DND:
  `NotificationCenter.dndUntil` (epoch ms, in the history file, one Timer to the deadline; ran out while away = off on
  load), `:dnd 30m|2h|8:00|off` rows (the deadline is re-checked every 30 s: Qt timers stand still through s2idle) (`ArgCommands.parseDnd`), IPC `dndFor`, "until HH:mm" in the sheet. Pinned apps:
  `~/.local/state/asahi/launcher-pins` (desktop ids), right-click a launcher app row or a grid cell; pinned lead Apps and
  the grid and win search ties. Foreign notification daemon: `busctl --user status org.freedesktop.Notifications` 5 s
  after start and on each sheet open → red banner + "Take over" (kill it, `asahi-restart-quickshell`); `asahi-debug`
  `check_notifications`. Battery chip `surge()` once per plug-in (UPower `onBattery` → false, 3 s settle). Windows mode
  (`,`) side card `Panes.WindowInspector`: one `ScreencopyView.captureFrame()` per selection (never live; inside a
  `ClippingRectangle` reference the rect by id — children sit in its content item, `parent.aspect` was undefined → 0
  size), facts, move / float / pin / close via `hl.dsp.window.*({ …, window = "address:0x…" })` (Quickshell's
  `address` has no 0x). SysPanel I/O tile: `/proc/net/dev` (wl / en / eth only: a tunnel counts twice) + `/proc/diskstats`
  (whole disks) every 2 s while open, mirrored `Shape` graphs (sqrt scale), history per open. Pre-shutdown warnings:
  `asahi-session check` (package manager, partial downloads < 2 min old, wf-recorder, restic, live Claude markers) → one
  red row above the power rows (launcher open, System, hold start). `System.NowPlayingCard`: once per track while playing
  (Apple Music only, his call 2026-11-26: browsers / video do not announce; 5 s settle; not while the launcher is open or over fullscreen), Actions › "Now-playing card" (`now-playing-card` flag).
  Servers pane: speaker protection (`speakersafetyd` / `speakerguardd*`) is never stopped or restarted (`asahi-servers`
  refuses; buttons off). Claude hold gives way below 20 % discharging (`battery_low`; `ASAHI_BATTERY_DIR` in tests); the
  bar cup shows it dim amber without a tooltip (bar rule). Display prompt pings use `qs ipc --any-display` (the
  autostarted instance's display reads `unk`: plain `qs -c remix ipc` finds no instance from scripts).
  Follow-ups (2026-11-25): `asahi-nightlight` rewrites `nightlight.json` in place (truncate, write) — every reader
  (StatusIndicators, Launcher, Osd) keeps its last state on an empty / cut-short read (as "off" it hid the chip, closed
  the popup and flashed Off / K cards on each slider step: the flicker). Window inspector = bindings.lua's window
  actions aimed at that window (`hl.dsp.window.*({ …, window = "address:0x…" })`, all verified nested): Float (60 % of
  its display, centred — floated at tile size it came out huge), Pin / Center (floating), Pseudo, Opaque, Group / Leave
  group, Maximize / Fullscreen / In tile, PiP and Pop (focus first: the scripts act on the focused window), move to a
  workspace / display; title-row icons Focus, Screenshot (`ASAHI_SHOT_GEOMETRY` skips the pick; on-screen windows
  only), New window, Close / Kill (second click within 3 s; the subtitle asks); facts with `ps` memory / age /
  command (click copies). Fits the pane without scrolling. Network rows / card: filled 󰋼 (the outline one read as a speck).
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
  leading `*`/`/`/`^` continues it. Units (`=10 km to mi`, `in` / `to` / `->`; length, mass, time, data, speed,
  volume, energy, °C/°F/K): `convert()`, 6 significant digits, copies the number; no qalc (not installed), no
  currency (needs a fetch). History in `~/.local/state/asahi/calc-history.json`. Legend = `CalcHist.LEGEND`.
- **Launcher search**: name tiers exact > prefix > word start > anywhere (`primaryScore`, omarchy AppSearch), then
  score, usage, shorter name. Windows mode = `,` prefix / "Windows" nav row: `Hyprland.toplevels`, most recent first
  (`focusHistoryID`, `refreshToplevels()` on entry), Enter = `hl.dsp.focus({ window = "address:0x…" })`.
  `Terminal=true` entries (btop, htop, nvim, cliamp) launch through `asahi-launch-tui` (they started windowless before),
  which runs the command through `$SHELL -ic 'exec "$@"'` inside Ghostty (`-e` passes argv as is): the interactive
  zshrc's environment, like a terminal window — `~/.local.zsh` holds API keys / PATH additions (nvim's parrot.nvim
  died on a missing `ANTHROPIC_API_KEY`); ~0.3 s. Linked into `~/.local/bin` for `asahi-nvim.desktop`.
  Desktop-entry actions are rows for typed queries (a `Terminal=true` app's actions run in Ghostty too: a
  DesktopAction has no `runInTerminal`, the app's counts) ("New Private Window · Firefox", `special: "app-action"`, usage -1
  like actions; idea: Ryoku / end-4); Actions › "App actions in search" switches them off / on, kept in
  `~/.local/state/asahi/launcher-app-actions` (`on` / `off`, missing = on). Typo rescue: a 4+ letter term one edit from a title word (`Data.oneEdit`, lowest
  score). `>` alone lists recent files (`asahi-recent-files`: recently-used.xbel, newest first, gone files skipped,
  XML entities decoded before the %-escapes — "Peace &amp; Love.mp3" read as gone;
  ~70 ms per open); Shift+Enter on a file row = show in folder (`asahi-reveal`: FileManager1.ShowItems → Thunar selects
  it, else the folder; also the Screenshots tiles' folder button and the screenshot / recording cards).
- **Recorder**: Screen audio = RecordPanel's System / Mic / Silent pill (idle only), saved as one word in
  `~/.local/state/asahi/record-audio` (`system|mic|none`, default system; `Recorder` FileView, no polling).
  `asahi-cmd-record` reads it, so keybinds follow: system = default sink's monitor, mic = default source (narrated
  demos), none = no audio (one device only: wf-recorder). Webcam and camera-only takes always record the mic.
  Panel tiles start the take once the card has left (`startAfterClose`, exit + 150 ms; the card takes no clicks while
  it leaves): started at once, the first frames caught the fading card and a second click stopped the new take.
  Super+Alt+R toggles `RecordPanel`; REC chip only while recording (click = panel, right-click = stop).
  `Recorder` singleton runs `asahi-cmd-record status --json` at start, on the script's `ipc call recording refresh`,
  1 s while recording; idle nothing polls. Webcam and camera-only takes record default source; screen takes default
  sink's monitor (wf-recorder: one device; camera-only = ffmpeg). No pause (wf-recorder exits on SIGUSR1). Stop = SIGINT, SIGKILL only after 15 s (MP4
  index written last), then detached `asahi-cmd-record finish <file>` (omarchy; stop clears the file marker: a later
  stop of a foreign wf-recorder (`pgrep` fallback) finished the old take again): unreadable file → critical card; else
  audio's first 0.4 s muted + loudnorm -14 LUFS (AAC 48k: loudnorm runs at 192k), video copied (no 0.1 s trim: needs a
  re-encode); card with a thumbnail (the gallery's `~/.cache/asahi/video-thumbs/<file>.jpg`: survives a reboot for the history
  card, the gallery reuses it), click opens. IPC:
  `qs -c remix ipc call recording panel`.
- **Packages**: `PkgManager.qml` over `asahi-pkg` (dnf5 JSON). Update checks run `dnf check-update` **without**
  `--cacheonly` (as user it read days-old `~/.cache/libdnf5`); offline (exit 1) → `--cacheonly`. Rows under
  "Obsoleting packages" are not updates. New query first stops a busy one (`running = true` on a busy Process delivers
  old rows). quickshell excluded on lionheartp copr (`dnf.sh` setopt; Upgrade all installed its build). Install /
  remove / upgrade: Ghostty via `asahi-launch-tui`, `ASAHI_TUI_WAIT=1` (`--wait-after-command`: result stays
  readable). Crashing query still prints `{error, packages: []}` (EXIT trap). Test: `asahi/bin/asahi_pkg_test.sh`.
  `dnf.sh` brings node + luac (for `make test-asahi`). After an upgrade (tui-upgrade,
  tui-flatpak-update, the `update` autoload) `qs ipc call updates refresh` re-checks at once (the icon stayed lit up to
  30 min). Flatpaks (idea: hyprconf): `updates` appends `flatpak
  remote-ls --updates` rows (`source: flatpak`, offline `--cached`), the bar's 30-min check counts them, the pane
  sends Flatpak rows to `tui-flatpak-update` and Upgrade all runs `flatpak update` after dnf. Grok Bot = Cursor's AppImage feed (`grokbot.sh`; icons linked
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
  the window's first buffer has it). Why: nothing presents while the lock holds the session, unlock shows what was on
  screen when the lock engaged; the cover makes that frame 0 whatever the decoder holds. `play` runs from
  `onMediaStatusChanged` (`kick`), never from a `ready` binding: that binding looped, Qt dropped it, and `pause()`
  on the new source held the cover on frame 0 (2026-11-09, switching wallpapers). The kick is deferred
  (`Qt.callLater`): `setSource()` first stops the old clip (Loaded + Stopped at 0, `go` still true), a kick inside it
  `play()`s the clip being replaced, `playbackState` stays Playing and the next clip never starts — frame 0 held until
  the failsafe on every wallpaper change after a finished intro or during one (2026-11-10; offscreen harness:
  `qml` + `QT_QPA_PLATFORM=offscreen` around the verbatim player block; unlock was fine, the hold's `pause()` resyncs). The flash he saw (2026-11-09)
  was the old hyprlock's grey fade-out + a late `play`; a stale-buffer flash did not reproduce nested.
  `asahi-lock`: `wallpaperIntro arm` → polls `ready` (each output swapped the cover twice:
  `cover.Window.window` `frameSwapped`; ≤ ~0.4 s; each call under `timeout 1`: a hung qs
  must not stop the lock) → the lock → `play` on its `Unlocked, exiting!` line (printed when PAM says yes, before the
  lift-off), again at its exit (no-op: once per arm, `played`); go after `unlockDelayMs` 400, so the clip starts
  moving while the lock lifts off its first frame.
  `FrameAnimation` is no "window rendered" signal (the animation driver falls back to a timer). 15 s failsafe ends a
  stalled clip (a held arm has none: `asahi-lock`'s EXIT trap calls `play` on every exit — unlock, out of retries,
  the TTY escape's pkill). `ready` live 2026-11-10: false, false, true ~220 ms after `arm` (the cover png loads
  synchronously; no cover = no wait); a static cover swaps once per `update()`, so `onFrameSwapped` asks for the second
  (a re-arm of a held cover stayed not ready for all 10 polls).
  qs log: `intro: arm` / `play` / `video on <output>`. IPC via `qs -c remix ipc --any-display`
  (Hyprland-spawned callers lack the shell's `QT_QPA_PLATFORM`). Triggers: login once per boot
  (`$XDG_RUNTIME_DIR/asahi-wallpaper-intro-boot`), `WallpaperService.wallpaperSet` (picker, Super+B), every unlock.
  The lock's background = `lock-screen` link → the clip's first frame (`WallpaperService.linkLockScreen`; the still
  without a clip), so unlock plays forward (eyes open). **Animated wallpapers only** (2026-11-09): `~/Pictures/wallpaper`
  = omarchy's theme intros (minus lumon, retro-82: 16)' end stills (`<theme>-<bg>`) + `intros/<theme>-<stem>.mp4`,
  fetched by `comp_asahi_wallpapers`; the old still collection (mylinuxforwork checkout) was moved once to
  `~/Pictures/wallpaper-backup`. Picker centre window loops its clip muted only while the picker is shown
  (`WallpaperCarousel` `Video`, `playing`: hidden, it kept decoding at ~50 % of a core; `WallpaperService.introClip`).
  Decode is software (QtMultimedia → ffmpeg-free: H.264 via OpenH264, VP9, AV1);
  ffmpeg-free cannot *encode* H.264 (`libopenh264` can). No clip = nothing happens. qs hot reload missed a replaced
  file once (2026-11-09): restart qs (Super+Ctrl+Alt+W) when a change does not show.
  **Rejected 2026-11-18** (built and taken out the same day, his words: "do not play video over my windows", "no
  blurred background"): an unlock mode with the clip on the Overlay layer above windows and bar (windows dissolving
  into it at lock, click to skip, the desktop opening out of its end in a soft circle from the Touch ID orb, or out
  of a blur into a frosted desktop) and a blurred / saturated first frame as the lock's background. The intro is the
  desktop background on unlock exactly as on a fresh wallpaper pick: Bottom layer, behind the windows; the lock shows
  the sharp first frame.
- **Wallpaper span** (idea: omarchy-wallpaper-cutter): `asahi-wallpaper-span` cuts the wallpaper across the live
  layout (logical px; slices in `~/.cache/asahi/wallpaper-span/`, only live set kept). Bezel `gap`: one value, all
  seams. EDID mm unused (LG reports 700x400). hyprpaper keeps per-monitor entries over the `,path` wildcard — every set
  (`apply` / `sync`) names each output; all `WallpaperService` desktop sets go through the script. `sync` (no-op, no
  state write if already shown) runs on `WallpaperService.screenLayout` changes, shell start, after Super+Ctrl+Alt+P
  (hyprpaper starts on `~/.local/state/asahi/lock-wallpaper`; no slideshow). One output: no cut, `outputs` cleared.
  Slices written to `.tmp`, renamed. Span switch in Monitors pane. Picker previews stay uncut. Test:
  `asahi/bin/asahi_wallpaper_span_test.py`.
- **Autotheme**: Hyprland has no portal Settings — `portals.conf` pins Settings to gtk. Flavours
  `source content vibrant calm mono` + by hue `expressive warm cool pastel` (`FLAVORS` = source of truth; saturation = fraction of gamut room, never a
  multiplier). ANSI / named colors stay in their hue family (`HUES`, `_family_hue`; red/orange lean less: critical vs
  warning); text ladders WCAG (subtext0 ≥ 4.5:1 on base, text on accent = crust). Bare run keeps saved flavour
  (colors.json `variant`), prefers `quickshell/wallpaper.conf`; runs hold `asahi-theme/.lock`. Writes
  `~/.local/state/asahi-theme/`. GTK ini is a real file, not a symlink. Unset portal `0` = light. Live: Ghostty
  `reload-config`, Quickshell `FileView`, Hyprland borders, btop SIGUSR2, Firefox, Claude Code
  (`~/.claude/themes/asahi.json`, omarchy's 38-role template, hot-reloaded; picked once per machine with `/theme` →
  custom:asahi: settings.json is never written, his is shared with macOS via Nextcloud). **GTK3 never repaints live** — do
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
  defaults the Aurora kernel lacks (unprivileged BPF off, `legacy_tiocsti` 0). `90-asahi-inotify.conf`:
  `max_user_instances` 128 → 1024 (49 in use; running out takes the session D-Bus down; idea: Gren-95). AsahiLocker's `luks-fetch-cache.timer`
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
  never written on load; holds Do Not Disturb (a QML save reloads qs). History cards cut at 3 lines get "more" / "less"
  (idea: Ryoku). The sound honours the spec's `suppress-sound` hint (Signal / Telegram play their own; the card still
  shows). Trash = two clicks within 3 s (stray click wiped
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
  Logout / Restart / Shutdown: `confirm: true` (Data.js), second Enter within 3 s runs; they (and Restart into macOS)
  go through `asahi-session logout|reboot|reboot-macos|poweroff` (reboot-macos arms the one-shot macOS boot,
  `pkexec asahi-bless --set-boot-macos --next`, only once the windows are gone: armed first, a cancelled reboot left it
  set and the next reboot landed in macOS; a dismissed polkit prompt or a refused reboot / poweroff ends in a
  critical card — the windows are closed by then): every window closed first, ≤ 8 s wait, so apps save their state
  (Logout was `hl.dsp.exit()` straight away); one left open (an unsaved-changes dialog) cancels with a card naming it
  (idea: omarchy-system; test `asahi_session_test.sh`). The OSD also shows any default-sink volume / mute change from
  elsewhere (headset buttons, apps, the bar wheel; `Osd.qml` bound to `Pipewire.defaultAudioSink`, a new sink only
  sets the baseline, taken once the node is `ready` — before binding it reads volume 0 and the real value arriving
  showed a card at every shell start / output switch; a device route's volume (headphones, HDMI, BT) can come after
  `ready`, so a sink's first 1.5 s only move the baseline; quiet while the launcher is open; keys still ask over IPC for feedback at 0 / 100 %).
- **Audio**: Aurora ships the stack (`aurora-audio`, keeps the `/usr/share/asahi-audio` paths) — don't port omarchy's
  Apple audio.sh. RT check is the **thread**: `ps -eLo comm,rtprio,cls | grep data-loop` → `20 RR`. Mic
  `effect_output.j414-mic` is MONO since aurora-audio 4.1-5 (old asahi-audio: 1ch `AUX0`, stereo recorders left only;
  our relabel filter `asahi-mic.conf` / `asahi_mic` is gone, the installer drops its link). Never override the audio
  package's node scripts (a `software-dsp.lua` overlay hung WirePlumber). The unplugged "Built-in Audio Headphones"
  sink is always listed (never default: no available route). speakersafetyd restarts "hot" (Aurora
  `50-aurora-warm-restart.conf`: attenuated until its model cools). 96 kHz playback can lock speakersafetyd
  (`Speaker volumes locked`): `sudo systemctl reset-failed speakersafetyd && sudo systemctl start speakersafetyd`.
- **Trackpad clicks** (haptics): Aurora plays the click from the host (`hid_magicmouse haptic_press`, set to `Y` by
  `64-aurora-trackpad-clicks.rules` on add / bind only). A click during an aborted suspend entry fails its waveform
  with `-16`; the driver then logs `click waveform failed (-16); returning click feedback to the firmware`, flips
  `haptic_press` to `N` and nothing turns it back on (2026-11-18 12:18: the click felt dead / different until
  re-armed). Check `cat /sys/module/hid_magicmouse/parameters/haptic_press`, `journalctl -k | grep magicmouse`; re-arm
  `echo Y | sudo tee /sys/module/hid_magicmouse/parameters/haptic_press` (or reboot). No guard of ours yet (would be a
  root system-sleep hook writing `Y` after every resume).
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
  `Menu.MenuChip` labels too (the keep-awake chips name inhibiting apps). Only exception: the notification body (StyledText from `NotificationModel.richBody`, an allowlist; `href` written raw:
  StyledText keeps `&amp;` in it).
- **Quickshell launch**: never `qs -d` (EPIPE/`qFatal` if the parent is gone); `setsid -f qs -n -c <module>`
  (`asahi-restart-quickshell`: kills every qs **but the lock** — `pkill -x qs` killed a running lock screen; its guard
  relocked). Bar vanished → `asahi-debug` coredumps first. qs reloads on save (log
  `/run/user/$UID/quickshell/by-pid/<pid>/log.log`). `grim` blocks on a DPMS-off output — always `timeout`. zprofile
  unsets Lmod's `BASH_ENV` (13 → 1.2 ms per bash).
- **Polkit**: `modules/system/PolkitAgent.qml` (Quickshell `PolkitAgent`) is the agent (else pkexec / GUI admin
  prompts fail silently); one card on the focused screen, laid out like the lock screen: the Touch ID orb + its line
  over the password pill. PAM asks for the finger first (system-auth: `pam_fprintd` sufficient before `pam_unix` for
  sudo / polkit-1; 3 tries / 30 s), only then the password: until `isResponseRequired` the pill is dim and the orb
  tells what happens; then the orb is a lock, "Type your password". PAM's own fingerprint lines show only while the
  orb has nothing to say.
- **Touch ID (Aurora)**: `apple_sep` module (loaded by `aurora-sep.timer` once root is up) + Aurora libfprint / fprintd
  on `/dev/sep-bio`; needs current Stage 2 DTBs (see Aurora boot chain). `make aurora` runs `comp_asahi_touchid`
  (`./install.sh asahi-touchid`; after the desktop, before doctor: its failures exit 1 and must not block the
  desktop): `sudo aurora-touchid-setup` (per-Mac calibration from the iBoot System Container,
  idempotent), authselect `with-fingerprint`, and `fprintd-enroll -f right-index-finger $USER` on a tty when no finger
  is enrolled; skips (warns) before the reboot onto Aurora DTBs and on Macs without a sensor node. Also installs +
  enables `aurora-fido` (Touch ID as a FIDO2 key: passkeys / WebAuthn, `ssh-keygen -t ecdsa-sk`; pam_u2f would work, not installed;
  only with `/dev/sep-key`: 0.2.0 (2026-11-11) dropped the `sealed` store, enable refuses and a running unit restart-loops
  without it, so the installer disables it there; `aurora-fido status`, `sudo aurora-fido disable [--forget]`).
  `pam_aurora_touchid` (system-auth) re-arms Touch ID after a password; `/etc/aurora/touchid.conf`
  `require_password_after_boot` (password before the first Touch ID, `aurora-touchid-boot`) needs the kernel's Touch ID
  wait ioctl: this kernel has none, so Touch ID works from the first login.
  `aurora-sep-ready` turns on authselect `with-fingerprint` (Aurora's vendor `local` profile: sudo, polkit and
  `fingerprint-auth` only; tty1 `login` stays password = keyring unlock).
  The lock runs its own `fingerprint` PAM (`quickshell/lockpam`); the polkit card shows
  PAM's finger prompt (`supplementaryMessage`). Diagnose `aurora-xart status`, `journalctl -u aurora-sep -u
  aurora-sep-ready`; start over `sudo aurora-xart reset-touchid`, reboot, enrol again (it refuses while the keybag works; also after a root
  rollback or reinstall: they bring back an
  older / empty xART owner list, `/var/lib/aurora-sep-xart-owned.bin`, and the guard refuses the Linux records;
  `/usr/share/doc/aurora-sep/XART-SAFETY.md`). Risk (omarchy-mac manual 04-security): the SEP anti-replay state is shared
  with macOS; written wrongly, FileVault macOS cannot unlock → DFU restore (erases); xART guard 1 (M2 default) refuses
  macOS's records (`xart_guard_refusals`, Hardware pane); README tells him to keep a macOS backup. No fprintd restart on
  resume (omarchy's `system-sleep/fprintd-resume`): Aurora's fprintd handles sleep itself, and Aurora's libfprint
  removes the reader while the lid is closed (`Lid closed; removing …`): the lock's fingerprint PAM fails then and is
  re-armed every 5 s until the reader is back.
  **Wedged fprintd** (2026-11-09 13:38 → dead for a day, silently): power key (= the sensor, pressed instead of
  touched) during a polkit / sudo finger prompt → suspend mid-verify → pam_fprintd's Release fails "still busy" →
  fprintd drops the claim but keeps the reader open → every Claim: `Open failed … already been opened` (lock, sudo,
  polkit; `fprintd-verify` shows it). Only a restart clears it: the lock restarts fprintd once after a failed fingerprint run
  (`asahi/polkit/49-asahi-fprintd-restart.rules`, installed by `asahi-touchid`: wheel may restart `fprintd.service`)
  and claims afresh on its next try.
- **Touch ID prompt** (idea: omarchnix's touchid plugin): `modules/system/TouchIdPrompt.qml` = a card under the notch
  while something waits for a finger without a prompt of its own (sudo / su in a terminal, `aurora-fido`: passkeys and
  ssh `ecdsa-sk`, `fprintd-verify`). It and the polkit card show **the lock screen's orb** (2026-11-18, his ask: the
  same display when approving things unlocked): `TouchIdOrb.qml` (glass disc with a hairline ring and the glyph in the
  state's colour; solid disc + `Style.menuOnAccent` glyph once something happens, like the lock's; no glow, no bold
  ring; phases ready / reading / nomatch / retry / match / failed / off) and `TouchIdLine.qml` (bold part in the
  state's tone, muted hint). **Animated here** (2026-11-19, his ask: "Reading", "Approved" etc. in the notch card), as
  the lock screen cannot be: the glyph breathes while it waits; while the finger is read a quarter arc runs round
  inside the rim (`RotationAnimator`, `Shape.CurveRenderer`) and three dots carry a wave; every result lands with a
  pop (disc from 0.86, the new glyph — check, crossed fingerprint — grows in from 0.5, `OutBack`); each new line
  rises in; the card drops out of the notch (and back up), a miss shakes it. Each colour eases once, straight to its
  target (easing the disc toward an easing ink lagged a miss by 0.2 s). Loops run only while `live` (the card is
  shown; test). The model's timer is set per state and aimed 20 ms past `until`: a QML Timer fires up to a frame
  early (seen 24 ms), and with an interval binding the state then outlived its time by a whole period (No match
  2.8 s, the next touch showed no "Reading"). **Real fprintd semantics** (2026-11-19, his report: "no animations whatsoever" on real touches while the IPC feed
  showed them): the model ended a read when `finger-needed` went false, and some drivers drop it as the finger
  lands → Reading for 0 ms, the card gone 450 ms later, the match after it (ignored). Now: a lift or a dropped
  "needed" never ends a read (6 s cap: fprintd sends no lift); a no-match is always `done` and fprintd
  reports a cancelled verify (sudo's Ctrl+C) as one too → a miss only with a finger down (`finger` follows
  `finger-present` in any phase), else the card just goes; after a miss, pam_fprintd's next `start` marks
  `retried` → back to ready, none → "No match · type your password". The card shakes once per miss. Replay test:
  realistic streams in `touchid_model_test.js`. Preview: a copy of `remix/` in `/tmp` + a root with the real
  `TouchIdPrompt` fed a scripted sequence (`card.feed(...)` from a Timer), in a nested Hyprland, `wf-recorder -g` +
  `ffmpeg -vf fps=30` frames. Colours = `Style.vivid` / `vivid2` = the lock's
  accent pair, carried in colors.json (`lock_accent`, `lock_accent2`: `colors_dict`, also in the `--preview`
  JSON; fallback accent / pink). Wording = the lock's (`touchid_model.js` `view()` here, `lock.qml`'s `lock.touch` there: two copies, keep
  them alike): "Touch ID ready", "Reading", "No match · touch again"
  (red), "Not read · touch again" (amber, phase `retry`: no shake), "<why> · type your password" with a crossed
  fingerprint once fprintd gave up (No match / Touch ID locked: red; disconnected / unavailable / password needed:
  amber), "Approved" (green check). Lock screen and polkit draw their own (`suppress`: the `qs -p …/remix/lock.qml`
  process / a `polkit-agent-he*` process alive): the notch card stays hidden (`visible()`), but the state still runs —
  `PolkitAgent` reads it (`touchId: touchIdCard` in shell.qml, kind `polkit`) for its own orb. Feed:
  `asahi-touchid-monitor` (stdlib + gi, `setpriv --pdeathsig`): fprintd's
  device signals are broadcast in 1.94.5 (`g_signal_emit` on the skeleton; upstream master sends them to the claiming client only — an fprintd update would leave the card blind) (`VerifyFingerSelected` = start per try, `finger-present`, `finger-needed`; `VerifyStatus` goes out at once, the properties *after* it from an idle), who asked is guessed from /proc at start (newest own sudo, its terminal's Hyprland window: click
  focuses it; fido: newest ssh / git < 120 s). aurora-fidod's own notification (app name `Touch ID`, "Touch ID to sign in
  to <site>", closed when the request ends) is routed by `NotificationCenter` into the card (no toast / history /
  sound; tracked, else freed at once). State machine `touchid_model.js` (`touchid_model_test.js`, also the wiring;
  monitor: `asahi_touchid_monitor_test.py`). Preview: `qs -c remix ipc --any-display call touchid feed '<event json>'`
  (nested: a root with `TouchIdPrompt` + a copy of `PolkitAgent.qml` whose `PolkitAgent {}` is a fake `QtObject` agent /
  flow — a second polkit agent cannot register; no IPC function named `show`: `qs ipc call` takes it for its own
  subcommand). Never test with a killed `fprintd-verify`: fprintd reported that as `verify-no-match` (may count toward
  the SEP lockout).
- **SSH on Touch ID** (2026-11-11, his pick): `asahi-touchid-ssh` makes `~/.ssh/id_ecdsa_sk` (aurora-fido, one touch,
  no passphrase, not resident: no PIN). `setup HOST…` = create + `authorize` (appends the pubkey over the old key,
  BatchMode) + `default` (Touch ID key before id_ed25519 in `Host *` of the untracked `~/.ssh/config`, backup
  `.bak-touchid`; id_ed25519 out of the running agent: the agent offers its keys first, in the order added) + `test`
  (sk only, no agent: a touch per host). `retire HOST…` drops id_ed25519 from a host's authorized_keys inside a login
  that only the Touch ID key could make. Host names / addresses live only in `~/.ssh/config` and the command line, never
  in the repo; a password / GSSAPI-only host offers no publickey at all: no key works there. id_ed25519 stays the local
  fallback (a host without the new key: passphrase via keychain as before). ForwardAgent hosts: a forwarded sign needs a
  touch here. **Dead since aurora-fido 0.2.0** (sealed store gone, 0.1 credentials refused): the 0.1 key cannot sign ("agent refused operation"); `retire` had locked id_ed25519 out of the hosts → re-add it (`ssh-copy-id`, password); `Host *` PreferredAuthentications ends in password. Kernel 7.3.0-40 has `/dev/sep-key`: new key made 2026-11-17. 0.2 reads the finger in the enclave, no fprintd verify (no monitor `start`): its note alone opens the card (`fidoNote`). A test notification with app name
  `Touch ID` lands in the card, not as a toast. Firefox (Flatpak, `devices=all`) reaches aurora-fido's hidraw (uaccess,
  `ID_SECURITY_TOKEN`; a CTAPHID INIT from inside the sandbox answers); **Proton Pass intercepts WebAuthn** (passkeys
  go to Proton, aurora-fido sees nothing): he keeps it so. `fido2-tools` (asahi-touchid) lists / deletes passkeys.
- **Stay awake**: one flag `$XDG_RUNTIME_DIR/asahi-stay-awake`, owned by `asahi-stay-awake`; hypridle listeners skip
  under it (`asahi-idle` checks `status`). **Claude Code at work** holds only idle sleep (his ask 2026-11-24: saver,
  lock, display off as usual, the agent runs on behind the lock, the lid still sleeps): Claude Code hooks in
  `~/.claude/settings.json` (shared with macOS: each guarded `[ -x …/asahi-claude-activity ] && … || true`) run
  `asahi-claude-activity` — UserPromptSubmit / Pre- / PostToolUse touch `$XDG_RUNTIME_DIR/claude-activity/<session_id>`,
  Stop / SessionEnd remove it; one untouched 15 min (crash, unanswered prompt; a Bash call caps at 10 min) is pruned.
  Only `can_sleep` asks (`status`): `off` locks + darkens, its 60 s retry sleeps once the last marker goes, no input
  needed. No logind `sleep` block inhibitor: under `LidSwitchIgnoreInhibited=no` it holds lid suspend too (and
  `asahi-clamshell`'s `lid_blocked` would blank + lock a shut lid instead). Hooks print nothing (UserPromptSubmit
  stdout joins the prompt), never exit 2 (blocks the tool). Bar: the cup in dim amber + "Claude Code working (N)"
  tooltip from `claude-activity.count` (FileView; rewritten on change, gone at 0; `status` every 5 min while it lives
  prunes a crashed session). `asahi_idle_test.sh` covers it.
  **Waiting for you** (2026-11-25, his pick; idea: Ricelin; a cup state was rejected: the cup is stay awake): `wait`
  (Notification hook, matcher `permission_prompt|idle_prompt`) writes `claude-activity.wait/<session>` and the bar's
  line `claude-activity.waiting` ("<n>\t<project>\t<window address>", gone at 0); `Ccu.qml` shows a static red ring
  round the Claude mark only (a red chip outline was tried and dropped: "looks bad"; not the ≥ 90 % wash), holds the chip rotation on Claude, hover names the
  project; a click stays the usage popup (click-to-focus the terminal was built and rejected the same day). The window
  = `hyprctl activewindow` at the last `start` (all Ghostty windows share one pid: the process tree cannot tell), used
  only so that nothing is shown while that window has the focus; every later hook of the session clears it. `status`
  checks windows only when `hyprctl clients` answers (the last window closed = `[]` drops the wait; a wait with no
  window noted stays); while one waits, the usage chip runs `status` on each Hyprland `closewindow` (no timer). Hooks are not in his settings.json yet (the classifier refuses edits there: he runs the script).
- **Idle (macOS-shaped)**: why hypridle (2026-11-23, his question): Hyprland has no idle actions of its own and logind
  sees no Wayland idle, so something must turn "no input for N minutes" into dim / lock / dark / sleep, lock before
  every sleep (and hold it until the lock is up: `inhibit_sleep = 3`), run the after-wake steps, and honour apps'
  "keep awake" (Wayland idle inhibitors and the D-Bus ScreenSaver inhibit: Chromium / calls). Nothing Apple-specific:
  omarchy-mac takes upstream omarchy's shell-side idle (screensaver 150 s, lock 300 s, the lock blanks after 30 s)
  and **never sleeps on idle** (lid / power key only); ours does (battery ~6 min idle → s2idle, measured 1.9 W over
  10 h). Kept over moving it into the shell: survives shell restarts, keeps the D-Bus inhibit and sleep hooks.
  hypridle = plain `hl.exec_cmd` in `autostart.lua`'s `hyprland.start` hook, **not**
  `hypridle.service` (its cgroup: a crash restart kills the lock / saver → lockdead; `qs ipc` matches by display
  string, session `QT_QPA_PLATFORM=wayland;xcb` → callers without it need `--any-display`). Super+Ctrl+Alt+I =
  `asahi-restart-app hypridle` (uwsm-app scope, no Restart=). `hypridle.conf` → `asahi-idle at <secs>`; step from the
  power source **at fire time** (unplug mid-idle still locks). Battery: dim + kbd 10 % 2.5 min → lock, off 5 min,
  no saver (2.5, not macOS's 2: by choice); AC: saver 3 → dim 5 → off 10 min. Backlight **not** zeroed; `off`
  suspends 60 s later. The lock surface's map fakes pointer motion (restarts every listener) → `off` ignores wakes while
  locking (`$XDG_RUNTIME_DIR/asahi-idle-locking`), set *before* stopping the saver (its unmap fakes motion too), then
  watches DPMS (`key_press_enables_dpms` → `asahi-idle wake`: stops the saver before the lid check). Dim while locked
  runs `off`. Sleep skips while Claude Code works (Stay awake), a sink carries signal
  (`pw-record -P '{ stream.capture.sink = true }'` on its monitor, else it records the mic; pre-volume: muted counts)
  or an external is on (`external_on` in `lib/common.sh`; `FALLBACK` is not one). `off`: flock single-instance
  (coalesces wake bursts), retries a refused suspend. Saver: one
  shared tick, no per-scene timers; Life's recursive source not `live`. Saver keys need `focus: true` on its Loader
  and no `focusable:` (overrides `WlrLayershell.keyboardFocus`).
  **Aurora: a key or trackpad click wakes s2idle** (dockchannel-hid wakeup source; touches don't; no lid check, logind
  re-suspends a closed lid after `HoldoffTimeoutSec`); lid, power button and, on AC, BT input
  (`asahi/udev/99-asahi-bt-wake.rules`; untested on BCM4388 — drop it on spurious wakes) too. Manual sleep
  (Super+Ctrl+Alt+S) = `asahi-idle sleep`, refused while an external is on. Log `~/.local/state/asahi/idle.log`. The first wake after a
  sleep (`sleep_mark`) checks `lock_running`: none = the session slept open → critical "Slept without the lock
  screen" card + `woke without a lock` (idea: omarchy-system-sleep-lock; needs hypridle's after_sleep_cmd). Test
  `asahi/bin/asahi_idle_test.sh` (`ASAHI_PSY_DIR`, `FAKE_LOCKED`). `asahi-idle why --json` feeds the Battery pane's
  keep-awake chips (his ask: an indicator, not a card — one small amber chip per hold at the right of the key facts;
  read on open and after a click, never polled): "<who> · show" focuses an inhibiting window, "· release" closes a
  sender's gtk-portal requests (`asahi-idle release <sender>`), "· turn off" ends stay-awake; logind blocks, Claude Code,
  external display, failed suspend and audio that plays show without an action (idea: serpantinum). A focused real
  fullscreen window (`fullscreen == 2`; not maximize / fullscreen-in-tile) skips saver, dim and off (idea: Gren-95) —
  not while locked, and on battery the off step still runs (lock, dark, sleep: his call).
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
  under a resting cursor took the selection, Enter launched it). No dock / pins / uninstall (omarchy's). Hover lifts the icon (−3 px, 1.06×) and lists the app's
  windows (≤ 3, title · workspace, `launcher.windowsOf`) under the cell, outside the grid's clip. omarchy's Super+K overview = Super+K **held**
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
- **More hardware readouts** (2026-11-20, his pick; no new polling, each rides an existing open-only read):
  `asahi-temperature` also lists macsmc `in*` / `curr*` (`volts`, `amps`) + the cpufreq cooling devices
  (`cooling`, human `Throttle:` line, `temp_display.js` parses it) → Battery SMC card "Charger Input" (PD level), Temps
  hero "CPU full clock / throttled". `asahi-cpu` "Pressure cpu X% mem Y%" (PSI avg10) and `asahi-memory` "Zram …
  (N.Nx)" → SysPanel "stall" line + swap ratio; heat tile shows the die °C. `asahi-metrics` `busy_pct` (io_ticks of
  the busiest disk) → Storage hero. `asahi-network` Bitrate "↓ rx ↑ tx". Displays: built-in only "14.2″ · 254 ppi"
  (external EDID mm lie). Hardware "Slept Thu 16:29 · −2.32 Wh". Battery hero: 24 h charge curve from UPower
  `GetHistory` (busctl JSON, one call per open) + the battery draw ("rate", state 2 only; 15-min means held as steps:
  UPower logs a rate only on change, raw points drew ramps) on its own scale, "draw ≤ N W". Running apps: `LauncherWindow.windowCount` / `isActive` over
  `ToplevelManager.toplevels` app ids → `Menu.MenuRunDots` (a dot per window, max 3; the focused app's first a 16×4
  accent pill + halo, OutBack; idea: shell-ninja/hyprconf dock) in the app grid and launcher app rows.
- **shell-ninja/hyprconf pass** (2026-11-20, his ask): auth flows grow out of the notch — `modules/system/IslandCard.qml`
  (notch-black pill the cutout's size, flush with the top edge, `grow` 0→1 on the spring lerps width / height / bottom
  radius, the surface fades over the black, content below the cutout after 55 %; closes on the exit curve; without a
  notch it starts bar-coloured) for the polkit card (dim + blur fade with it). The Touch ID card stays under the bar
  (his pick: it covered the notch bell). Their island is a floating rounded rect, ours the notch.
  Launcher prompt glyph names the mode (calculator / files / the category's icon, accent). Lock: see "Locker" (a
  notch island on the lock was built twice and rejected: nothing at the notch on the lock). Theme flavours +4 by hue (`palette.py`
  `accent_from`): expressive (≥ 50° from the dominant accent), warm (OKLCH 15–95°), cool (175–275°), pastel (+0.25
  L, −0.35 sat, tinted panels: light mode caps the accent); picked from the 12 representatives by chroma × weight^0.4,
  fallback = hue turned toward the window; neutrals turned half-way to the picked hue only within 90° (orange → blue
  half-way is magenta). Their generator is HLS bins, dark-only; ours keeps OKLCH + WCAG.
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
  replaces the desc rule; monitors.lua alone did not stick). eDP-1 too (`monitors.lua`, 2026-11-21): its EDID primaries
  are Display P3 and DCP passes values straight to the panel, so sRGB showed oversaturated; partial `hl.monitor` evals
  keep `cm`, screenshots are taken before it (unchanged), power no consistent difference. The LG here is a 27UP850
  (043e:9a39): its "LG Monitor Controls" HID is a vendor page (0xFF00), not the VESA brightness class the UltraFine
  5K/4K speak, and DCP has no DDC: no hardware brightness (omarchy PR #13887 does not apply).
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
  DCP `-22` suspend
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
- **Servers** (idea: serpantinum-kde servers panel): Quick pane `panes/ServersPane.qml` over `asahi-servers --json`
  (stdlib Python). Listening = `ss -tulnpHe`, one row per port + owner (v4 / v6, tcp / udp merged), `local` or `LAN`
  (orange: reachable from the network), LAN first. A user sees pid + name of his own sockets only; `-e` prints every
  socket's cgroup, so root daemons still map to their unit (`/proc/<pid>/cgroup` fallback). Own UDP sockets on an
  ephemeral port (`ip_local_port_range`) are client sockets (Firefox QUIC / WebRTC, wsdd): skipped. Open (`asahi-launch
  xdg-open http://localhost:<port>`, closes the launcher) for own TCP listeners reachable on loopback, root ones only on
  web ports (631 CUPS, 80 / 443 / 8080 / 8443 / 9090). Services = enabled user services (minus dbus-broker, tmpfiles) +
  every unit owning a port; one `systemctl [--user] show --timestamp=unix` per scope (since = entered its current
  state; a stamp before the boot = the clock was set by NTP after it (the RTC reads ~40 days behind at boot):
  boot + its monotonic stamp). `asahi-servers start|stop|restart user|system <unit>`: argv only, `fullmatch` on
  `[A-Za-z0-9@._:\\-]+\.service` (`\x2d` escapes pass; `re.match` + `$` let a trailing newline through);
  system units ask polkit (the shell's agent), a system Stop takes a second click within 3 s. Containers (read-only)
  only when `podman` exists. Polls every 5 s only while shown; rows are
  rebuilt only when their shape changes (state / memory looked up by key). Test `asahi/bin/asahi_servers_test.py`.
- **VPN facts** (idea: serpantinum vpn-info.sh): `asahi-vpn-info` reads locally (nmcli, `ip route get`, resolvectl,
  `ip link`) the kill switch (Proton's `pvpn-(routed-)killswitch`; `-ipv6` = leak guard, not the switch; no profile =
  not shown), full or split tunnel, DNS, MTU → one plain-text line in the VPN card. Read on open and on tunnel change,
  never polled. Test `asahi/bin/asahi_vpn_info_test.sh`.
- **Default apps**: `asahi/mimeapps.list` sends text, Markdown, JSON, YAML, TOML, Python, shell and logs to
  `asahi-nvim.desktop` (`asahi-launch-tui nvim %F`: Neovim in a Ghostty window with the shell's environment;
  `nvim.desktop` is Terminal=true and nothing runs it in a terminal); text/plain went to LibreOffice Writer before (by accident).
- **Speed test**: `asahi-speedtest [--json]` — Cloudflare 50 MB down / 25 MB up (100 MB is 403). Network pane button.
- **Wi-Fi QR**: `asahi-wifi-qr` → `$XDG_RUNTIME_DIR` mode 600; `nmcli -s` for the PSK. Code sits inside the Wi-Fi card
  (layout reserves its width; a raw width painted over the LAN card).
- **Network detail sheet** (idea: caelestia NetworkDetailPage / SavedNetworksPage): `panes/NetDetailSheet.qml`, pure
  helpers `net_detail.js` (`net_detail_test.js`). The info button on a list row / the Wi-Fi card opens it over the
  **whole pane** (the networks card is ~2 rows at rest); back / Esc closes (pane `handleEscape` first). Reads on open and
  after an edit: `nmcli -e no -t -f … connection show uuid <u>`, the cached scan (`dev wifi list --rescan no`, again when
  the pane's list changes), `ip -j link` (address ≠ `permaddr` = private MAC). Edits = `systemd-run --user --wait
  --quiet --collect nmcli connection modify uuid <u> …`, argv only: autoconnect / metered at once; IPv4 Apply only after
  a change (DHCP / DHCP + DNS = `ignore-auto-dns yes` / Manual; unused fields cleared: NM refuses a gateway without an
  address), then `nmcli connection up uuid <u>` only when active ("Applying reconnects …"). IPv6 read-only. Forget = the
  pane's (by uuid, asks twice); Share QR = the card's (active network only). Saved profiles the scan misses follow the
  list as "Other saved networks" (click = sheet). "Connected since" = `connection.timestamp` (stayed the activation time
  while up). Check modify args without touching NM: `nmcli --offline connection modify …` (keyfile on stdin / stdout).
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

