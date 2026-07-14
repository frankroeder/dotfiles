#!/usr/bin/env bash
# dotfiles installer
#
# Replaces the monolithic Makefile install targets with a single, checkable
# entry point. Runs full-machine profiles or individual components. Profiles
# are idempotent: rerunning one refreshes configs and symlinks and skips
# binaries/tools that are already installed.
#
# Usage:
#   ./install.sh <profile|component> [options]
#
# Profiles (full machine setup):
#   macos     macOS Intel/ARM: brew, apps, shell, dev tooling
#   linux     Linux with sudo: system packages, shell, dev tooling
#   minimal   Linux without sudo (implies --no-sudo)
#   micro     Bash-only, no external tooling (backs up existing dotfiles first)
#   asahi     Asahi Linux (Fedora Minimal + Hyprland)
#
# Components (run one piece in isolation):
#   directories git zsh python misc node nvim agents terminal default-shell
#   homebrew macos-apps sketchybar        (macOS)
#   linux-base                            (Linux)
#   asahi-system asahi-zotero asahi-desktop asahi-battery-alerts  (Asahi)
#   after services                        (post-install / desktop services)
#
# Meta commands:
#   doctor    Report which binaries/services are present (no changes)
#   help      Show this message
#
# Options:
#   --no-sudo     Never call sudo; skip steps that need root
#   --check       Alias for the `doctor` command
#   -h, --help    Show this message

set -uo pipefail

DOTFILES="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export DOTFILES

# shellcheck source=install/common.sh
. "$DOTFILES/install/common.sh"
# shellcheck source=install/components.sh
. "$DOTFILES/install/components.sh"

usage() { awk 'NR==1{next} /^#/{sub(/^# ?/,""); print; next} {exit}' "$0"; }

# --- profiles ---------------------------------------------------------------

profile_macos() {
  require_macos; require_tools; ensure_sudo
  comp_directories
  comp_homebrew
  comp_macos_apps
  comp_zsh
  comp_python
  comp_misc
  comp_nvim
  comp_git
  comp_node
  print_step "Finalizing macOS setup"
  comp_default_shell
  zsh -i -c "fast-theme free" 2>/dev/null || print_warning "Failed to set fast-theme"
  compaudit 2>/dev/null | xargs chmod g-w 2>/dev/null || true
}

# Shared component list for the sudo and no-sudo Linux profiles.
_linux_components() {
  comp_directories
  comp_linux_base
  comp_git
  comp_zsh
  comp_python
  comp_misc
  comp_node
  comp_nvim
}

profile_linux() {
  require_linux; require_tools; ensure_sudo
  _linux_components
  print_step "Finalizing Linux setup"
  comp_default_shell
}

profile_minimal() {
  NOSUDO=1
  require_linux; require_tools
  _linux_components
}

profile_micro() {
  comp_backup
  comp_bash
  comp_micro
}

profile_asahi() {
  require_linux; require_tools; ensure_sudo
  comp_asahi_system
  comp_asahi_zotero
  comp_asahi_desktop
  comp_asahi_battery_alerts
  comp_default_shell
  comp_doctor
  comp_agents
  comp_asahi_wallpapers
}

# --- dispatch ---------------------------------------------------------------

[ $# -eq 0 ] && { usage; exit 0; }

TARGET=""
for arg in "$@"; do
  case "$arg" in
    --no-sudo) NOSUDO=1 ;;
    --check) TARGET="doctor" ;;
    -h|--help|help) usage; exit 0 ;;
    -*) print_error "Unknown option: $arg"; usage; exit 1 ;;
    *) [ -z "$TARGET" ] && TARGET="$arg" || { print_error "Unexpected argument: $arg"; exit 1; } ;;
  esac
done
export NOSUDO

[ -z "$TARGET" ] && { usage; exit 0; }

case "$TARGET" in
  macos)                profile_macos ;;
  linux)                profile_linux ;;
  minimal)              profile_minimal ;;
  micro)                profile_micro ;;
  asahi)                profile_asahi ;;

  directories)          comp_directories ;;
  git)                  comp_git ;;
  zsh)                  comp_zsh ;;
  python)               comp_python ;;
  misc)                 comp_misc ;;
  node)                 comp_node ;;
  nvim)                 comp_nvim ;;
  agents)               comp_agents ;;
  terminal)             comp_terminal ;;
  default-shell)        comp_default_shell ;;

  homebrew)             comp_homebrew ;;
  macos-apps)           comp_macos_apps ;;
  sketchybar)           comp_sketchybar_top; comp_sketchybar_island ;;

  linux-base)           comp_linux_base ;;

  asahi-system)         comp_asahi_system ;;
  asahi-zotero)         comp_asahi_zotero ;;
  asahi-desktop)        comp_asahi_desktop ;;
  asahi-battery-alerts) comp_asahi_battery_alerts ;;

  after)                comp_after ;;
  services)             comp_services ;;
  doctor)               comp_doctor ;;

  *) print_error "Unknown target: $TARGET"; usage; exit 1 ;;
esac

# Surface a tally so warnings don't get lost in a long install log (doctor's
# warnings are the report itself, so skip the summary there).
if [ "$TARGET" != "doctor" ] && [ "$INSTALL_WARNINGS" -gt 0 ]; then
  printf '\033[1m\033[33m==> Finished with %s warning(s); review the log above\033[0m\n' "$INSTALL_WARNINGS"
fi
