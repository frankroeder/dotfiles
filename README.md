# dotfiles

![](https://flat.badgen.net/badge/platform/Linux,macOS?list=|)
![](https://flat.badgen.net/badge/icon/docker?icon=docker&label)
![](https://flat.badgen.net/badge/license/MIT/blue)

My personal dotfiles for Linux and macOS.

## Installation
- Clone the repository as `~/.dotfiles`
- Consider to test these dotfiles in a docker container by executing `make test` or `NOSUDO=1 make test`.

## Options
- macOS Intel and ARM: `make macos`
- Linux with sudo rights: `make linux`
- Linux without sudo rights: `make NOSUDO=1 minimal`

## Local configuration files
The following list of files could be created and used to define local configurations:
- `~/.local.gitconfig`
- `~/.local.zsh`
- `~/.local.tmux`
- `~/.local.vim`

## References

- https://github.com/neovim/neovim
- https://github.com/robbyrussell/oh-my-zsh
- https://github.com/htr3n/zsh-config
- https://github.com/sindresorhus/pure
