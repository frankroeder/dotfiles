[[ $OSTYPE != 'Linux' ]] && return

path=(
  "$HOME/.local/bin"
  "$HOME/.local/nodejs/bin"
  $path
)

# Asahi helper scripts only belong on Asahi hosts.
if [[ -n ${ASAHI:-} ]] \
  || { [[ -r /etc/os-release ]] && grep -qi asahi /etc/os-release; } \
  || [[ $(uname -r) == *[Aa]sahi* ]]; then
  path=("$DOTFILES/asahi/bin" $path)
fi

# Desktop-only features for Linux (GUI tools, clipboard, etc.)
# Server utilities are in shared/linux.sh

# Open current directory in file manager (GUI)
alias f='xdg-open ./'

if (( ${+commands[wl-copy]} )) && (( ${+commands[wl-paste]} )); then
  pbcopy() { command wl-copy "$@"; }
  pbpaste() { command wl-paste --no-newline "$@"; }
  copypubkey() { pbcopy < ~/.ssh/id_rsa.pub; }
fi
