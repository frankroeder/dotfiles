# dotfiles

![](https://flat.badgen.net/badge/platform/Linux,macOS,AsahiLinux?list=|)
![](https://flat.badgen.net/badge/icon/docker?icon=docker&label)
![](https://flat.badgen.net/badge/icon/container?icon=apple&label)
![](https://flat.badgen.net/badge/license/MIT/green)

My personal dotfiles for Linux, macOS, and Apple Silicon Linux (Aurora Fedora Remix).

## Installation

Clone the repository as `~/.dotfiles`, then run a **profile**. Install logic lives
in `install.sh`; the `Makefile` keeps thin wrappers plus test/benchmark/format.

| Setup | Command |
| --- | --- |
| macOS Intel/ARM | `make macos` |
| Linux with sudo | `make linux` |
| Linux without sudo | `make minimal` |
| Bash-only, no tooling | `make micro` |
| Apple Silicon Linux (Aurora Fedora Minimal + Hyprland) | `make aurora` |

Profiles are **idempotent**: simply rerun one (e.g. `./install.sh macos`) to
refresh configs and re-apply symlinks; tools already installed are skipped.
Test in a container with `make test` (or `NOSUDO=1 make test`).
The `linux` and `minimal` profiles exit non-zero when a required step fails.
`make doctor` is profile-aware (Hyprland checks only on Asahi).
`make smoke` syntax-checks installer scripts; container tests also run `install/check.sh`.

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

## Apple Silicon install (Aurora)
1. In macOS, download the Aurora installer app (an alpha prerelease as of 2026-11; Alpha 18 ships 9 profiles):
   [aurora-installer releases](https://github.com/aurora-silicon/aurora-installer/releases). Choose **Aurora Fedora
   Remix**, profile **minimal**, and keep disk encryption on (the default, see [Disk encryption](#disk-encryption)).
   Supported Macs: [aurorasilicon.org/devices](https://aurorasilicon.org/devices/).
2. First boot: the tty1 wizard creates your user; its password also unlocks the disk.
3. From the tty:
```sh
nmcli device wifi connect "SSID" --ask
sudo dnf install -y git make
git clone https://github.com/frankroeder/dotfiles.git ~/.dotfiles
cd ~/.dotfiles
make aurora          # sudo; at the end it calibrates Touch ID and enrols a finger
systemctl reboot     # tty1 login starts Hyprland
```

`make aurora` (= `make asahi`) is idempotent: rerun it after a failure, after `git pull`, or after a reboot that a
step asked for. It applies a minimal Hyprland desktop with Ghostty, Quickshell (bar, launcher, notifications), Hypridle
and Hyprlock. A converted Fedora Asahi Remix install needs one more run after its first boot on the Aurora kernel
(asahi/CLAUDE.md, "Aurora boot chain"). Coming back from a backup: [Backup & restore](#backup--restore).
Files with an iPhone: LocalSend (installed), receiving only on a network in
firewalld's home zone: `nmcli connection modify "<Wi-Fi name>" connection.zone home`.

### Disk encryption
The installer encrypts the root by default (its encryption toggle; first boot converts it to LUKS2 in the initrd,
Aurora's `omarchy-mac-encrypt`). On Minimal, the tty1 wizard's password protects both the account and the disk, and
the temporary key on `/boot` is removed once it is enrolled. No recovery key is made, and a later `passwd` does not
change the disk password (`sudo cryptsetup luksChangeKey <partition>` does). Add a recovery key and keep it off the Mac:
```sh
lsblk -o NAME,FSTYPE,UUID                        # the crypto_LUKS partition
sudo systemd-cryptenroll --recovery-key /dev/disk/by-uuid/<UUID>
```
Status per Aurora's [validation log](https://github.com/aurora-silicon/aurora-distributions/blob/main/docs/VALIDATION.md)
(2026-11): in-place LUKS2 encryption is validated on other Macs (only the owner's keyslot kept); minimal-image encryption
and physical installs on M2 Pro are still being checked, so confirm after the first boot that `lsblk -f` shows the root
partition as `crypto_LUKS`. `asahi/bin/asahi-debug` checks it on every run (root on LUKS, no temporary key
or LUKS header copy left on the unencrypted `/boot`). Converted Fedora Asahi installs are not encrypted:
[AsahiLocker](https://github.com/doug445/AsahiLocker) from a live USB. Touch ID cannot unlock the root volume yet.

**Touch ID and macOS**: Linux and macOS share the Secure Enclave's anti-replay state. If it is ever written wrongly,
macOS with FileVault on cannot unlock and needs a DFU restore, which erases the Mac (omarchy-mac
[manual](https://github.com/omacom/omarchy-mac-pkgs/blob/main/mac-manual/content/04-security.md)). Aurora's xART
guard (on by default on M2: `xart_guard=1`) refuses to rewrite macOS's records; the Hardware pane shows its refusals.
Keep a macOS backup (Time Machine) while Touch ID is on in Linux; `options apple_sep xart_writes=0
provision_keybag=0` opts out (no Touch ID on Linux).

## Backup & restore
`asahi-timemachine` (restic) keeps `~` encrypted on a USB drive or an SFTP host, every ≥ 72 h and from the Quick pane
**Backup** (Super+Ctrl+R: back up, browse, restore). snapper keeps hourly and daily snapshots of `/` and `/home` (weekly
too for `/`) on the same disk.

- **Keep off the Mac** (password manager): `~/.config/asahi-timemachine/{password,config,id_ed25519}`. The backup holds
  them too, but you need them to open it.
- **Not backed up**: everything outside `~` (`/etc`, `/var`, `/boot`, the ESP), caches, Flatpak apps (their data in
  `~/.var/app` is), `~/Nextcloud`, the Trash, `node_modules` / `.venv` / `build`, `.nobackup` dirs. `make aurora`
  brings back packages, Flatpaks, configs and wallpapers; Wi-Fi, Bluetooth, Touch ID and logins are by hand.

### Reinstall
Install as above with the **same user name, login password (keyrings) and hostname** (restic groups snapshots by
host), then, before `make aurora`:
```sh
sudo hostnamectl hostname <old-hostname>
sudo dnf install -y restic git
mkdir -pm 700 ~/.config/asahi-timemachine   # copy password, config, id_ed25519 here (chmod 600)
c=~/.config/asahi-timemachine; . $c/config; export RESTIC_PASSWORD_FILE=$c/password
export RESTIC_REPOSITORY="sftp:$TM_SFTP:$TM_SFTP_PATH"
sftp -P "${TM_PORT:-22}" -i $c/id_ed25519 "$TM_SFTP"   # accept the host key, then: bye
o=(-o sftp.command="ssh -F /dev/null -i $c/id_ed25519 -o IdentitiesOnly=yes -p ${TM_PORT:-22} $TM_SFTP -s sftp")
# USB drive instead: udisksctl mount -b /dev/disk/by-label/$TM_LABEL
#   export RESTIC_REPOSITORY="/run/media/$USER/$TM_LABEL/$TM_DIR"; o=()
restic "${o[@]}" snapshots --tag asahi                             # pick <id>
restic "${o[@]}" restore <id>:/home/$USER --target ~ --dry-run -v  # then without --dry-run
sudo restorecon -R ~
cd ~/.dotfiles && make aurora && systemctl reboot   # the restored tree, uncommitted work included
asahi-timemachine status | jq .timer                # "active"; else asahi-timemachine init
```
snapper configs are not in the backup: `sudo snapper -c root create-config / && sudo snapper -c home create-config
/home && ./install.sh asahi-snapper`. Touch ID after a reinstall: the SEP's Linux records look like another OS's
to the xART guard (`/usr/share/doc/aurora-sep/XART-SAFETY.md`): `sudo aurora-xart reset-touchid` (it
refuses while the keybag works), reboot, then `./install.sh asahi-touchid`.

### Malfunction
- Lost or broken file in `~`: Quick pane **Backup** → Restore (to `~/Restored/…`), or the hourly copy in
  `/home/.snapshots/<N>/snapshot/$USER/` (`snapper -c home list`, no sudo).
- Bad update: pick the older kernel in the GRUB menu. To roll `/` back (it mounts `subvol=root`, so
  `snapper rollback` does nothing; `/boot` and the ESP are not in snapshots; Touch ID failing afterwards = the rollback
  brought back an older xART owner list: `sudo aurora-xart reset-touchid`):
```sh
sudo snapper -c root list                          # <N> from before the breakage
sudo mount -o subvolid=5 "$(findmnt -no SOURCE / | cut -d'[' -f1)" /mnt   # e.g. /dev/mapper/fedora_crypt
sudo mv /mnt/root /mnt/root.broken
sudo btrfs subvolume snapshot /mnt/root.broken/.snapshots/<N>/snapshot /mnt/root
sudo rmdir /mnt/root/.snapshots && sudo mv /mnt/root.broken/.snapshots /mnt/root/
sudo umount /mnt && systemctl reboot               # pick a kernel whose modules are in <N>
# later: mount again, sudo btrfs subvolume delete -R /mnt/root.broken
```
- No GRUB after a Stage 2 (m1n1) update: boot macOS (hold power → Options), then put the previous Stage 2 back:
```sh
diskutil list                                      # ESP "EFI - FEDOR" (FAT, 500 MB), e.g. disk0s4
diskutil mount disk0s4
cd "/Volumes/EFI - FEDOR/m1n1" && cp boot.bin boot.bin.bad && cp boot.bin.old boot.bin
```

Credits: the Asahi setup draws from [Omarchy](https://github.com/omacom/omarchy) and
[Omarchy Mac](https://github.com/omacom/omarchy-mac); the Quickshell launcher and Displays pane take design cues from
[Ryoku](https://github.com/Ryoku-dev/ryoku).

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
- https://github.com/basecamp/omarchy
- https://github.com/omarchy-mac/omarchy-mac (Asahi)
- https://github.com/maralcbr/omarchy-mx-mac (Asahi)
- https://github.com/Ryoku-dev/ryoku (Asahi, Quickshell design inspiration)
