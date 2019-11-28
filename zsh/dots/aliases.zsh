alias cp='nice cp'
alias mv='nice mv'
alias grep='grep --color=auto'

alias src='exec "$SHELL" -l'
alias {dotfiles,dots}='cd ~/.dotfiles'
alias vim=$EDITOR
alias {activate,venv}='source ./venv/bin/activate'
alias speedtest="wget -O /dev/null http://speed.transip.nl/100mb.bin"
alias vimrc="$EDITOR ~/.dotfiles/vim/init.vim"
alias localrc="if [[ -a ~/.local.zsh ]]; then ${EDITOR} ~/.local.zsh; fi"
alias localgit="if [[ -a ~/.local.gitconfig ]]; then ${EDITOR} ~/.local.gitconfig; fi"

# CPU and MEM Monitoring
alias cpu="top -F -R -o cpu"
alias mem="top -F -o rsize"

# List top 5 processes by CPU usage
alias hogs="ps -acrx -o pid,%cpu,command | awk 'NR<=6'"
alias battery="pmset -g ps"

# Print each PATH entry on a separate line
alias path='echo -e ${PATH//:/\\n}'

# Print each function name
alias showfunctions="declare -f | grep '^[a-z].* ()' | sed 's/{$//'"
alias ag="ag --path-to-ignore ${DOTFILES}/ignore --color --color-line-number \
  '0;35' --color-match '46;30' --color-path '4;36'"
alias :q="exit"
alias ipd="curl -sS ipinfo.io  2>/dev/null | jq ."
alias -g @="| grep -i"
alias joke="curl https://icanhazdadjoke.com"

# Get week number
alias week='date +%V'

alias npmls='npm ls --depth=0'
alias npmlsg='npm ls --depth=0 -g'

alias dfh='df -h'
alias copypubkey='pbcopy < ~/.ssh/id_rsa.pub'
