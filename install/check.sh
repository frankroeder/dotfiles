#!/usr/bin/env bash
# Strict post-install assertion used by make test.
set -euo pipefail

DOTFILES="${DOTFILES:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"

failed=0
for path in \
  "$HOME/.zshrc" \
  "$HOME/.zshenv" \
  "$HOME/.gitconfig" \
  "$HOME/.tmux.conf" \
  "$HOME/.config/nvim"
do
  if [ ! -L "$path" ]; then
    printf 'FAIL %s is not a symlink\n' "$path"
    failed=1
    continue
  fi
  target="$(readlink "$path")"
  case "$target" in
    "$DOTFILES"/*)
      printf 'ok   %s -> %s\n' "$path" "$target"
      ;;
    *)
      printf 'FAIL %s readlink does not start with %s/ (got %s)\n' "$path" "$DOTFILES" "$target"
      failed=1
      ;;
  esac
done

if [ "$failed" -ne 0 ]; then
  exit 1
fi
