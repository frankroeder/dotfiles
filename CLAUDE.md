# General

These dotfiles target macOS (Apple Silicon), Linux x86, Asahi Fedora (aarch64 ARM).
Share as much as possible across OS while respecting arch diffs.
`install.sh` defines 5 profiles (micro, minimal, linux, macos, asahi; `make <profile>` wraps it) using
symlinks, brew/dnf installs, services. Always differentiate Linux by arch.

- macOS WM: yabai+skhd or aerospace/flashspace + sketchybar (`sketchybar/{top,bottom,island}/`)
- Asahi: Hyprland (`asahi/hypr/hyprland.lua` + `conf.d/*.lua`), quickshell remix
  (`asahi/quickshell/remix/`), hyprpaper/hyprlock/hypridle, ghostty, `asahi/bin`
- Shared: nvim (`nvim/`), zsh (zim+dots), mpv, ghostty

Profiles: `micro` (bash/tmux/htop, almost no rights), `minimal` (nvim/zsh/python/node,
local, no sudo), `linux` (full desktop/server), `macos` (Apple Silicon suite), `asahi`
(Linux ARM suite).

# Executing

- Run smoketests; inspect outputs; verify symlinks. Asahi: `make test-asahi` runs every Asahi test
  (Quickshell JS, `asahi/bin` shell + Python, theme pytest, Lua syntax; ~25 s; fakes or read-only checks) except
  `asahi/theme/smoke_test.sh` (it rewrites the live theme state).
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
- Everything Asahi (docs, rules, gotchas) lives in `asahi/CLAUDE.md`.
  Read it before touching Asahi bits outside `asahi/` too: `comp_asahi_*` / doctor in `install/components.sh`,
  `install.sh asahi-*`, the `test-asahi` target, zsh keychain / `BASH_ENV` handling, nvim spell cycle.

## Shared
- **CCU**: one core, `sketchybar/helpers/ccu_common.py`. `asahi-ccu` reuses the cost scan (every transcript, ~2–4 s CPU) for 10 min
  (`~/.cache/asahi/ccu.cost.json`, dropped at midnight): popup cost figures lag up to that. Front-ends: Lua literal (sketchybar) or
  `--json` (`asahi-ccu`). `ccu_cost.py` is JSON-only (reserved keys). Claude plan = credentials `subscriptionType` +
  `rateLimitTier` (e.g. "Pro · 1x"), email from `~/.claude.json` (local reads, no API). Asahi chip (idea: dancik/limitbar):
  usage ring (arc + colour = used share of the **main** weekly / monthly window) around the provider mark, then % and
  countdown (short form drops the countdown), then one 4 px mini bar per other window (`chip_subs`: 5-hour session, model
  pools; usage colours). Red chip wash = the main window ≥ 90 % only — sub-limit badges / washes read as the main window
  being full (no `wk`/`5h` superscripts: rejected; the countdown tells the window). Marks are `PathSvg` paths in `components/marks.js` filled by a `Shape` —
  no MultiEffect tint (a layer pass in an always-on bar; layered marks also stayed blank in the offscreen harness after a
  late source change). Popup: main window (weekly / monthly) kept as "N% of … limit used" + reset
  line over a full-width bar (preferred to a row); the other windows (session, Fable, Cursor pools) are
  2-column mini tiles (`subLimits`: name … %, 4 px bar, "Resets Oct 22, 3:20 PM · 2h 4m" — absolute date + countdown,
  only where `ownReset` (≠ main reset ± 5 min); red ≥ 90 %, "reset, awaiting update" once passed) — label | bar | % rows looked misaligned. Plan only as the popup pill
  (not in the chip: rejected), header click opens the usage page. Chip rotation = `chipSwap` (roll up + fade, `shownIndex` swaps halfway, ring scales in, arc eases to the new share). Grok Bot `usagePercent` is 0–100 (the app labels 0 < x < 1 as "1%"; reading ≤ 1
  as a fraction showed 0.77 % as 77 %). Cursor pools carry `span_sec` (else they read "weekly"). Test:
  `uv run --no-project python asahi/bin/asahi_ccu_test.py`.
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
