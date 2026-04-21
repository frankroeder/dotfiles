# dotfiles

![](https://flat.badgen.net/badge/platform/Linux,macOS?list=|)
![](https://flat.badgen.net/badge/icon/docker?icon=docker&label)
![](https://flat.badgen.net/badge/license/MIT/blue)

My personal dotfiles for Linux and macOS.

## Installation
- Clone the repository as `~/.dotfiles`
- Consider testing these dotfiles in a Docker container by executing `make test` or `NOSUDO=1 make test`.

## Options
- macOS Intel and ARM: `make macos`
- Linux with sudo rights: `make linux`
- Asahi Linux (Fedora Minimal + DankLinux/Hyprland): `make asahi`
- Linux without sudo rights: `make NOSUDO=1 minimal`

## Asahi install
Start from Fedora Minimal and configure the Wi-Fi and install DankLinux.

From the tty, follow the setup and the following commands:
```sh
# Connect to WIFI
nmcli device wifi connect "SSID" --ask
curl -fsSL https://install.danklinux.com | sh
sudo reboot
```

After reboot:
```sh
git clone https://github.com/frankroeder/dotfiles.git ~/.dotfiles
cd ~/.dotfiles
make asahi
```


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
