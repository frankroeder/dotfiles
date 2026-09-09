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
- required-step failures must fail the installer (not warn-only)
- doctor must not flag Hyprland on generic Linux

# Documentation

## macOS
- yabai (tiling WM, bspwm-like): https://github.com/asmvik/yabai/wiki
- skhd (hotkey daemon): https://github.com/asmvik/skhd
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
- **Lock on boot**: do not lock after Hyprland starts. This session is `login` on tty1 — the getty password is the auth gate. A second hyprlock after the desktop appears was redundant, and two passwords at boot is not wanted. **Do not "fix" that with agetty `--autologin`**: it was tried and reverted, because `zsh/zprofile` falls through to an interactive shell when `start-hyprland` is not on PATH, and under autologin that shell is unauthenticated. A leftover `/etc/systemd/system/getty@tty1.service.d/10-asahi-autologin.conf` still skips the password until `./install.sh asahi-getty` removes it (also part of `comp_asahi_system`). Do not restart `getty@tty1` on a live session — that kills Hyprland. A display manager (sddm/greetd) was rejected for the same reason it always is here — a second stack to maintain. Super+Escape and hypridle still lock.
- **Console keymap**: `asahi/vconsole.conf` `KEYMAP="de-latin1-nodeadkeys"` — the console counterpart of `input.lua`'s `kb_layout=de` / `kb_variant=mac_nodeadkeys`. It must be a **legacy** kbd map. Every xkb-converted map under `/usr/lib/kbd/keymaps/xkb/` (`de`, `de-nodeadkeys`, `de-mac_nodeadkeys`, …) fails to compile — `lk_add_key called with bad keycode -1` plus unknown keysyms — and `systemd-vconsole-setup` then silently leaves the console on US. The `mac-*` maps do compile but carry PowerPC ADB keycodes (keycode 21 is `4`, not `z`); `hid_apple` reports ordinary evdev keycodes, so those would scramble the layout. Always check first: `loadkeys --mktable <name> >/dev/null && echo compiles`.
- **Console/getty font**: set it in `asahi/vconsole.conf` (`FONT="ter-v32n"`), installed to `/etc/vconsole.conf` by `comp_asahi_system`. **A setfont unit cannot do this** — the old `asahi-tty-font.service` was deleted because `systemd-vconsole-setup` is udev-triggered and re-runs as the DRM devices appear (last run ~460ms after the service on this box), overwriting whatever setfont had put there; the getty prompt was showing `eurlatgr` the whole time, never the service's font. Check the real order with `journalctl -b -u systemd-vconsole-setup -u <unit>`. `ter-v32n` is kbd's 32px ceiling; on the 3024x1964 panel that is a 189x61 grid.
- **Hibernate**: unsupported on Asahi (`freeze`/`mem` only, zram is not a resume image). Launcher has no Hibernate row; logind/sleep drop-ins ignore hibernate keys. Stay on `systemctl suspend` (s2idle).
- **Power button**: Hyprland is not GNOME — `gsettings` `power-button-action` is a no-op here (`gnome-settings-daemon` is not installed). `asahi/systemd/logind.conf.d/10-asahi-sleep.conf` sets `HandlePowerKey=ignore` (and `HandlePowerKeyLongPress=ignore`) so a tap of Touch ID / power cannot `poweroff`. A ~10s hold is SMC firmware force-reset and bypasses the OS. Apply post-hoc with `./install.sh asahi-logind` (also part of `comp_asahi_system`). It HUPs systemd-logind after installing the drop-in — do not restart that unit, it would kill the session.
- **Lid**: Apple Silicon names the switch `Apple SMC power/lid events`, not `Lid Switch`. Binds live in `asahi/hypr/conf.d/monitors.lua` (dpms + `asahi-idle-brightness` on eDP-1) with `locked = true`. There is no ACPI `/proc/acpi/button/lid` on this hardware.
- **HDMI**: `monitors.lua` leaves `HDMI-A-1` disabled so a plug cannot modeset on the udev tick (shared DCP: `valid_mode:0` + eDP page-flip freezes the laptop, Dell stays black). `asahi-hdmi` enables it after ~2s and must pass `disabled = false` or the lua rule sticks. `asahi-dpms` only DPMS outputs Hyprland already has enabled (never a disconnected HDMI). Test: `asahi/bin/asahi_hdmi_test.sh`.
- **Notch**: `comp_asahi_system` writes `/etc/modprobe.d/asahi-notch.conf` (`options appledrm show_notch=1`) and rebuilds initramfs with **dracut**. Reboot required. Without this, Asahi crops the panel below the notch.
- **fnmode**: `asahi/modprobe.d/hid_apple.conf` sets `options hid_apple fnmode=1` (media keys on the top row, F-keys behind Fn). Applied live by writing `/sys/module/hid_apple/parameters/fnmode`; boot needs the dracut rebuild so the initramfs snapshot matches.
- **Keyboard backlight**: `XF86Search` / `XF86LaunchA`. Fine step is `SHIFT` on those keys. Display brightness stays on `XF86MonBrightness*`; fine display is `SHIFT +` brightness.
- **Screenshots**: slurp + grim, no hyprpicker freeze (that baked a stuck cursor into the PNG). Super+F10/F11/F12 (window / smart / display) and the same on Super+mute/vol-/vol+. OCR/QR: Super+Shift/Ctrl+F11. Color picker: Super+Shift+F12. Record: Super+Alt+F11 region, Super+Alt+F12 display, Super+Alt+Shift+F12 display plus pinned webcam overlay (`asahi-webcam`; Super+Alt+[ / ] resize). Test: `asahi/bin/asahi_webcam_test.sh`.
- **Browser screenshare**: camera and mic already work (apple-isp + asahi-audio). Chromium screenshare needs `CHROMIUM_USER_FLAGS=--enable-features=WebRTCPipeWireCapturer` in `hypr/conf.d/env.lua` and `environment.d/90-asahi.conf` — Fedora's wrapper ignores `chromium-flags.conf`. No Google Chrome; Fedora already ships `hyprland-share-picker`.
- **asahi-debug**: Fedora Asahi health report (`asahi/bin/asahi-debug [--json]`). dnf/rpm, `wpa_supplicant`, asahi-audio DSP, `speakersafetyd`, `kernel-16k`, HID, notch, sshd mask, no-hibernate. Not pacman/iwd/SDDM. Test: `asahi/bin/asahi_debug_test.sh`. Does not run from `make doctor` and must not flag Hyprland on generic Linux.
- **Night light**: Super+Ctrl+N toggles hyprsunset (`asahi-nightlight`; starts the daemon if needed). On = `temperature` from `asahi/hypr/hyprsunset.conf` (1500K). Off = `hyprctl hyprsunset identity`. Identity profile so autostart tints nothing. Clock-based: uncomment the 20:00 profile.
- **Appearance**: Hyprland does not publish `org.freedesktop.appearance color-scheme`. Autostart sets `gsettings` `color-scheme=prefer-dark` plus `adw-gtk3-dark` / `Papirus-Dark`; GTK ini lives in `asahi/gtk-{3,4}.0/settings.ini`. LibreWolf chrome (`userChrome.css`) and nvim follow that portal/gsettings signal, not quickshell/ghostty palettes. Unset (`default` / portal `0`) is treated as light.
- **sshd**: Fedora ships sshd *enabled*, so a fresh install listens on `0.0.0.0:22` with password auth. Nothing uses inbound SSH here — the service is disabled and masked (`sudo systemctl disable --now sshd && sudo systemctl mask sshd.service sshd.socket`). Re-check after a Fedora release upgrade, which can unmask units.
- **Notification images**: `image-path` comes from any app on the session bus, and Qt fetches `http(s)` sources, so `NotificationCenter.qml`'s `localImage()` renders only `image:`/`file:`/`/…`. Summary and body are `Text.PlainText`, which is what keeps `<img src>` in a body inert.
- **bash 5.3**: Fedora 44 ships bash 5.3, where an `EXIT` trap whose **last command returns non-zero** overrides a successful script's exit status under `set -e`. A handler ending on `[[ -n $x ]] && rm -f "$x"` makes a clean run exit 1. End every trap handler on something that cannot fail (`|| true`, or an `if` block rather than a trailing `&&`). Existing handlers are clean; check new ones with `bash -c 'set -e; c(){ [[ -n "$s" ]] && rm -f "$s"; }; trap c EXIT; true'; echo $?`.
- **Trailing `&&` in a function**: the same rule bites any function whose last line is `[ -n "$x" ] && printf ...`. When `$x` is empty the function returns 1, and `out=$(f)` under `set -e` kills the script before it prints anything — `asahi-network` lost its whole JSON payload this way whenever `nmcli` reported no BSSID. Use `if` blocks for the optional tail lines. Interactive helpers (`shared/docker_functions.sh`, `shared/fzf.sh`) are sourced into zsh without `set -e`, so the pattern is harmless there.
- **Apple HID race**: the internal keyboard/trackpad arrive over dockchannel-hid and bind to `hid-generic` first, then get destroyed and re-created when the real drivers load; on an unlucky boot logind's `TakeDevice` loses that race and libinput never retries, killing the device for the session. `asahi/dracut.conf.d/10-asahi-hid.conf` force-loads `hid_apple` from the initramfs so it binds correctly the first time (installed by `comp_asahi_system`, which then reruns `dracut -f`). Only `hid_apple` is listed: Fedora's Asahi kernel builds `hid_magicmouse` **in** (`modinfo -n` → `(builtin)`), so naming it is a no-op — check before adding drivers. Verify bindings with `ls /sys/bus/hid/drivers/` and `readlink -f /sys/bus/hid/devices/*/driver`.
- **Audio**: the Asahi stack (`asahi-audio` UCM + DSP chain, `speakersafetyd`, `rtkit`, `pipewire-pulseaudio`) ships and runs correctly on Fedora Asahi Remix. Do **not** port omarchy's `install/hardware/apple/audio.sh` — it exists because Arch/ALARM has to bolt this on. Confirm RT scheduling on the *thread*, not the process: `ps -eLo comm,rtprio,cls | grep data-loop` should read `20 RR` (a bare `ps -eo` shows only the main thread and always looks unprivileged).
- **Trackpad taps**: omarchy runs `tap_to_click = false` on Asahi, noting that `disable_while_typing` alone does not stop stray taps while typing on this touchpad. `input.lua` keeps `tap_to_click = true` deliberately — if phantom clicks while typing ever show up, that pairing is the known cause.
- **Window management defaults**: `general.lua` carries omarchy's tuning — `dwindle.force_split = 2` (new windows go right/below instead of following the mouse quadrant), `binds.hide_special_on_workspace_change` (the SUPER+S scratchpad stops trailing between workspaces), `misc.allow_session_lock_restore` (a crashed hyprlock can be replaced instead of wedging the session), `misc.on_focus_under_fullscreen`, `misc.initial_workspace_tracking = 0`, `misc.anr_missed_pings = 3`. `group`/`groupbar` is themed to the Catppuccin borders because SUPER+W groups windows and the stock groupbar clashes. Validate key names against `/usr/share/hypr/stubs/hl.meta.lua` (it enumerates every config path, e.g. `group.col.border_active` — *not* `active_border`), then `hyprctl reload && hyprctl configerrors`.
- **Terminal trackpad scroll**: `rules.lua` sets `scroll_touchpad = 0.2` for `com.mitchellh.ghostty`. ghostty scrolls by lines rather than pixels, so the global `scroll_factor` is far too fast in a terminal; 0.2 is omarchy's Asahi value for this exact pairing.
- **asahi/bin structure**: shared shell helpers live in `asahi/bin/lib/common.sh` (`display_device`, `keyboard_device`, `focused_monitor`), sourced with `. "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/lib/common.sh"` — `readlink -f` so a script reached through a symlink still finds it. `asahi-launch` is the ONE place that knows the `uwsm-app`/`setsid` dance; `asahi-launch-tui`, `-wifi` and `-bluetooth` exec through it instead of repeating it. Scripts address their siblings via that same `$(dirname ...)`, not a hardcoded `$HOME/.dotfiles`. `install/components.sh` chmods `asahi/bin/*`, which skips `lib/` because it is a directory — keep sourced files there.
- **Autostart**: two mechanisms, deliberately separate. `asahi/xdg-autostart/` is linked into `~/.config/autostart/` for `systemd-xdg-autostart-generator`; its only file is a `Hidden=true` stub masking Fedora's `gnome-keyring-ssh.desktop`. Hyprland `exec-once` scripts are plain `asahi/bin/asahi-*` entries called from `hypr/conf.d/autostart.lua`. Verify the mask with `ls /run/user/$(id -u)/systemd/generator.late/ | grep keyring` — no `app-gnome\x2dkeyring\x2dssh@autostart.service`.
- **Secrets**: Hyprland is not KDE. `asahi/kwalletrc` disables kwallet/ksecretd (`Enabled=false`, `apiEnabled=false`) so the "Default Keyring" wallet wizard never appears. `gnome-keyring-daemon --components=secrets` owns `org.freedesktop.secrets`; SSH stays with `keychain`. Do not start gnome-keyring's ssh component.
- **SSH / keychain**: Fedora 44 ships keychain 3. `/etc/profile.d/keychain.sh` (keychain RPM) greps every private key in `~/.ssh` (`google_compute_engine` included) and on interactive login runs `keychain --quiet --immediate $SSHKEYS` — no `--noask` — so tty1 getty asks for every passphrase after the login password. `/etc/zprofile` sources `/etc/profile` before `~/.zprofile`. Export `KEYCHAIN_DONE=1` from `zshenv` (that script's own skip flag) so the hook is a no-op. A leftover `~/.keychain/$HOST-sh` after reboot can name a reused PID (not `ssh-agent`) plus a dead socket; `--quick` then re-exports that socket and every git/ssh asks for the key password. `asahi-ssh-keychain` must drop `--quick`, discard a stale pidfile without killing the reused PID, and start a **empty** agent (`--noask`). Do **not** prompt for the key passphrase on tty1 — getty is only the login gate. The first `git`/`ssh` unlocks via `AddKeysToAgent yes` and the agent holds the key for the session. Hyprland exec-once is the same `--noask` + `--systemd` helper. `zshenv` unsets `SSH_AUTH_SOCK` when `ssh-add -l` cannot talk to the agent (exit > 1).

## Shared
- **CCU usage helpers**: ONE shared core, `sketchybar/helpers/ccu_common.py` (`lua_literal`/`emit` output contract, `short_error`, TTL cache, `with_auth_retry`, `write_json_atomic`). `claude_usage` / `cursor_usage` / `grok_usage` keep only their own API and payload shape. `emit` is the contract both front-ends depend on: a Lua table literal for sketchybar's `sbar.exec` (`ccu.lua:parse_lua_table`), JSON under `--json` for `asahi/bin/asahi-ccu`, which imports the helpers as modules. `ccu_cost.py` keeps its own JSON-only `emit` on purpose — Lua literals break on reserved keys like `days30.end`. Test: `python3 asahi/bin/asahi_ccu_test.py`.
- **Lua test bootstrap**: `sketchybar/top/tests/prelude.lua` owns the root resolution, `package.path`, and `ok`/`eq`/`fail`/`done`. Test files open with the five-line `dofile` bootstrap in its header comment.
- **dict.cc launchers**: ONE shared core, `vicinae/extensions/dict-cc/src/dictcc-core.mjs`
 (query parsing, HTML parsing, meta, LRU cache; conservative ES2018, no fetch/matchAll —
 quickshell's QML JS engine must run it). Hosts keep only transport: vicinae `src/dictcc.ts`
 wraps it with fetch (macOS), the Asahi quickshell launcher imports it directly
 (`import "dictcc-core.mjs" as DictCC` via symlink in `asahi/quickshell/remix/modules/launcher/`)
 with an XMLHttpRequest lookup — no python helper, no subprocess. dict.cc ignores User-Agent, so
 QML's forbidden-UA-header XHR is fine; `xhr.responseURL` works for DE/EN direction detection.
 Test: `node asahi/quickshell/remix/modules/launcher/dictcc_test.js` (real-page fixture).
- Neovim: https://neovim.io/doc/
- Zsh: https://zsh.sourceforge.io/Doc/
- Ghostty: https://ghostty.org/docs
- mpv: https://mpv.io/manual/stable/

# SketchyBar layout (macOS)

Three instances: `sketchybar` (bottom), `sketchybar-top` (top), `sketchybar-island` (notch pill).
Config in `sketchybar/{bottom,top,island}/`; shared lua at `sketchybar/*.lua`. Reload each
with `<bin> --reload`. Prefer plain `require` for items (fail loud), not safe_require.

Requirements / decisions:
- Island pill fill AND border are notch-black (0xff000000), border_width 0 — a themed ring
  (`theme.border` blue) reads as a seam against the physical notch. Foregrounds are the static
  mocha palette at full alpha (`colors.mocha` in island_style) — bright in both modes, since latte
  fg is unreadable on black.
- Island pills: appswitch, siri, layout (`island_layout` from skhd fn-e/w/s), mic (`island_mic`
  from top mic), bluetooth (`island_bluetooth` from top bt poll on new connect), window
  (`island_window` from skhd fn+shift-w/s float+sticky toggles; re-queries yabai for state).
  No battery/power pills (macOS notifies on low battery), no volume pill (native HUD), no wifi
  pill, no space pill (overlapped appswitch), no now-playing/media pill, no vpn pill.
- Expand priority: lower prio never clobbers higher; sticky siri (duration=0) only yields to higher
  prio or same kind. Dismiss timers are DUAL (`sbar.delay` + `sbar.exec sleep` failsafe, shared
  token + fired flag) because sbar.delay rides the animation tick and dies with a wedged display
  link. Dismiss is VERTICAL and SOLID: the pill slides straight up behind the screen edge (bar
  y_offset → -(height+1), the ONLY animated prop) with NO fade — fading made it translucent
  mid-slide, visibly not notch-black, and read as flicker. Width/margin/height/colors stay
  constant — no sideways collapse. Idle geometry snaps only after the hide
  (apply_idle_geometry), and geometry trackers are NOT reset at dismiss start so a morph arriving
  mid-slide sees real values and rides y_offset back down inside its animate batch (cur_y tracker).
- `display.refresh()` re-probes notch + arrangement rows on `display_change` (hotplug).
- Every expand grows out of the notch (idle seed in island_core); consecutive expands morph.
- NEVER put constant-valued props inside `sbar.animate` batches when the value is unchanged —
  numeric geometry jitters 1px, colors double-set (visible flicker on morphs). island_core tracks
  the last-applied bar color/border and icon/label colors alongside geometry and prunes constant
  entries from every batch. A bar-color change with NO geometry change is snapped un-animated
  (a color-only bar batch gets mangled: omitted margin zeroes to a full-display stretch). Expand
  only animates changing geometry; fresh shows seed content transparent BEFORE unhiding the bar.
  The vertical dismiss animates only y_offset + fade; idle geometry snaps un-animated after hide.
- `display.notch_width`: require both auxiliary flanks + n < 40% of screen (else 0). Full-width
  "notch" on externals was a false positive that set idle pill width = display width.
- Smoke: `sketchybar/island/smoke_test.sh [out_dir]`.
- Island tuck equals corner_radius (offsets -16): hides the top rounding above the screen edge so
  the pill sides come out of the notch square; heights include the tucked 16px.
- Island is notch-aware: on the built-in (notched) display the pill straddles the notch — text in
  a wide left box (left-aligned, at the pill's left, out of the notch), glyph in a fixed right lobe
  (right of the notch). The wide left box fills the width so the glyph is pushed to the right lobe
 with only small paddings — DO NOT use large paddings (~notch width) to build the gap, sketchybar
 mis-renders them (content collapses/centers even though `--query` reports the set values). Widths
 in settings.lua are sized (from measured label widths) so the left text stays clear of the notch;
 the declared family is now SF Pro (installed) — measure against it with probe items. On
 external/notchless displays lobes are equal halves clustered toward the center.
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
- Island yabai `external_bar` top = idle pill only (`idle_height + y_offset_expand`
  from settings.lua). Island bar `topmost=on` so taller critical can draw over
  windows. Needs `yabai --restart-service` to apply.
- Top bar renders on ALL displays (no display pin). In dual-monitor `notch_width` stays 0 (avoids
  external cutout artifacts); the built-in notch is covered by the island pill, not a bar cutout.
- No `front_app` top widget: deleted. The island appswitch pill is the app indicator, driven
  directly by the native `front_app_switched` event in the island instance.
- No high-CPU alert pill.
- GPU widget (bottom): single-row `GPU 00%` label · graph · centered temp (the committed layout).
  Hardware polls `/usr/local/bin/silistats --once`: load = `usage.*.perf_percent` (freq-weighted,
  not `active_*` residency; `busy_*` absent on first/`--once` sample), temps = `temperature.*_avg_c`,
  power = `power.system_watts` (SMC PSTR platform total, not `all_watts` package rails). Fields are
  always present — no fallbacks. Swap pct only guards `swap_gb_total > 0` (div-by-zero).
- Bar presets in settings.lua: `transparent` (default, invisible bar) / `gnix` (solid+blur).
- No capsule drop shadows anywhere — deliberate, do not add them back.
- Top-bar right cluster keeps an even ~12–14px visual gap rhythm. Grouped widgets (mic/volume)
 default to 0 outer padding, which packed them tight — their explicit padding overrides plus
 wifi icon pads and calendar's trimmed left pads carry the rhythm; verify gaps numerically via
 `--query <item>` `bounding_rects` (rect gap + inner edge paddings), not by eye.
 Icon-only strip (mic/volume/wifi/bt/coffee) is 18pt in a 24px box with 4px item pads — wifi
 must not use a fixed `width` or those pads are eaten and it glues to volume. Bluetooth is Hack
 Nerd Font 18 (no SF bluetooth glyph — SF Pro fallback made 󰂯 look tiny vs wifi's 􀙇). Disk
 pies on the bottom bar are the same Nerd-in-SF-Pro trap.
- Network rates render "12 KB/s" (leading zeros stripped, `ps`→`/s`) LEFT-aligned in the fixed
 56px label — numbers must hug the ↑/↓ arrows; right-align opened a hole between arrow and value
 whenever the text was shorter than the box. Raw zero-padded provider strings are kept in
 `last_rates` (the `^0+%s` inactive check depends on them) and prettified only at display time.
 Idle = wifi icon only; hover (wifi/gap/rates) animates the stacked ↑/↓ row open (tanh,
 motion.normal, `network_down` width 0↔rate_row). `network_update` still polls; the bar is
 painted only while hot so the numbers don't twitch the layout when collapsed.
- Mic/volume percentages are hover-only (idle = icon). The shown label is still a fixed 42px
 left-aligned box so "9%"→"100%"→"Muted" don't jitter while hovering ("Muted" = 39px in SF Pro
 Semibold 13). Icons stay a fixed 24px box (state glyphs differ in width). `ui.bind_popup`
 `hover_label` animates label.width (tanh, motion.normal) 0↔42; `drawing` snaps outside the
 animate batch (not interpolatable). Show on `mouse.entered`, collapse on `mouse.exited`.
 `mouse.exited.global` still closes the popup and collapses — `mouse.exited` no-ops while the
 popup is open so the parent doesn't shrink and jump it.
- ALL bars now declare `SF Pro` (installed at /Library/Fonts/SF-Pro*.otf). "SF Mono" never was
 installed — every bar used to render a ~10% narrower system fallback, and all fixed widths were
 calibrated against SF Pro after the switch. Verify font metrics with probe items
 (`--add item` + `bounding_rects`), never by assuming.
- Island pill widths are DYNAMIC per toast (`island_core.pill_width`, params in
 `settings.island.sizing`): `w = (probed notch + 2×10 fudge) + 2×max(lpl 16 + exact text width +
 lpr 4 + slack 2, right lobe 4+48+16)`, ceil-quantized to 20px so similar-length toasts reuse
 geometry (string-swap instead of a morph). Text widths are EXACT: `island_text.lua` holds SF Pro
 Semibold 15pt advance widths measured via NSString sizeWithAttributes on the resolved "SF Pro"
 Semibold face (char-sum ≤ 0.6px off full-string rendering); unknown codepoints get a full em.
 The AppKit aux-area probe (220 @ 1800pt wide) BADLY underreads the physical cutout —
 live-calibrated on text end position (display center ± end): 772.8 clipped "Ghostty"'s tail by
 2–4px and 762.8 was still "almost hidden", so the visible cutout edge sits near ±768 (physical
 ≈ 268–272pt, ~25px/side beyond the probe; the retired FIXED widths grazed it too — mic 430 put
 "Mic muted" at 776). `notch_fudge 24 + lpr 4 + slack 2` keeps text ends ≤ ~753 (≥ 15px visual
 gap, +0–9.5px quantization). Slim examples: "Ghostty" 540→440, "Siri" 380→420, "Tiled" 430→420,
 "Mic muted" 430→480, bluetooth worst 590→620 (cap, pixel-refit guards it). Texts that would
 exceed `max_width` are pixel-refit in place with `island_text.fit` — the hard guarantee that
 text never renders under the cutout. Regenerate the W15 table with a JXA probe if the pill font
 family/weight ever changes.
- App/device names in island pills are truncated with `utils.ellipsize` (codepoint-aware,
 utf8.offset) — byte-based `string.sub` split multibyte names ("Café…") into mojibake.
- A long-lived sketchybar process can silently corrupt: `--bar hidden=…` becomes a no-op AND all
 bar props inside `--animate` batches get dropped, while direct un-animated sets still apply.
 Symptoms on the island: pills stuck at idle height/margin while expanded, bar never re-hiding
 after retract. `--reload` does NOT clear it — only a full process restart does
 (`launchctl kickstart -k gui/$UID/git.frank.sketchybar-island`). Diagnose by comparing a direct
 `--bar margin=N` (applies) against `--animate tanh 15 --bar margin=N` (dropped when corrupted).
- ROOT CAUSE of frozen animations (macOS 26): sketchybar ticks its animator AND SbarLua's
 `sbar.delay` off a CVDisplayLink. A lock/unlock (or display sleep) can wedge CoreVideo/SkyLight
 state SYSTEM-WIDE: every fresh `CVDisplayLinkStart` never delivers (a `sample` of the binary
 shows NO CVDisplayLink thread), so ALL sketchybar instances — including freshly kickstarted
 processes — freeze animations at frame 0 and drop delays, while direct sets/triggers/queries
 still work. Process restarts do NOT help. `pmset displaysleepnow` + `caffeinate -u -t 3` re-arms
 currently-armed links for one burst, but the next link start wedges again; only reboot/logout
 fully resets. Downstream damage: lock.lua's unlock slide-in never runs → bars parked off-screen
 at the lock position (y −20 / margin −30) = "bars disappeared". Guards: lock.lua
 `ensure_rest_after` (exec-driven post-unlock snap) and island dual timers. Upstream:
 FelixKratz/SketchyBar #691, #776, #738.
- sketchybar TRIMS leading label whitespace — ASCII space AND NBSP alike — so left-padding a
 digit-first string is impossible; interior padding survives. FIGURE SPACE (U+2007) is exactly
 digit-wide in SF Pro (tabular digits), so stacked pairs (eCPU/pCPU, RAM/SWP) drop zero-padding
 ("pCPU 07%") for interior U+2007 ("pCPU␇7%") and stay column-aligned. Power keeps a fixed 34px
 right-aligned label box so 9 W ↔ 19 W cannot resize the capsule. ccu popup chart GRIDS still
 need Menlo (real mono) — space-padded cells drift in any proportional face.
- ccu cards (top bar): head = provider + plan name with a right-aligned email/rebill peer;
 subline = "x% of weekly|monthly limit used" + "Resets <date>, <time> · <countdown>". The meter is
 NOT a slider: plain items whose BACKGROUND is the bar, one per usage category (Grok's shared
 weekly pool split: Chat/Grok Build/API/Imagine/Voice) + one remaining-track item, positioned via
 the same pad/negative-pad trick as pop_item (relayout must NOT reset width on them — keep_w).
 Legend cells (dot + "Chat 1%") pack left the same way. Grok data = gRPC-web GetGrokCreditsConfig
 protobuf scan in `helpers/grok_usage.py` (+ tier from /v1/settings, rebill from
 grok.com/rest/subscriptions); Cursor adds GetPlanInfo/GetMe + spend cents in
 `helpers/cursor_usage.py`. All-time/30d/7d + chart rows stay from ccu_cost.py. Cards without a
 plan name (Claude/Codex) keep the old single-line head + solid accent meter.
- Layout pill (`widgets.yabai_layout`): glyph = space layout, label = stack `i/n` + the focused
  window's flag glyphs, tint = `state_accent`, where window state outranks layout
  (zoom=yellow > float=peach > sticky=teal > layout accent). Float only overrides outside float
  layout, where the layout accent is already peach. `refresh_layout_pill` is the SOLE writer and
  carries a generation counter — overlapping chains land out of order, newest wins.
- `property_change` (fired by skhd after fn+shift-w/s/z) IS a live event — it re-reads the focused
  window twice (immediately + 0.12s, since skhd triggers before yabai applies the toggle). Do not
  delete it again.
- Layout pill is interactive: left-click cycles bsp→stack→float, right-click reverses, scroll
  cycles, middle-click is inert (it means "send window" on the space capsules — do not overload it
  here). It relays `sketchybar-island --trigger island_layout` so the notch pill toasts like the
  skhd bindings. Space capsule middle-click sends the focused window to that space without
  following it.
- SF Symbols glyphs live in `/Library/Fonts/SF-Pro*.otf`, NOT in `/System/Library/Fonts/SFNS.ttf`.
  Glyph names there are `uniXXXXXX.medium`, so name→codepoint lookup is impossible; verify a new
  codepoint by rendering a labelled contact sheet with fontTools+Pillow and looking at it.
- EVERY `yabai -m signal --add` MUST carry a `label=`. `--add` is append-only, so an unlabelled
  signal stacks a fresh duplicate every time yabairc is re-sourced (one window open then fires the
  trigger N times). A label makes the add replace in place, so sourcing yabairc stays idempotent.
- No signal sends one bar two triggers; the lua handlers own their own rescan. The bottom bar has
  no yabai widgets — never trigger it from yabairc.
- Non-obvious signals: `application_hidden`/`application_visible` (cmd-H changes per-space counts),
  `display_changed` (focus to an empty display fires no `window_focused`; relays as island
  `window_focus`, NOT the costly `display_change` hotplug re-probe), `mission_control_enter` →
  island `island_hide`, `mission_control_exit` → `layout_change` (Mission Control is where spaces
  get REORDERED, and a reorder fires no `space_*` signal).
- Event routing is tiered — do not promote an event to a heavier handler without checking:
  `updateLayout` (full `--spaces` rescan + capsule rebuild) is for STRUCTURE only (`layout_change`,
  `space_created/destroyed`, `display_change`, mission-control exit). `updateStackIndicator` /
  `refresh_layout_pill` is for membership + focus (`space_windows_refresh`, `window_focus`).
  `scheduleSpaceWindowRefresh` on the observer owns the capsule counts.
- SketchyBar has NO built-in `display_added`/`display_removed` (only `display_change`), so those
  yabai signals are not redundant — they also run `arrange-displays.sh`. But built-in `space_change`
  and `space_windows_change` DO overlap the custom yabai window signals; untested, not swapped.
- yabairc changes need `yabai --restart-service` to take effect.
- Bar `margin` is HORIZONTAL only (the island centres its pill with it), so `external_bar` reserves
 bar `height` alone — do not add margin to it.
- `bar_config.M.bar(extra)` sends ONLY the props passed in (+ `notch_width` only when its resolved
 value changes). It used to accumulate every prop ever passed — `M.apply` seeded the store with the
 FULL bar config — and replay the whole set on every call; inside `sbar.animate` batches (siri
 tint, lock slide) that was a bar-wide batch of constant-valued props per event and made the top +
 bottom bars flicker/stretch wildly whenever Siri opened. sketchybar keeps unspecified props as-is,
 so minimal sends are always correct. Bar-color washes (siri) are SNAPPED, never animated.
- `BAR_NAME` is a lua GLOBAL set in each instance's init.lua ("sketchybar" / "sketchybar-top" /
 "sketchybar-island"). The launchd plists never exported a BAR_NAME env var, so `os.getenv`-based
 instance detection (theme_handler) silently failed — both bars believed they were "bottom"
 (double borders restarts, mis-aimed relays). Shared modules must read the global (env as
 fallback). Shared `siri.lua` loads on top AND bottom (via shared default.lua): both tint, but only
 the top instance relays `island_siri` — dual relays double-triggered the island (pill flicker);
 the island's siri item additionally dedupes consecutive same actions.
- "Item not found" spam in bar logs right after a restart is transient rebuild noise: init does
 `sbar.remove "/.*/"` and async timers/event providers keep firing sets until items.init re-adds
 everything. Benign — fix the thing causing restarts, not the noise.

# Hints

When working with sketchybar, you can inspect for both bars the logs in `/opt/homebrew/var/log/sketchybar/sketchybar.* /tmp/sketchybar-top.*` to inspect print outputs and much more.
Make sure to clean those files to track the latest changes.
