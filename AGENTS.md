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
  prio or same kind. Dismiss uses cancellable `sbar.delay`. Restore snaps idle geometry outside
  animate then hides.
- `display.refresh()` re-probes notch + arrangement rows on `display_change` (hotplug).
- Every expand grows out of the notch (idle seed in island_core); consecutive expands morph.
- NEVER put constant-valued numeric props inside `sbar.animate` batches when value is unchanged
  (1px jitter). Expand only animates changing geometry. Restore snaps idle geometry un-animated
  then hides (avoids omitted margin/width zeroing to full-display stretch).
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
 Icon-only strip (mic/volume/wifi/bt/coffee) is 18pt; bluetooth is Hack Nerd Font 18 (no SF
 bluetooth glyph — SF Pro fallback made 󰂯 look tiny vs wifi's 􀙇). Wifi→bt→coffee item pads
 are 4px so those icons don't glue together after rates went hover-only.
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
- Island pill widths (settings.lua `island.widths`) are FIXED per kind:
 `w = 2 × (16px text pad + measured longest left text in SF Pro Semibold 15 + 12px slack) +
 220px probed notch`, floored by the right-lobe minimum (wing ≥ 4+48+16 → w ≥ 356, binds siri).
 Undersizing runs the text into the notch (the old bluetooth 580 was 10px short for
 "Momentum4… · 100%" = 156px). Per-toast slimming (fit width to the actual text) was TRIED AND
 REVERTED: the probed `display.notch_width` (220) underreads the physical cutout, so tight-fit
 pills clipped real text behind the notch — only the generous fixed worst-case wings absorb the
 probe error. Do not reintroduce dynamic pill widths without first measuring the true cutout.
- App/device names in island pills are truncated with `utils.ellipsize` (codepoint-aware,
 utf8.offset) — byte-based `string.sub` split multibyte names ("Café…") into mojibake.
- A long-lived sketchybar process can silently corrupt: `--bar hidden=…` becomes a no-op AND all
 bar props inside `--animate` batches get dropped, while direct un-animated sets still apply.
 Symptoms on the island: pills stuck at idle height/margin while expanded, bar never re-hiding
 after retract. `--reload` does NOT clear it — only a full process restart does
 (`launchctl kickstart -k gui/$UID/git.frank.sketchybar-island`). Diagnose by comparing a direct
 `--bar margin=N` (applies) against `--animate tanh 15 --bar margin=N` (dropped when corrupted).
- sketchybar TRIMS leading label whitespace — ASCII space AND NBSP alike — so left-padding a
 digit-first string is impossible; interior padding survives. FIGURE SPACE (U+2007) is exactly
 digit-wide in SF Pro (tabular digits), so stacked pairs (eCPU/pCPU, RAM/SWP) drop zero-padding
 ("pCPU 07%") for interior U+2007 ("pCPU␇7%") and stay column-aligned. Power keeps a fixed 34px
 right-aligned label box so 9 W ↔ 19 W cannot resize the capsule. ccu popup chart GRIDS still
 need Menlo (real mono) — space-padded cells drift in any proportional face.
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

# Hints

When working with sketchybar, you can inspect for both bars the logs in `/opt/homebrew/var/log/sketchybar/sketchybar.* /tmp/sketchybar-top.*` to inspect print outputs and much more.
Make sure to clean those files to track the latest changes.
