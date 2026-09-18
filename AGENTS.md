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
- **Lid**: the switch is `Apple SMC power/lid events`, not `Lid Switch`; no ACPI `/proc/acpi/button/lid` here. Binds live in `monitors.lua` and run `asahi-clamshell`, `locked = true`. **Exactly one owner per case, split by logind's own defaults** — `HandleLidSwitchDocked` is `ignore`, `HandleLidSwitch` is `suspend`, and `Docked` is true only while an external is attached. So with an external, logind stays out and `asahi-clamshell` disables eDP-1; without one, logind suspends and `asahi-clamshell close` must return immediately. It used to DPMS-blank eDP-1 there too, which raced logind's s2idle into a failed modeset (`set_digital_out_mode returned 8000000a`) and hung the machine hard. Do not set `HandleLidSwitch` — omarchy-mac and omarchy-mx-mac both leave it alone and only sed `HandlePowerKey=ignore`; neither has a lid bind at all. Such a hang logs nothing itself — diagnose from `journalctl -b -1`, where the `Lid closed.` → `Suspending...` → `PM: suspend entry` run-up is decisive.
- **s2idle hang**: laptop-only, no HDMI. Lid close reaches `PM: suspend entry (s2idle)` and never `Lid opened` / `PM: suspend exit` — panel black, keys dark, lid/power do not wake (still asleep or stuck entering it). 2026-09-17 bus: 08:15:29 entry, SMC reset, next boot 08:52. An earlier cycle that morning (06:49→07:57) *did* wake; that resume also logged a ghost external modeset (`289c00000.dcp` `2560x1440` with `HPD connected:0`, `80000104`) and internal `8000000a` that still `finished:8500`. `asahi-hdmi sync` on resume does not help a machine that never left s2idle — do not add it. Do not set `HandleLidSwitch=ignore` or restart logind. Recover: hold power ~10s, wait ~15s, tap power. Diagnose `journalctl -b -1` last lines. hypridle `after_sleep_cmd` only runs on a successful `suspend exit`.
- **HDMI**: `monitors.lua` leaves `HDMI-A-1` disabled so a plug cannot modeset on the udev tick (shared DCP: `valid_mode:0` + eDP page-flip freezes the laptop, Dell stays black). `asahi-hdmi` enables it after ~2s and must pass `disabled = false` or the lua rule sticks. `asahi-dpms` only DPMS outputs Hyprland already has enabled (never a disconnected HDMI). Test: `asahi/bin/asahi_hdmi_test.sh`.
- **Mirroring costs you the output**: a mirrored monitor leaves the layout — no workspace, no input — so mirroring `HDMI-A-1` strands the `workspace_rule` 1–4 windows pinned to it (this locked the session: the PDF could not be scrolled, only eDP-1 still answered). The mirror eval therefore carries **only** `mirror = <source>`: a `mode` forces a DCP modeset, and `position = "0x0"` lands on top of the source when the mirror does not take. Source must be an *enabled* output (`monitors all -j` lists disabled ones, and in clamshell eDP-1 is one). Way back is `hyprctl reload` — the Monitors pane's Unmirror/Extend, `Super+Ctrl+Alt+R`, or the pane's 15 s auto-revert that every topology change arms unless `Keep` is clicked. Same rule for external-only: enable the external (with `disabled = false`) *before* eDP-1 goes dark, never leave zero outputs.
- **Notch**: `comp_asahi_system` writes `/etc/modprobe.d/asahi-notch.conf` (`options appledrm show_notch=1`) and rebuilds initramfs with **dracut**. Reboot required. Without this, Asahi crops the panel below the notch.
- **fnmode**: `asahi/modprobe.d/hid_apple.conf` sets `options hid_apple fnmode=1` (media keys on the top row, F-keys behind Fn). Applied live by writing `/sys/module/hid_apple/parameters/fnmode`; boot needs the dracut rebuild so the initramfs snapshot matches.
- **Keyboard backlight**: `XF86Search` / `XF86LaunchA`. Fine step is `SHIFT` on those keys. Display brightness stays on `XF86MonBrightness*`; fine display is `SHIFT +` brightness.
- **Keybinding grammar**: omarchy's tiers, and new binds must land in the right one. Bare `Super` acts on the focused window or navigates; `Super+Shift` is that action's inverse (move vs focus); `Super+Alt` is a variant of it (focus→resize, capture→record, workspace-tab→group-tab) — note `Super+Alt+HJKL` runs `hl.dsp.window.resize { relative = true }`, which moves the **shared split border** in that direction, so the same key grows the left/top window and shrinks the right/bottom one; label such binds by direction, never "grow"/"shrink"; **`Super+Ctrl+<letter>` is a system panel or toggle** (A audio, B bluetooth, D display, W network, P power, S screenshot gallery, T activity, I stay-awake, N night light, E emoji, V clipboard, K keybindings — omarchy's own letters); `Super+Ctrl+Alt` restarts/reloads the stack. Two confusable neighbours: `Super+Ctrl+plus/minus` is the **display scale** (`asahi-monitor-scale`, per-output, persisted), while `Super+Ctrl+Z` / `Super+Ctrl+Alt+Z` is the **cursor magnifier** — `hl.config { cursor = { zoom_factor = … } }` is writable mid-session under the lua provider (unlike `hyprctl keyword`) and `hl.get_config "cursor.zoom_factor"` reads it back, so the bind is a plain lua function, not a dispatcher. Panels go through `quick()` in `bindings.lua` (`launcher quick <key>`; keys are `quickActions` in `LauncherWindow.qml`). `Super+B`/`Super+N` are deliberately free — they were bluetooth/network before the `Super+Ctrl` family existed. **Every bind needs a `desc`**: the launcher's Keys drill is generated from `hyprctl binds`, and `parseHyprBinds` silently drops descless binds (that is why Super+Tab was invisible for months). Binds written as `code:NN` also need a label in `bindCombo`'s `codeNames` map or they render as "code:12" — and the labels follow **de(mac_nodeadkeys)**, where `code:34`/`code:35` are `ü`/`+`, not the US `[`/`]`.
- **Monitor direction binds**: `Super+Ctrl+arrows` (focus) and `Super+Shift+Ctrl+HJKL` (move) must check `hl.get_monitor(dir)` before dispatching. Unguarded, a direction with no display raises `Invalid monitor / monitor doesn't exist` — an error toast for `window.move`, a log warning for `focus` — and laptop-only is the normal state here. `hl.get_monitor` takes the same `l`/`r`/`u`/`d` selector and returns nil, so one `if` per bind is the whole fix; they are generated in a loop in `bindings.lua`.
- **Clipboard secrets**: `asahi-cliphist` watchers run `wl-paste --watch <self> store`, not `… cliphist store`, so every selection passes `store_unless_sensitive` first — anything offering the `x-kde-passwordManagerHint` mime type (what `wl-copy --sensitive` adds) is dropped instead of stored, and `seed_current` checks the same. Without it `asahi-cmd-qr`'s "sensitive" OTP/Wi-Fi payloads were landing in the history anyway. `asahi-cliphist types` prints the current clipboard's mime types and whether it would be filtered — that is how to check whether a given password manager marks its copies at all, since a browser extension using `navigator.clipboard.writeText` sets no hint. `watcher_running` greps the new command line; `start_watcher` pkills the old `--watch cliphist store` form so a pre-filter watcher cannot survive an upgrade.
- **Screenshots**: slurp + grim, no hyprpicker freeze (that baked a stuck cursor into the PNG). Super+F10/F11/F12 (window / smart / display) and the same on Super+mute/vol-/vol+, plus the macOS aliases Super+Ctrl+Shift+3/4/5 (`code:12/13/14` — keycodes so the de/mac_nodeadkeys layout cannot shift them). OCR/QR: Super+Shift/Ctrl+F11. Color picker: Super+Shift+F12. Record: Super+Alt+F11 region, Super+Alt+F12 display, Super+Alt+Shift+F12 display plus pinned webcam overlay (`asahi-webcam`; Super+Alt+ü / + resize — `code:34/35`, which are `[`/`]` only on a US layout). Test: `asahi/bin/asahi_webcam_test.sh`.
- **Browser screenshare**: camera and mic already work (apple-isp + asahi-audio). Chromium screenshare needs `CHROMIUM_USER_FLAGS=--enable-features=WebRTCPipeWireCapturer` in `hypr/conf.d/env.lua` and `environment.d/90-asahi.conf` — Fedora's wrapper ignores `chromium-flags.conf`. No Google Chrome; Fedora already ships `hyprland-share-picker`.
- **asahi-debug**: Fedora Asahi health report (`asahi/bin/asahi-debug [--json]`). dnf/rpm, `wpa_supplicant`, asahi-audio DSP, `speakersafetyd`, `kernel-16k`, HID, notch, sshd mask, no-hibernate. Not pacman/iwd/SDDM. Test: `asahi/bin/asahi_debug_test.sh`. Does not run from `make doctor` and must not flag Hyprland on generic Linux.
- **Night light**: Super+Ctrl+N (part of the `Super+Ctrl` panel family) toggles hyprsunset (`asahi-nightlight`; starts the daemon if needed). On = `temperature` from `asahi/hypr/hyprsunset.conf` (1500K). Off = `hyprctl hyprsunset identity`. Identity profile so autostart tints nothing. Clock-based: uncomment the 20:00 profile.
- **Bar notch**: the cutout is a hole the layout may not use, not a spacer (sketchybar's `bar notch_width`). `BarModel.notchRegionInset` makes `leftRegion`/`rightRegion` clipped Items owning their own side, so nothing can render under the camera. Height is pure geometry — the rows above the 16:10 area (3024x1964 → **74**, macOS's 37pt menu bar at 2x); a lookup table saying 64 left a 10px band behind the housing at scale 1.333. Side region is 954px at 1.333, 632px at 2x, and the right cluster wants ~687 — so `BarHost.ccuCompact` shortens the one widest widget (ccu ~190px → ~106px) when it does not fit. `rightOthers` excludes ccu's own width and compares against its uncompacted `fullWidth`, so the answer cannot change the question. Anything added to the right cluster eats that budget first.
- **Bar tray**: width is capped, not collapsible — any app can add an icon and reflow the strip into the camera. `maxInline` (3) icons on the bar, the rest behind a `+N` pill opening `TrayPanel.qml` downward. Gotchas: `SystemTrayItem.NeedsAttention` (the bare `SystemTrayStatus` name does not exist in QML); a `PanelWindow` popup MUST set `screen:` + `exclusionMode: ExclusionMode.Ignore` like `Osd.qml` or it lands off-screen; `HyprlandFocusGrab` clears instantly on a `focusable: false` layer, so click-outside dismissal does not work.
- **Launcher quick panes**: each deck pane is its own file in `quickshell/remix/modules/launcher/panes/` (`MediaPane`, `NetworkPane`, `MonitorsPane`, `ScreenshotsPane`, `TempPane`, `BatteryPane`, `BluetoothPane`, `StoragePane`, `ClipboardPane`). `LauncherWindow.qml` instantiates them as `Panes.XPane { root: launcherSelf }`; inside a pane `root` is the launcher (fontPx, uiSans/uiFont, launcherGeom, binDir, state). `launcherSelf` exists because `root` inside the pane scope resolves to that property, not the launcher id. `layout_test.js` reads `panes/MonitorsPane.qml` for the monitors assertions. Shared M3 widgets live in `modules/menu` (`MenuSlider`, `MenuHudDial`, `MenuAnim`, `MenuDivider`, `MenuScrollBar`).
- **Recorder panel**: Super+Alt+R (`hl.dsp.global "quickshell:recorder-panel"`) toggles `RecordPanel` (start display/region ± webcam, stop, elapsed clock, file size, recent recordings with open/delete). The bar's REC chip only shows while recording: click opens the panel, right-click stops. State comes from `asahi-cmd-record status --json` (markers `$XDG_RUNTIME_DIR/asahi-record.{pid,file,start}`) via the `Recorder` singleton in `quickshell/remix/services`. No pause: this wf-recorder build exits on SIGUSR1. IPC: `qs -c remix ipc call recording panel`; launcher action "Recorder".
- **There is one wallpaper picker**, `WallpaperManager` (Super+Shift+W → `wallpaper toggle`, opens on the focused monitor). It is standalone: `ipc: "wallpaper"` in `quickActions` **and** `wallpaper: true` in `quickDeckHidden`, exactly like Packages and Recorder — so it is not a Quick tile, but typing "wall"/"paper" still finds it (the action list ignores `quickDeckHidden`, and search activation dispatches `ipc` the same way).
- **Deck rule — a visible Quick tile must have a pane.** `quickPaneKey` falls back to `t.key`, not just `t.mode`, so *every* visible tile asks `quickDetailFor` for a pane; an entry with only `ipc:`/`command:` has none and drops to `quickDefaultComp`'s bare "select a quick tile". That is exactly what happened when Wallpapers was first switched to `ipc:` while left visible. All 16 paneless actions are in `quickDeckHidden`, and `wallpaper_carousel_test.js` derives that list from `quickActions` and fails if any of them is left in the deck. It used to be a second, in-launcher `mode:` pane (`quickWallpaperComp`) that reimplemented the carousel, grid, search, shuffle/apply and hint row; that clone is deleted. When adding picker features, there is only one place to add them. `WallpaperCarousel` (a three-slot Row of prev/current/next; ListView clipped neighbours, PathView drifted while the card animated) is its browse strip. It centres the applied wallpaper; ←/→, Ctrl+h/l or the wheel browse; ⏎, Apply or a click on any tile applies (`WallpaperService.setWallpaper`), Esc/close restores (`stopPreview`). "All" expands the filter + grid. Previews only fire while the picker is shown and after the anchor is placed; `WallpaperService` re-asserts the saved wallpaper on load in case one was left behind.
- **Live preview is opt-in** (`WallpaperService.liveMode`, default off): browsing is thumbnails only until you arm it, so the desktop does not churn while you scroll a few hundred wallpapers. **Shift** toggles it, **Shift+←/→** arms it, and the "Live" chip does the same by mouse. Bare Shift is ignored while the search field has focus, where it is just a modifier for capitals. Armed, every preselected tile repaints in real time — the centre tile on the desktop (`hyprctl hyprpaper`) plus the shell palette and Ghostty (`asahi-autotheme --preview --variant <flavour>` prints the palette JSON → `DefaultTheme.applyJson`, and installs `asahi-adaptive` + `adaptive.css` then `reload-config` — Ghostty does not read `state/ghostty.theme`; no GTK/LibreWolf/colors.json). The debounce is 70ms, not a wait: a full palette pass is ~110ms, so it only swallows key-repeat and fires once browsing pauses.
- **Wallpaper color index**: `wallpaper_thumbs.colorIndexScript` samples six dominant colors per wallpaper *from the cached thumb* (`magick -colors 6 histogram:`, ~1.3s over 230 cold, one `find` once warm) into `<thumb cache>/colors.tsv`; `wallpaper_colors.js` parses it into `{swatches, accent, L, hue, bucket, tone}`. Hue buckets and the accent pick mirror `theme/palette.py` (`_pick` "accent", `LIGHT_MODE_THRESHOLD`) so the dot beside a wallpaper matches the accent it will generate and the Dark/Light chips predict the mode. Filter/sort state lives on `WallpaperService` (`filterTone`, `filterBucket`, `sortKey`) and the list goes through `WallpaperService.arranged(query)`. `WallpaperFilterBar` (tone chips, color dots, sort cycle), `WallpaperPalette` (swatch strip for the centre tile) and `WallpaperFlavors` (flavour chips) are the picker's rows. Test: `node asahi/quickshell/remix/modules/wallpaper/wallpaper_colors_test.js`.
- **Appearance / wallpaper autotheme**: Hyprland does not implement `org.freedesktop.impl.portal.Settings`. `asahi/xdg-desktop-portal/portals.conf` pins Settings to **gtk** (`default=hyprland;gtk`) so LibreWolf, Chromium, GTK4, Qt (`QT_QPA_PLATFORMTHEME=gtk3`), and nvim see `prefers-color-scheme`. Autostart seeds `prefer-dark` / `adw-gtk3-dark` / `Papirus-Dark`, then `asahi-autotheme` overrides from wallpaper lightness (omagen-inspired; no matugen). `--mode {auto,dark,light}` forces the mode instead of deriving it.
- **Theme flavours** (`asahi-autotheme --variant`, the picker's Flavour row): `source content vibrant calm mono` — matugen `scheme-*` analogues (DankMaterialShell's `matugen_type`) but plain OKLCH shaping of one palette, not a second algorithm per scheme. **Saturation is a fraction of the room available (grey .. sRGB gamut edge), never a multiplier.** That is the whole reason there are five and not eight: multipliers pushed every strong flavour past the gamut edge, `gamut_map` clipped them all to the *same* accent, and vibrant/expressive/content were indistinguishable. `theme/oklab.max_chroma(L, H)` gives the edge; `palette._saturate` interpolates against it. `Flavor` is five scalars (`accent_sat`, `accent_dl`, `surface_c`, `ansi_sat`, `fidelity`). The flavours deliberately pull *different* axes apart rather than all turning chroma up: `content` tints the surfaces hard (`surface_c=1.6`) and keeps wallpaper hues verbatim (`fidelity`), `vibrant` does the opposite — gamut-edge accents on neutral panels (`surface_c=0.45`). `test_palette.py::test_no_two_flavours_look_alike` is the regression guard (distinct accents, each ≥0.012 chroma apart). `FLAVORS` is the single source of truth: the CLI takes `choices=tuple(FLAVORS)` and `wallpaper_colors_test.js` fails if the QML list drifts. The chosen flavour rides on every autotheme call (apply, preview, restore) and survives restarts because autotheme writes `variant` into colors.json, which `WallpaperService.flavor` binds to until the user picks one. That writes `~/.local/state/asahi-theme/` (colors.json for Quickshell `DefaultTheme`/`Style`, Ghostty theme+GTK CSS, Hyprland borders, hyprlock vars, LibreWolf `asahi-adaptive.css`, btop `asahi-adaptive.theme`, GTK3/4 CSS, Chromium `BrowserThemeColor`) and live-applies gsettings + `hyprctl eval` + Ghostty `reload-config` + `pkill -SIGUSR2 btop`. GTK ini in `~/.config/gtk-{3,4}.0/settings.ini` is a real file (not a symlink) so light/dark flips do not dirty git. Unset (`default` / portal `0`) is treated as light. Test: `asahi/theme/tests/test_palette.py`, `asahi/theme/smoke_test.sh`.
- **What can and cannot repaint live**: Ghostty (own `reload-config`), Quickshell (`FileView` on colors.json), Hyprland borders (`hyprctl eval`), btop (SIGUSR2) update in place. **GTK3 never re-reads `~/.config/gtk-3.0/gtk.css`** — not on file change, not on touching gtk.css, not on a `gtk-theme-name` round-trip, not on a prefer-dark toggle, not even for a freshly created widget; only a new process picks it up (all five measured). **LibreWolf cannot repaint live either, and the obvious fix does not work** — details below. Do not add watchers trying to beat either.
- **LibreWolf live reload is a dead end (measured, do not retry)**: `userChrome.css` is parsed once at startup, and the usual escape — `nsIStyleSheetService` from `librewolf.overrides.cfg` — cannot run, because **the autoconfig sandbox exposes no XPCOM**: 84 globals, pure JS plus `pref`/`getPref`/`getenv`, no `Components`/`Cc`/`Ci`/`Services`, and `general.config.sandbox_enabled=false` in the profile does not change it. A new palette lands on the next browser start. To inspect a running instance: `librewolf --headless --no-remote --marionette -remote-allow-system-access --profile <dir>`, then drive Marionette on port 2828 and read `getComputedStyle(document.documentElement)` in chrome context.
- **The vertical-tabs sidebar is shadow DOM** (`sidebar-main` is a `MozLitElement`; `:host` in `sidebar-main.css`, `::part()` from outside). Element selectors in `userChrome.css` cannot reach inside it — **only inherited custom properties cross the boundary**, which is why the sidebar was the most visibly unthemed part. It consumes design-system tokens (`--background-color-list-item-hover`, `--text-color-deemphasized`, `--background-color-box`, `--button-*-ghost-*`, `--tab-selected-outline-color`, `--color-accent-attention`), so those are set on `:root` too. `--sidebar-box-background/-color` are locally defined as translucent/`currentColor` and adapt on their own; leave them.
- **LibreWolf chrome variables**: `write_librewolf_css` must emit names *current* Firefox still reads. 17 of the 26 it used to emit were dead and failed **silently** — that is what left highlight colors stuck on Firefox defaults while the rest of the chrome followed the wallpaper. Dead: `--lwt-toolbar-field-*`, `--lwt-selected-tab-background-color`, `--urlbarView-highlight-*`, `--tab-selected-bgcolor`, `--tab-selected-color`, `--urlbar-box-bgcolor`, `--arrowpanel-*`, `--toolbar-bgcolor`, `--toolbar-color`, `--panel-color`, `--toolbarbutton-{hover,active}-background`. Two traps when checking a name:
  - **Substring grep lies.** `--panel-background` matches inside `--panel-background-color`, and `--toolbar-color` "exists" only as `--toolbar-color-scheme`. Require a non-`[A-Za-z0-9_-]` char after the name.
  - **`chrome/devtools/**` is a different styling world** userChrome.css never reaches. `--toolbarbutton-hover-background` is alive *there* and dead in the browser chrome; scope the search to exclude it.
  `--lwt-*` is a third trap: every consumer sits under `:root[lwtheme]`, and `LightweightThemeConsumer` sets that attribute only when `theme.id != "default-theme@mozilla.org"` — so with the stock system theme they are unreachable. Set the consuming variable (`--toolbox-background-color`, `--toolbar-field-*`) instead. Menu hover and urlbar text selection resolve to GTK system colors (`-moz-menuhover`, `Highlight`) with no themeable variable, so `userChrome.css` pins them by rule. To check a name: unzip **both** `omni.ja` files (`/usr/share/librewolf/omni.ja` and `.../browser/omni.ja`) and grep for `var(--name)` outside `chrome/devtools`. `smoke_test.sh` and `test_apply.py` fail on the dead spellings.
- **sshd**: Fedora ships sshd *enabled*, so a fresh install listens on `0.0.0.0:22` with password auth. Nothing uses inbound SSH here — the service is disabled and masked (`sudo systemctl disable --now sshd && sudo systemctl mask sshd.service sshd.socket`). Re-check after a Fedora release upgrade, which can unmask units.
- **Notification images**: `image-path` comes from any app on the session bus, and Qt fetches `http(s)` sources, so `NotificationCenter.qml`'s `localImage()` renders only `image:`/`file:`/`/…`. Summary and body are `Text.PlainText`, which is what keeps `<img src>` in a body inert.
- **bash 5.3**: Fedora 44 ships bash 5.3, where an `EXIT` trap whose **last command returns non-zero** overrides a successful script's exit status under `set -e`. A handler ending on `[[ -n $x ]] && rm -f "$x"` makes a clean run exit 1. End every trap handler on something that cannot fail (`|| true`, or an `if` block rather than a trailing `&&`). Existing handlers are clean; check new ones with `bash -c 'set -e; c(){ [[ -n "$s" ]] && rm -f "$s"; }; trap c EXIT; true'; echo $?`.
- **Trailing `&&` in a function**: the same rule bites any function whose last line is `[ -n "$x" ] && printf ...`. When `$x` is empty the function returns 1, and `out=$(f)` under `set -e` kills the script before it prints anything — `asahi-network` lost its whole JSON payload this way whenever `nmcli` reported no BSSID. Use `if` blocks for the optional tail lines. Interactive helpers (`shared/docker_functions.sh`, `shared/fzf.sh`) are sourced into zsh without `set -e`, so the pattern is harmless there.
- **Apple HID race**: the internal keyboard/trackpad arrive over dockchannel-hid and bind to `hid-generic` first, then get destroyed and re-created when the real drivers load; on an unlucky boot logind's `TakeDevice` loses that race and libinput never retries, killing the device for the session. `asahi/dracut.conf.d/10-asahi-hid.conf` force-loads `hid_apple` from the initramfs so it binds correctly the first time (installed by `comp_asahi_system`, which then reruns `dracut -f`). Only `hid_apple` is listed: Fedora's Asahi kernel builds `hid_magicmouse` **in** (`modinfo -n` → `(builtin)`), so naming it is a no-op — check before adding drivers. Verify bindings with `ls /sys/bus/hid/drivers/` and `readlink -f /sys/bus/hid/devices/*/driver`.
- **Audio**: the Asahi stack (`asahi-audio` UCM + DSP chain, `speakersafetyd`, `rtkit`, `pipewire-pulseaudio`) ships and runs correctly on Fedora Asahi Remix. Do **not** port omarchy's `install/hardware/apple/audio.sh` — it exists because Arch/ALARM has to bolt this on. Confirm RT scheduling on the *thread*, not the process: `ps -eLo comm,rtprio,cls | grep data-loop` should read `20 RR` (a bare `ps -eo` shows only the main thread and always looks unprivileged).
- **Trackpad taps**: the macOS set is `tap_to_click = true` with `tap_and_drag = false` and `drag_lock = false` (tap-click, no tap-drag), plus `clickfinger_behavior` and `scroll_factor = 0.2`. omarchy runs `tap_to_click = false` on Asahi, noting that `disable_while_typing` alone does not stop stray taps while typing on this touchpad; `input.lua` keeps it `true` deliberately — if phantom clicks while typing ever show up, that pairing is the known cause.
- **Window management defaults**: `general.lua` carries omarchy's tuning — `dwindle.force_split = 2` (new windows go right/below instead of following the mouse quadrant), `binds.hide_special_on_workspace_change` (the SUPER+S scratchpad stops trailing between workspaces), `misc.allow_session_lock_restore` (a crashed hyprlock can be replaced instead of wedging the session), `misc.on_focus_under_fullscreen`, `misc.initial_workspace_tracking = 0`, `misc.anr_missed_pings = 3`. `group`/`groupbar` is themed to the Catppuccin borders because SUPER+W groups windows and the stock groupbar clashes. Validate key names against `/usr/share/hypr/stubs/hl.meta.lua` (it enumerates every config path, e.g. `group.col.border_active` — *not* `active_border`), then `hyprctl reload && hyprctl configerrors`.
- **Terminal trackpad scroll**: `rules.lua` sets `scroll_touchpad = 0.2` for `com.mitchellh.ghostty`, because ghostty scrolls by lines rather than pixels. 0.2 is omarchy's Asahi value for this pairing and is now also the global `touchpad.scroll_factor`, so the rule is currently a no-op — keep it anyway, it is what stops a later global bump from re-speeding the terminal.
- **asahi/bin structure**: shared shell helpers live in `asahi/bin/lib/common.sh` (`display_device`, `keyboard_device`, `focused_monitor`, plus `saved_scale` / `anchor_offset` for the display work), sourced with `. "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/lib/common.sh"` — `readlink -f` so a script reached through a symlink still finds it. `asahi-launch` is the ONE place that knows the `uwsm-app`/`setsid` dance; `asahi-launch-tui`, `-wifi` and `-bluetooth` exec through it instead of repeating it. Scripts address their siblings via that same `$(dirname ...)`, not a hardcoded `$HOME/.dotfiles`. `install/components.sh` chmods `asahi/bin/*`, which skips `lib/` because it is a directory — keep sourced files there.
- **Quickshell launch**: never `qs -d`. Its fork/pipe handshake `qFatal()`s the child (EPIPE in `exitDaemon`) whenever the parent is gone before the child reports ready — `pkill -x qs`, or hypridle's `on-resume` stop racing a `start`; that was 8 SIGABRT coredumps in a week. `asahi-start-quickshell` and `asahi-screensaver` use `setsid -f qs -n -c <module>`; `-n` still keeps one instance. `asahi-debug` has a `coredumps` check (desktop stack, last 7 days) — look there first when the bar "just vanished".
- **Stay awake**: ONE flag, `$XDG_RUNTIME_DIR/asahi-stay-awake` (session-scoped, gone on reboot), owned by `asahi-stay-awake on|off|toggle|status|unless <cmd>`. `hypridle.conf` listeners run through `asahi-stay-awake unless …`, so hypridle never sees the path and the bar chip only calls the script.
- **Timers**: `asahi-timer add <dur> [label]` is a transient `systemd-run --user --on-active` unit (`asahi-timer-<ns-suffix>`, label in `--description`) that fires `notify-send` — survives Quickshell restarts, dies with the session. `list --json` reads `systemctl --user list-timers` + unit descriptions; the bar `timerChip` polls it (1s while a timer is armed, else 4s) and cancels the soonest one on click. Launcher: `:timer 10m tea`, parsing in `arg_commands.js` (`parseTimer`/`formatSeconds`, tested).
- **Lua dispatchers**: legacy `hyprctl dispatch <name> <args>` is dead ("expected a dispatcher") — use `hyprctl dispatch 'hl.dsp.window.float({ action = "enable" })'`; `--batch 'dispatch …; dispatch …'` works. `resize({ x, y })` is exact (pass `relative = true` for a delta), `fullscreen` needs `mode` alongside `action = "unset"`, and the float must be its own call — batched resize/pin still see a tiled window. Maximized windows refuse resize + pin. Names and args: `/usr/share/hypr/stubs/hl.meta.lua`, or probe with `hyprctl eval` (building a dispatcher does not run it).
- **`hyprctl reload` does not reset a device, it stops overriding it**: a value pushed with `hyprctl eval 'hl.device({…})'` outlives the reload unless some rule asserts a good one, and `hl.device` validates field *names* strictly (`unknown field 'x'`) but **not values** — `accel_profile = "custom nonsense"` is accepted and silently kills pointer motion until reboot. So never probe values against a live input device, and always keep an explicit `hl.device` rule for the trackpad in `input.lua` even when running a stock profile: that rule is the only thing that makes a reload a working escape hatch.
- **Trackpad pointer feel**: `input.lua` pins a `hl.device` rule on `apple-mtp-multi-touch` with a stock macOS tracking-speed libinput curve (`com.apple.mouse.scaling` 0.6875) — `accel_profile`/`scroll_points` are `"<step> <output velocity per step>"`, both step `1.0` with six points. Slow-drag samples are 0.10/0.22 (not 0.03 — that crawled vs macOS); high-end stays damped (last motion sample 0.86, not 1.25). Raise earlier points for slow drags, later points for flicks. Scroll is accelerated too, not 1:1. libinput ignores `sensitivity` under a custom profile, so the curve alone owns pointer feel here (`input.sensitivity` stays 0). Swipes: `gestures.workspace_swipe_cancel_ratio = 0.25` (commit after 25% travel) and `general.lua`'s `hl.gesture` 3-finger horizontal workspace swipe at `scale = 0.75`.
- **Monitor events are userdata, not tables**: `hl.on("monitor.added"/"monitor.removed", function(m))` hands an `HL.Monitor` **userdata**, so a `type(m) == "table"` name reader silently yields `""`. That blacked every screen on lid close: `hdmi_cmd` fell past its `^HDMI` guard and ran `asahi-hdmi removed` with no argument, which defaults to `HDMI-A-1` and disabled the external; `asahi-clamshell apply` then saw no external and re-enabled eDP-1 at backlight 0. Read `.name` off userdata too, and make an unknown name a no-op — never let one reach a script whose argument defaults to a real output.
- **Window pop**: Super+O → `asahi-window-pop [w h]` floats, resizes (1300x900 clamped to the monitor), centers, pins, tags `pop`; second press retiles.
- **Display scale**: Super+Ctrl+plus/minus → `asahi-monitor-scale up|down|cycle|set|apply|status`. Legal scales are presets snapped to divisors of gcd(w·120, h·120) — eDP-1 is 1 / 1.333333 / 2 only. Saved per output in `$XDG_RUNTIME_DIR/asahi-monitor-scale/<name>` and read back through `saved_scale` (`lib/common.sh`) by `asahi-hdmi`, `asahi-clamshell` and `apply`, so a reload / replug / lid open keeps the pick instead of snapping back to monitors.lua. The file is keyed by output name, and HDMI-A-1 is reused by both externals — a scale saved for the 4K sink is illegal on the 1440p one. **Positions must be derived, never pinned**: logical size is pixels/scale, and the externals are anchored by the edge facing eDP-1 (LG right edge on x = 0, Dell bottom edge on y = 0), so `anchor_offset` (`lib/common.sh`) recomputes that coordinate in both `asahi-monitor-scale` and `asahi-hdmi`. A fixed `-2048x-360` is only correct at scale 1.875; every other scale lapped the panel and tripped "Your monitor layout is set up incorrectly … overlaps with other monitor(s)".
- **Clamshell**: lid binds run `asahi-clamshell close|open`, and it handles the external case only. Close returns immediately (`external_on || exit 0`) when nothing else is attached — logind owns that path, see **Lid**. With an external: eDP-1 `disabled = true` + flag `$XDG_RUNTIME_DIR/asahi-clamshell`. Open → eDP-1 back (mode/position from monitors.lua, scale via `saved_scale`). `apply` re-asserts on `config.reloaded` and on `monitor.removed`, and is what guarantees never zero outputs when the external goes away mid-clamshell.
- **Speed test**: `asahi-speedtest [--json]` — curl against `speed.cloudflare.com`, 50 MB down / 25 MB up (100 MB is refused 403), ~20 s. Button in the launcher's network pane.
- **No touchpad toggle**: removed on request; `input.lua`'s `disable_while_typing` is the only mechanism. Live device rules would need `hyprctl eval 'hl.device({ … })'` — `hyprctl keyword` is rejected by the lua provider and `hyprctl reload` wipes eval'd rules.
- **Wi-Fi share QR**: `asahi-wifi-qr` renders `WIFI:T:…;S:…;P:…;;` of the active connection with `qrencode` (asahi/dnf.sh) into `$XDG_RUNTIME_DIR` (mode 600) and prints the path; the network pane's "Share" button shows it. `nmcli -s` yields the PSK without a polkit prompt for the user's own connections.
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
