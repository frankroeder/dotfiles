# omarchy-mac (quattro) integration map for Asahi dotfiles

Audit of https://github.com/omarchy-mac/omarchy-mac branch `quattro`, and what was integrated into these dotfiles.

## Integrated (this goal)

### Top menu bar (Quickshell)

| omarchy-mac | Asahi dotfiles |
|-------------|----------------|
| `shell/plugins/bar/Bar.qml` — flat bar, notch floor, transparent mode | `asahi/quickshell/remix/modules/bar/BarHost.qml` |
| `shell/plugins/bar/BarModel.js` — `notchHeight()`, measured cutouts | `asahi/quickshell/remix/modules/bar/BarModel.js` + `notchSpacerWidth()` |
| Empty center / workspaces left (notch design) | Workspaces on left; center spacer on `eDP-*` |
| `shell/Ui/WidgetButton.qml` — flat controls | `asahi/quickshell/remix/modules/bar/WidgetButton.qml` |
| `config/omarchy/shell.json` right-cluster rhythm | Clock `ddd dd MMM HH:mm`; indicators + tray on right |
| `Style.bar` typography (12px body) | `Style.barHeight`, `barFontBody`, `barEdgeMargin` |
| Bar transparency toggle | `asahi/bin/asahi-toggle-bar-solid` + `~/.local/state/asahi/toggles/bar-transparent` |

## Usage

- Default bar is **solid** crust tint. Run `asahi-toggle-bar-solid` to switch transparent/solid.
- `PanelWindow` must wrap `BarHost` in `shell.qml` (Variants does not inject `modelData` into imported `PanelWindow` types).
- Reboot after first install if notch or HID modules were added to initramfs.

### Apple Silicon Linux

| omarchy-mac | Asahi dotfiles |
|-------------|----------------|
| `install/hardware/apple/enable-notch.sh` | Already in `install/components.sh` (`comp_asahi_system`) |
| `install/hardware/apple/fix-asahi-hid-race.sh` | Added to `comp_asahi_system` (`apple_hid_modules.conf` + dracut) |
| Lid switch naming (`Apple SMC power/lid events`) | Already in `asahi/hypr/conf.d/monitors.lua` |
| `appleSiliconHost` probe in Bar.qml | `BarHost.qml` device-tree probe |

## Not integrated (candidates for later)

- Full omarchy **plugin registry** (`shell/shell.qml`, `PluginRegistry`, per-widget panels) — large architectural change; Asahi keeps modular QML components + existing popups.
- **Weather**, **keyboard layout**, **agents**, **monitor/power** bar widgets and panel UIs — need Fedora equivalents and new `asahi/bin` helpers.
- **Night light**, **dictation**, **reminder** indicators — macOS-centric or missing services on Fedora.
- **Clipboard history**, **emoji picker**, **image picker** plugins — useful but separate feature work.
- Arch/Alarm-specific installer (`arm-mirrors.sh`, pacman, mkinitcpio `asahi` hook tests) — Fedora Asahi Remix uses dracut/dnf, not applicable.
- T2 Intel Mac fixes (`fix-t2.sh`, `fix-brcmfmac-supplicant.sh`) — not Apple Silicon Asahi targets.
- Theme pack (`themes/*`) — Asahi uses Catppuccin via `DefaultTheme.qml` / wallpaper service.
- **Transparent foreground sampling** (`omarchy-bar-text-color`) — not ported; bar uses fixed `Style.text`.

## References

- omarchy-mac quattro bar layout: `config/omarchy/shell.json` (empty `center`, clock on `right`)
- Notch height math: `shell/plugins/bar/BarModel.js`
- Apple HID race: `install/hardware/apple/fix-asahi-hid-race.sh`
