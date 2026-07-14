#!/usr/bin/env bash
# Shared helpers for the dotfiles installer.
# Sourced by install.sh and install/components.sh. Not meant to run on its own.

# --- environment ------------------------------------------------------------
: "${DOTFILES:?DOTFILES must be set before sourcing common.sh}"
OSTYPE_UNAME="$(uname -s)"
ARCHITECTURE="$(uname -m)"

# NOSUDO=1 disables every sudo call and package manager step that needs root.
NOSUDO="${NOSUDO:-}"

# Make repo-provided binaries discoverable, mirroring the old Makefile PATH.
PATH="$PATH:/usr/local/bin:/usr/local/sbin:/usr/bin"
PATH="$PATH:$DOTFILES/bin/$OSTYPE_UNAME/$ARCHITECTURE:$DOTFILES/bin/$OSTYPE_UNAME"
PATH="$PATH:$HOME/bin:$HOME/.local/bin:$HOME/.local/nodejs/bin"
[ "$OSTYPE_UNAME" = "Linux" ] && PATH="$PATH:$DOTFILES/asahi/bin"
[ "$ARCHITECTURE" = "arm64" ] && PATH="$PATH:/opt/homebrew/bin:/opt/homebrew/sbin"
export PATH

# --- pretty printing --------------------------------------------------------
# Warnings/errors are counted so a run can print a summary at the end.
INSTALL_WARNINGS=0
print_step()    { printf '\033[1m\033[34m==> %s\033[0m\n' "$*"; }
print_ok()      { printf '\033[1m\033[32m  ok %s\033[0m\n' "$*"; }
print_warning() { INSTALL_WARNINGS=$((INSTALL_WARNINGS + 1)); printf '\033[1m\033[33mWarning: %s\033[0m\n' "$*"; }
print_error()   { INSTALL_WARNINGS=$((INSTALL_WARNINGS + 1)); printf '\033[1m\033[31mError: %s\033[0m\n' "$*" >&2; }

have() { command -v "$1" >/dev/null 2>&1; }

# --- guards -----------------------------------------------------------------
require_macos() { [ "$OSTYPE_UNAME" = "Darwin" ] || { print_error "This step requires macOS"; exit 1; }; }
require_linux() { [ "$OSTYPE_UNAME" != "Darwin" ] || { print_error "This step requires Linux"; exit 1; }; }

require_tools() {
  print_step "Validating required tools"
  local missing=0 t
  for t in curl git make; do
    have "$t" || { print_error "$t is required"; missing=1; }
  done
  [ "$missing" -eq 0 ] || exit 1
  print_ok "curl, git, make available"
}

# --- sudo keepalive ---------------------------------------------------------
# Prime sudo and refresh it in the background so long installs don't re-prompt.
# No-op when NOSUDO=1.
ensure_sudo() {
  [ -n "$NOSUDO" ] && { print_warning "NOSUDO set; skipping sudo authentication"; return 0; }
  print_step "Installation with sudo required"
  if sudo -n true 2>/dev/null; then
    print_warning "sudo session already active"
  else
    sudo -v
  fi
  ( while true; do sudo -n true; sleep 1200; kill -0 "$$" || exit; done 2>/dev/null & )
}

# --- symlink helpers (ported from the Makefile) -----------------------------
# link_if_exists SRC DST : link only when SRC exists, else warn and skip.
link_if_exists() {
  local src="$1" dst="$2"
  mkdir -p "$(dirname "$dst")"
  if [ -e "$src" ] || [ -L "$src" ]; then
    echo "Linking $dst -> $src"
    ln -sfn "$src" "$dst"
  else
    print_warning "Optional source $src does not exist; skipping symlink"
  fi
}

# replace_with_symlink SRC DST : replace any existing DST (file/dir/link) with a
# link to SRC. Used for config directories that must point into the repo.
replace_with_symlink() {
  local src="$1" dst="$2"
  mkdir -p "$(dirname "$dst")"
  if [ ! -e "$src" ] && [ ! -L "$src" ]; then
    print_warning "Optional source $src does not exist; skipping symlink"
  elif [ -L "$dst" ] && [ "$(readlink "$dst")" = "$src" ]; then
    echo "Link already correct: $dst -> $src"
  else
    if [ -e "$dst" ] || [ -L "$dst" ]; then
      echo "Removing existing $dst"
      rm -rf "$dst"
    fi
    echo "Linking $dst -> $src"
    ln -sfn "$src" "$dst"
  fi
}

# link_first_exists DST SRC... : link DST to the first SRC that exists.
link_first_exists() {
  local dst="$1"; shift
  mkdir -p "$(dirname "$dst")"
  local src
  for src in "$@"; do
    if [ -e "$src" ] || [ -L "$src" ]; then
      echo "Linking $dst -> $src"
      ln -sfn "$src" "$dst"
      return 0
    fi
  done
  print_warning "Optional sources not found for $dst: $*"
}

# --- service / binary checks ------------------------------------------------
# check_bin NAME [LABEL] : report presence of a binary, returns non-zero if absent.
check_bin() {
  local name="$1" label="${2:-$1}"
  if have "$name"; then print_ok "$label present"; return 0
  else print_warning "$label not installed"; return 1; fi
}

# report_check LABEL PREDICATE... : ok "LABEL loaded" when the predicate succeeds.
report_check() {
  local label="$1"; shift
  if "$@"; then print_ok "$label loaded"; else print_warning "$label not loaded"; fi
}

# check_link PATH : ok when PATH is a symlink resolving into $DOTFILES, else warn
# (distinguishing broken links, foreign files, and missing paths).
check_link() {
  local p="$1"
  if [ -L "$p" ] && [[ "$(readlink "$p")" == "$DOTFILES"/* ]]; then
    [ -e "$p" ] && print_ok "$p -> repo" || print_warning "$p is a broken repo symlink"
  elif [ -e "$p" ] || [ -L "$p" ]; then
    print_warning "$p exists but is not a repo symlink"
  else
    print_warning "$p missing"
  fi
}

# brew_service_running NAME : true when a `brew services` entry is started.
# Output is captured first so `grep -q`'s early exit can't SIGPIPE the producer
# into a pipefail failure.
brew_service_running() {
  have brew || return 1
  local out; out="$(brew services list 2>/dev/null)"
  printf '%s\n' "$out" | awk -v n="$1" '$1==n && $2=="started" {found=1} END {exit !found}'
}

# launchd_loaded LABEL : true when a launchd label is bootstrapped for the user.
launchd_loaded() {
  local out; out="$(launchctl list 2>/dev/null)"
  case "$out" in *"$1"*) return 0 ;; *) return 1 ;; esac
}
