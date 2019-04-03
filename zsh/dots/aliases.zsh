alias ll='ls -la'
alias la='ls -a'
alias l.='ls -d .*'
alias lsd='ls -l | grep "^d"'
alias cp='nice cp'
alias mv='nice mv'
alias dud='du -d 1 -h'
alias duf='du -sh *'

alias src='exec "$SHELL" -l'
alias dotfiles='cd ~/.dotfiles'
alias vim=$EDITOR
alias venv='source ./venv/bin/activate'
alias speedtest="wget -O /dev/null http://speed.transip.nl/100mb.bin"
alias vimrc="$EDITOR ~/.dotfiles/vim/init.vim"

# CPU and MEM Monitoring
alias cpu="top -F -R -o cpu"
alias mem="top -F -o rsize"
# List top 5 processes by CPU usage
alias hogs="ps -acrx -o pid,%cpu,command | awk 'NR<=6'"
alias battery="pmset -g ps"
# Print each PATH entry on a separate line
alias path='echo -e ${PATH//:/\\n}'
# Print each function name
alias functions="declare -f | grep '^[a-z].* ()' | sed 's/{$//'"
alias ag="ag --path-to-ignore ${DOTFILES}/ignore"
alias :q="exit"
alias localip="ipconfig getifaddr en0"
