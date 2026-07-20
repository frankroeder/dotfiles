# dotfiles

![](https://flat.badgen.net/badge/platform/Linux,macOS,AsahiLinux?list=|)
![](https://flat.badgen.net/badge/icon/docker?icon=docker&label)
![](https://flat.badgen.net/badge/icon/container?icon=apple&label)
![](https://flat.badgen.net/badge/license/MIT/green)

My personal dotfiles for Linux, macOS, and Asahi Linux.

## Installation

Clone the repository as `~/.dotfiles`, then run a **profile**. Install logic lives
in `install.sh`; the `Makefile` keeps thin wrappers plus test/benchmark/format.

| Setup | Command |
| --- | --- |
| macOS Intel/ARM | `make macos` |
| Linux with sudo | `make linux` |
| Linux without sudo | `make minimal` |
| Bash-only, no tooling | `make micro` |
| Asahi (Fedora Minimal + Hyprland) | `make asahi` |

Profiles are **idempotent**: simply rerun one (e.g. `./install.sh macos`) to
refresh configs and re-apply symlinks; tools already installed are skipped.
Test in a container with `make test` (or `NOSUDO=1 make test`).

### Options

Profiles share components (`zsh`, `git`, `nvim`, …) runnable in isolation, e.g.
`./install.sh zsh`. Run `./install.sh help` for the full list.

- `--no-sudo` — skip steps needing root (implied by `minimal`).
- `make doctor` — report binaries, services, and config-symlink health.
- `make after` — post-install: git setup, Treesitter parsers, desktop services.

### Maintenance
- `make check` — Neovim health check.
- `make benchmark` — Neovim and Zsh startup times.
- `make format` — format Lua files with stylua.
- `make uninstall` — remove installed symlinks and configs.

## Asahi install
Start from Fedora Minimal and configure Wi-Fi.

From the tty, follow the setup and the following commands:
```sh
# Connect to WIFI
nmcli device wifi connect "SSID" --ask
sudo reboot
```

After reboot:
```sh
git clone https://github.com/frankroeder/dotfiles.git ~/.dotfiles
cd ~/.dotfiles
make asahi
```

This applies a minimal Hyprland desktop with Ghostty, Quickshell, Mako, Hypridle, and Hyprlock.


## Local configuration files
The following list of files could be created and used to define local configurations:
- `~/.local.gitconfig`
- `~/.local.zsh`
- `~/.local.tmux`
- `~/.localnvim.lua`

## References

- https://github.com/neovim/neovim
- https://github.com/robbyrussell/oh-my-zsh
- https://github.com/htr3n/zsh-config
- https://github.com/sindresorhus/pure
- https://github.com/nikitabobko/AeroSpace
- https://github.com/ghostty-org/ghostty
