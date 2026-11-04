# Asahi Fedora (aarch64)

Loaded when a session works under `asahi/`; shared rules live in the root `CLAUDE.md`.

## Documentation
- Fedora Asahi Remix: https://asahilinux.org/fedora/
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
  Hyprland). No display manager; Super+Escape / hypridle lock.
- **Console**: `asahi/vconsole.conf` (`comp_asahi_system`): `KEYMAP="de-latin1-nodeadkeys"` (≙ `input.lua`
  `de`/`mac_nodeadkeys`), `FONT="ter-v32n"`. xkb-converted maps (`/usr/lib/kbd/keymaps/xkb/`) fail
  (`lk_add_key … keycode -1`); `mac-*` = ADB keycodes, scramble `hid_apple`. Check
  `loadkeys --mktable <name> >/dev/null`. Font here, not a setfont unit (loses to `systemd-vconsole-setup`).
- **Sleep / lid / HDMI**: s2idle only (zram is no resume image): no Hibernate row, drop-ins ignore hibernate keys;
  `systemctl suspend`. Power key: `HandlePowerKey`/`…LongPress=ignore` in
  `asahi/systemd/logind.conf.d/10-asahi-sleep.conf` (~10s hold = SMC force-reset); gsettings `power-button-action` is
  a no-op. F6 = KEY_SLEEP (tap bypassed idle guards): `autostart.lua` holds a session
  `systemd-inhibit --what=handle-suspend-key` (polkit, no root); `XF86Sleep` → Do Not Disturb.
  `./install.sh asahi-logind` also installs udev rules (HDMI lid inhibit, BT wake) + inhibit unit; HUP logind, never
  restart it; never `udevadm trigger` drm (hotplugs HDMI). `InhibitDelayMaxSec=15` = hyprlock time on lid close.
  Lid = `Apple SMC power/lid events` (`locked = true` in `monitors.lua`). Never set `HandleLidSwitch` (laptop-only =
  logind `suspend`); docked = `HandleLidSwitchDocked=ignore` + `asahi-clamshell` turns eDP-1 off. Without a lit
  external (`external_up`: Hyprland-enabled **and** DRM `enabled` or DPMS-off — 2026-11-02 an unmodeset DP-1 hotplug
  under lock left zero lit outputs; `asahi/bin/asahi_clamshell_test.sh`) close is a no-op — never DPMS-blank eDP there
  (races s2idle, `8000000a`, hangs) — unless a block inhibitor (`asahi-hdmi`: cable in, output off) stops suspend:
  wait 5 s for the external, else blank + lock.
  HDMI-A-1 / DP-1 stay `disabled = true` (`monitors.lua`) until `asahi-hdmi` enables one; logind doesn't count it docked
  → `asahi-hdmi-lid-inhibit.service` holds `handle-lid-switch` while HDMI/DP reads `connected` (udev: the **card's**
  `HOTPLUG=1`, connectors get none; `systemd-run` re-check after 3 s, sysfs `status` stale until Hyprland probes;
  start/stop, never restart: gap lets logind suspend); drop-in sets `LidSwitchIgnoreInhibited=no`. `asahi-dpms` only
  flips Hyprland-enabled outputs in the other state (redundant enable flashes).
  Hangs (laptop-only close stuck in s2idle; live HDMI plug freezing DCP: `valid_mode:0` + eDP flip, then **do not
  close the lid**): hold power ~10s, wait ~15s, tap power. `after_sleep_cmd` also runs after a refused suspend. Never
  add `asahi-hdmi sync` to resume. Diagnose `journalctl -b -1` (`Lid closed.` → `Suspending...` → `PM: suspend entry`,
  no `suspend exit`), `-t asahi-clamshell` (each lid decision + output states), `-t hyprland` (autostart's
  `/run/…/hyprland.log` mirror). Test: `asahi/bin/asahi_hdmi_test.sh`.
