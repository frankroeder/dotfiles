[[ $OSTYPE != 'Linux' ]] && return

path=(
  "$HOME/.local/bin"
  "$HOME/.local/nodejs/bin"
  $path
)

# Desktop-only features for Linux (GUI tools, clipboard, etc.)
# Server utilities are in shared/linux.sh

# Open current directory in file manager (GUI)
alias f='xdg-open ./'

if [ $commands[xclip] ]; then
	alias pbcopy='xclip -selection clipboard'
	alias pbpaste='xclip -selection clipboard -o'
	alias copypubkey='xclip -selection clipboard < ~/.ssh/id_rsa.pub'
fi
[ $commands[xdg-open] ] && function open() { xdg-open $@; };
