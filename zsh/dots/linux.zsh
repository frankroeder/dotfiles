[[ $OSTYPE != 'Linux' ]] && return

path=(
  "$DOTFILES/asahi/bin"
  "$HOME/.local/bin"
  "$HOME/.local/nodejs/bin"
  $path
)

# Desktop-only features for Linux (GUI tools, clipboard, etc.)
# Server utilities are in shared/linux.sh

# Open current directory in file manager (GUI)
alias f='xdg-open ./'

if [ $commands[wl-copy] ] && [ $commands[wl-paste] ]; then
  pbcopy() { command wl-copy "$@"; }
  pbpaste() { command wl-paste --no-newline "$@"; }
  copypubkey() { pbcopy < ~/.ssh/id_rsa.pub; }
fi