- **Sleep drain (AsahiLinux/linux#262)**: s2idle ~3 %/h (`slept …` in `idle.log`) = kernel floor; don't chase it in
  userspace. Gauge stale-high 30–90 s post-resume → logged ~90 s after wake minus awake draw (AC sleeps uncorrected).
  No S3 / hibernate / RTC `wakealarm`. AOP ALS wakes ~3.6/s (#638): blacklist / PM notifier no help; lid-angle stream
  unstoppable. j314s #262 hangs = out-of-tree SEP Touch ID + `fprintd` (no SEP here); ours = DCP.
- **Failed suspend**: `apple-drm … failed to suspend: error -22` ← USB-C unplug with DP-1 on: clear-swap timeout
  silently sets `dcp->crashed`, `dcp_crtc_atomic_check` rejects the disable-all until reboot (fix in
  `~/linux-fairydust`). Signature: aquamarine `Cannot commit a disconnected output`, no dcpext `dcp_poweroff() done`.
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
  `$lock_fail` for the caps color.
  Preview without locking: nested `Hyprland -c <min.lua>` + `hyprctl output create headless` + hyprlock + grim; type
  via live `hl.dsp.send_shortcut` to `class:^(aquamarine)$` (never Enter: PAM).
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
  `asahi-hdmi reset` + reload. No primary display; eDP-1 = mirror source + 0,0 anchor. USB-C `DP-1` is gated like
  HDMI-A-1 (last named rule wins: reverse scan). `asahi-hdmi added`/`sync` enable after the settle (gen file per
  output); `place` re-derives position (desc rules assume eDP at 4/3) only on an eDP scale change (HDMI too, not
  mirrors). `config.reloaded` runs `asahi-hdmi sync` and `sync DP-1`. Hyprland 0.57 fires no `monitor.added` for an
  output its rule disables (`onConnect` returns first): `gated_plugs` starts `asahi-hdmi added` on
  `monitor.layout_changed` from the connector's sysfs disconnected → connected edge (a Monitors-pane disable keeps the
  cable in, stays off; test `asahi/hypr/monitors_test.lua`, run by `asahi_hdmi_test.sh`). `asahi-hdmi removed` writes
  `disabled = true`, re-arming the gate (the enable eval replaced the rule: same name). DP never enables while USB-C's
  DCP is crashed (`dcp_crashed`: dcpext1's last unplug while lit got no `dcp_poweroff() done`, see Failed suspend;
  PR #582's "…poweroff clear swap; continuing" warning counts as alive): every modeset then fails EINVAL, Hyprland
  keeps DP-1 enabled at 0x0 and aborts on `IFramebuffer::alloc`'s zero-size RASSERT (safe mode loops until unplug).
  One critical notification; reboot. Not timing (`valid_mode:0` modesets work; `DPTXController … device == NULL` logs
  on every plug). Power off first (DPMS, Monitors pane disable + Keep): that unplug runs no clear swap. The pane's
  enable toggle skips the check.
- **Notch / fnmode**: `comp_asahi_system` writes `asahi-notch.conf` (`show_notch=1`) + `hid_apple fnmode=1`, then
  `dracut -f`; reboot. Live: `/sys/module/hid_apple/parameters/fnmode`.
- **Charge limit**: SMC is CHLS (90 reads back 90; CHWA would read 80): end 10–99 holds, start = end − 5 (start writes
  ignored), end < 100 sets the force-discharge bit (battctl: drains on AC; not seen). `asahi-charge-limit` clamps
  60–100; 100 = no limit, ≤ 99 = hold (also `asahi-battery`). One saved copy `/var/lib/asahi/charge-limit` (dir
  root:wheel 2775, temp + rename), written only after the SMC took it; boot applies it. Battery pane (Super+Ctrl+P,
  Reapply on mismatch) reads it on open / after change, never polls. SMC keeps it across unplug + s2idle: no AC-plug /
  resume re-apply unless a replug drops it. Never read the limit from UPower (1.91.5: fixed hwdb 75/80).
- **Keyboard / display brightness**: kbd `XF86Search` / `XF86LaunchA`, display `XF86MonBrightness*` (Shift = fine).
  `asahi-brightness-keyboard-auto`: re-derives only on a lux move seen twice (shadow filter); steady tick forks
  nothing. Auto fade, idle off/restore and keys share `$XDG_RUNTIME_DIR/asahi-idle-brightness.lock` (`brightness_lock`
  in `lib/common.sh`); a key while idled off / dimmed steps from the saved level. hypridle listener (`ignore_inhibit`)
  fades keys off; `asahi-idle keys` relights (not on the lock's fake motion / under a closed lid).
- **Keybinding grammar**: Super = window / navigate; +Shift = inverse (move vs focus); +Alt = variant (focus→resize,
  capture→record). `Super+Alt+HJKL` moves the **shared split border** — label by direction, never grow/shrink.
  `Super+Ctrl+<letter>` = panel (A audio, B bluetooth, C calendar, D display, W network, P power, R backup, S
  screenshot gallery, T activity, I stay-awake, N night light, E emoji, V clipboard, K keybindings). `Super+Ctrl+Alt`:
  R reload Hyprland, W/P/I restart Quickshell / hyprpaper / hypridle, S suspend, Z magnifier reset.
  `Super+Ctrl+plus/minus` = display scale; `Super+Ctrl+Z` / `+Shift+Z` / `+Alt+Z` = magnifier in / out / reset
  (`hl.config { cursor = { zoom_factor } }`, not `hyprctl keyword`). Panels: `quick()` in `bindings.lua`
  (`quickActions` in `LauncherWindow.qml`); same combo again closes (`openQuick`/`openCategory`). Esc peels one layer
  (Quick pane → home → close); shortcut-opened → closes (`openedByShortcut`). Workspaces: Super+N go, Super+Ctrl+N
  move, Super+Alt+N send w/o following, Super+Y back-and-forth. Super+Alt+F = fullscreen in tile (`fullscreen_state`
  client 2); Super+Alt+arrows join neighbour group; Alt+Tab cycles. Lock / media / lid binds in `submap_universal`
  (writing-tools submap's catchall swallowed them). Super+B/N/S free. **Every bind needs a `desc`**
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
  Super+Alt+Shift+F12 + webcam (`asahi-webcam`; Super+Alt+ü/+ resize = `code:34/35`). Annotate (tile pencil / preview
  pill) = `asahi-screenshot-annotate` = `swappy -f shot` (satty not in Fedora; class `swappy` floats). Only Save
  (Ctrl+S / button) counts: `asahi/swappy/config` → `~/screenshots/annotated-*.png` + `early_exit`; script moves it
  over the shot if `magick compare -metric AE` sees changes (else drops it), re-copies. No `-o` (swappy writes it on
  Esc / q / close too). Thumbs regenerate when older (`-nt`); tile + preview Images `cache: false` (same path).
  `screenshot` toasts (also OCR / QR) show silently under Do Not Disturb. Test: `asahi/bin/asahi_webcam_test.sh`.
- **Browser screenshare**: Chromium needs `CHROMIUM_USER_FLAGS=--enable-features=WebRTCPipeWireCapturer` in
  `env.lua` + `environment.d/90-asahi.conf` (Fedora ignores `chromium-flags.conf`). No Google Chrome; Fedora ships
  `hyprland-share-picker`. xdph never reconnects to PipeWire (after a restart `Start` spins, shares hang) — drop-in
  `xdg-desktop-portal-hyprland.service.d/10-asahi-pipewire.conf` (`PartOf=pipewire.service`).
- **asahi-debug**: Fedora Asahi health (`asahi/bin/asahi-debug [--json]`; dnf, `wpa_supplicant`, not pacman/iwd/SDDM;
  Wi-Fi radio off on purpose = PASS). Test: `asahi/bin/asahi_debug_test.sh`. Not in `make doctor`; must not flag
  Hyprland on generic Linux.
- **Night light**: Super+Ctrl+N → `asahi-nightlight` (hyprsunset); on = `hyprsunset.conf`, off =
  `hyprctl hyprsunset identity`. Identity profile so autostart tints nothing; autostart drops stale `nightlight.json`
  (chip showed on, no tint).
- **Bar notch**: cutout is a hole (`BarModel.notchRegionInset`), not a spacer; height from geometry (3024x1964 →
  **74**), width = real cutout; overflow clipped at the wall. Optional words granted in order while they fit
  (`BarHost.grants`: usage countdown → VPN name → VPN uptime → network name; VPN name+ only without notch; measured
  without grants, never past the first misfit; external gets all). Clock always weekday + date, same size/colour.
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
- **Bar tray**: ≤ 3 inline while they fit (`BarHost.trayInline`, budgeted before grants), rest `+N` → `TrayPanel.qml`.
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
- **sshd**: Fedora enables it; disable + mask `sshd.service` + `sshd.socket`. Re-check after a release upgrade.
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
  all). Super+comma `dismissOne`; Super+Shift+comma `dismissAll` also clears the saved list (so does IPC `clear`).
  Sheet and bar popups close each other; sheet focus grab arms 200 ms late (an unmapping popup clears it); the bell click
  ending the grab is ignored; the launcher closes the sheet (grab kept its keys). `historyGroups` built only while open
  (day labels fresh past midnight). shell.qml id is `notifCenter` — `notificationCenter: notificationCenter` self-binds
  to null.
- **bash 5.3 / trailing `&&`**: EXIT trap or function ending in `[[ -n $x ]] && …` returns 1 when `$x` is empty;
  `set -e` then kills the script (`asahi-network` lost JSON). End traps on `|| true` / `if`; optional tail lines in `if`
  blocks. Interactive zsh helpers without `set -e` are fine.
- **Apple HID race**: dockchannel-hid binds `hid-generic` first; `asahi/dracut.conf.d/10-asahi-hid.conf` force-loads
  `hid_apple` only (`hid_magicmouse` builtin). Verify `/sys/bus/hid/drivers/` +
  `readlink -f /sys/bus/hid/devices/*/driver`. Live trackpad recovery:
  `sudo udevadm trigger --action=add /dev/input/eventN` (input node, not drm).
- **Volume keys**: `asahi-media-control output-volume raise|lower|+1|-1` (and Media pane slider) unmutes the sink **only
  if muted** (`unmute_if_muted`; unconditional `set-mute 0` clicked the speakers); never unmutes the mic. Launcher
  Logout / Restart / Shutdown: `confirm: true` (Data.js), second Enter within 3 s runs.
- **Audio**: Fedora Asahi ships the stack — don't port omarchy's Apple audio.sh. RT check is the **thread**:
  `ps -eLo comm,rtprio,cls | grep data-loop` → `20 RR`. Mic `effect_output.j414-mic` is 1ch `AUX0` (stereo recorders:
  left only) → `asahi/wireplumber/wireplumber.conf.d/asahi-mic.conf`: software-dsp copy stage = MONO default
  `asahi_mic`, `hide-parent` hides AUX0. Not a loopback (AUX0 stayed visible: mute bypass); `node.rules` can't remap a
  filter's channels. New filter node reports 2 `channelVolumes` until first capture (chip 0 % / unmuted) — prime:
  `timeout 1 pw-record --target asahi_mic /dev/null`. Never override asahi-audio's node scripts (a `software-dsp.lua`
  overlay hung WirePlumber). 96 kHz playback can lock speakersafetyd (`Speaker volumes locked`):
  `sudo systemctl reset-failed speakersafetyd && sudo systemctl start speakersafetyd`.
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
  hidraw is root-only: "Allow access" → `pkexec asahi-logitech-access` writes
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
  `nmcli connection up id "<ssid>"` (Proton tunnel survives), not `nmcli device reapply wld0`. Proper fix kernel-side
  (`~/linux-fairydust`).
- **Wi-Fi band**: `asahi-wifi-band [status|auto|2.4|5]` pins the profile's band (AP band-steers), reverts if the
  reconnect fails. Connected card: `asahi-network`'s tooltip (without `--bar` it describes Wi-Fi even with a cable up) +
  `iw link` (dBm only `^-?[0-9]{1,3}$`). Open, Enhanced Open, WEP = public, 802.1X = sign-in; no extra probe. BCM4388
  resume fix (omarchy-mac) not ported: post-resume rejects recover in 6–30 s. Tests:
  `asahi/bin/asahi_wifi_band_test.sh`, `asahi/bin/asahi_network_test.sh`.
- **Kernel**: self-built `fairydust` (USB-C DP alt mode, not in Fedora) in `~/linux-fairydust`, 16k pages; `asahi-debug`
  accepts `*fairydust*`. Local fixes only in `~/linux-fairydust` (never this repo): brcmfmac `roam_delta` init
  (`WLC_SET_ROAM_DELTA error (-52)`; upstream since asahi-7.2.13 — drop on next rebase), dcp HPD re-sample on resume
  (upstream dropped it on purpose in c0a8f705 — re-test without), dcp atomic_check passes a CRTC that stays off (keep;
  open AsahiLinux/linux PR #582 fixes the cause), j414s DTS disabling AVD + its DART (no avd-fw on Fedora; failed probe
  keeps `avd_sys` powered; needs `make dtbs && sudo make dtbs_install && sudo update-m1n1`). USB-C display =
  `card2-DP-1`; no `ddc` link. Roam fix + `appledrm.ko` (both dcp fixes) sit in
  `/lib/modules/7.1.13-fairydust+/updates/`, which depmod prefers: delete on next full rebuild.
- **m1n1 DTB pin**: m1n1 `boot.bin` carries ONE device-tree set; on kernel add/remove grubby's `10-devicetree.install`
  re-points `/boot/dtb` to the newest Fedora `dtb-*` and `15-update-m1n1.install` rebuilds `boot.bin` → fairydust loses
  DP alt mode (no `/proc/device-tree/aliases/dcpext1`). `./install.sh asahi-system` (before dnf) links
  `/boot/dtbs/fairydust` → running release, sets `DTBS="/boot/dtbs/fairydust"` (`/etc/sysconfig/update-m1n1`) and
  `UPDATEDEFAULT=no` (`/etc/sysconfig/kernel`); rerun after a new fairydust (`asahi-debug` WARNs `fairydust-pin`).
  Recovery: fix pin, `sudo update-m1n1`; worst case swap `m1n1/boot.bin` and `boot.bin.old` on the ESP.
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
  **Keyboard/trackpad cannot wake s2idle** (no wakeup source); lid, power button and, on AC, BT input
  (`asahi/udev/99-asahi-bt-wake.rules`; untested on BCM4388 — drop it on spurious wakes) can. Manual sleep
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
- **Window pop**: Super+O → `asahi-window-pop` (float/resize/center/pin/`pop`); second press retiles.
- **Display scale**: Super+Ctrl+plus/minus → `asahi-monitor-scale`. Legal scales = 1/120 divisors (eDP-1: 1 / 1.333333
  / 2). Saved per output name under `$XDG_RUNTIME_DIR` (HDMI-A-1 shared by both sinks). Positions **derived**
  (`anchor_offset` in `lib/common.sh`), never pinned.
- **Refresh rate**: eDP-1 stays 120 Hz (`monitors.lua`); battery 60 Hz saved ~3 W only in video — do not re-add.
  Wi-Fi power save: no gain, stays off.
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

