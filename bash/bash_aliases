#!/usr/bin/env bash

alias ..='cd ..'
alias ...='cd ../..'
alias ....='cd ../../..'
alias .....='cd ../../../..'
alias ......='cd ../../../../..'

alias vi='vim'
alias cp='nice cp'
alias mv='nice mv'
alias src="source ~/.bash_profile"

# Lists the top 4 processes by CPU usage
alias hogs="ps -acrx -o pid,%cpu,command | awk 'NR<=5'"

alias speedtest="wget -O /dev/null http://speed.transip.nl/100mb.bin"

# Print each PATH entry on a separate line
alias path='echo -e ${PATH//:/\\n}'

# Print each function name
alias showfunctions="declare -f | grep '^[a-z].* ()' | sed 's/{$//'"

alias {dots,dotfiles}='cd ~/.dotfiles'
# enable color support of ls and also add handy aliases
if [ -x /usr/bin/dircolors ]; then
  test -r ~/.dircolors && eval "$(dircolors -b ~/.dircolors)" || eval "$(dircolors -b)"
  alias ls='ls --color=auto'
  alias l='ls -lah'
  alias ll='ls -la'
  alias la='ls -a'
  alias l.='ls -d .*'
  alias lsd='ls -l | grep "^d"'

  alias grep='grep --color=auto'
  alias fgrep='fgrep --color=auto'
  alias egrep='egrep --color=auto'
fi

alias venv='source ./venv/bin/activate'
## Vim related shortcuts
alias vimrc="vim ~/.vimrc"
alias vi='vim'
alias vimup="vim +PlugUpdate +qall && vim +PlugUpgrade +qall"
alias :q="exit"
alias ipd="curl -sS ipinfo.io  2>/dev/null | jq ."
alias localrc="vim ~/.bash_local"

alias varwww='cd /var/www/html/'
alias mails="vim /var/mail/$USER"
alias distro='cat /etc/issue'

alias v0="vim -c \"normal '0\""
alias wgpu='watch -n 0.1 -d nvidia-smi'
alias whou='who -u | sort -k 3 --reverse'

alias ta='tmux attach -t'
alias tad='tmux attach -d -t'
alias ts='tmux new-session -s'
alias tl='tmux list-sessions'
alias tksv='tmux kill-server'
alias tkss='tmux kill-session -t'

alias dps='docker ps'
alias dimg='docker images'
alias drmall='docker rm $(docker ps -a -q)'
alias dkillall='docker kill $(docker ps -a -q)'
alias drmiall='docker rmi $(docker images -a -q)'
alias dsdf='docker system df'
alias dsev='docker system events'

## git alias
alias g='git'
alias gl='git pull'
alias gp='git push'
alias gco='git checkout'
alias gm='git merge'
alias gd='git diff'
alias gdw='git diff --word-diff'
alias glg='git log --stat --color'
alias gb="git branch"
alias gc='git commit'
alias gcmsg="git commit -m"
alias gc!='git commit -v --amend'
alias gcaa="git commit -a --amend -C HEAD"
alias gaa="git add -A ."
alias gst='git status'
alias gt="git tag"
alias grt='cd "$(git rev-parse --show-toplevel)"'
alias gg='git grep'
alias gwch='git whatchanged -p --abbrev-commit --pretty=medium'

