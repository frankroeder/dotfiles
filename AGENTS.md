# General

These dotfiles are for macOS, Linux (x86), Asahi Linux Fedora (aarch64). We want
to share as many parts as possible and as necessary between the two operating
systems. Different installation optiosn are define within the `Makefile` and
consider:
- `micro` setup with bash, tmux, and htop where there are almost no rights for the user
- `minimal` setup with nvim, zsh, python, node and more tools installed locally without sudo
- `linux` setup for desktop and server settings with the full suite for both sudo and non-sudo users
- `macos` setup with the full suite of applications, window management and applications for native Apple Silicon
- `asahi` setup with the full suite of applications, window management and applications for Linux ARM

---

We need to always differentiate between the different Linux settings with respect to architecture.
