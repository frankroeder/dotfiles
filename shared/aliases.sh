#!/usr/bin/env sh
# Common aliases shared between bash and zsh

# Navigation
alias ..='cd ..'
alias ...='cd ../..'
alias ....='cd ../../..'
alias .....='cd ../../../..'
alias ......='cd ../../../../..'

# File operations
alias cp='nice cp'
alias mv='nice mv'
alias grep='grep --color=auto'

# Directory shortcuts
[ -d "$HOME/Documents" ] && alias repos='cd $HOME/Documents'
[ -d "$HOME/Downloads" ] && alias dl='cd $HOME/Downloads'
alias dotfiles='cd $HOME/.dotfiles'
alias dots='cd $HOME/.dotfiles'
alias tmp='cd $HOME/tmp'

# Editor
alias vi='vim'
alias vim="${EDITOR:-vim}"

# Utilities
alias speedtest="wget -O /dev/null http://speed.transip.nl/100mb.bin"
alias hogs="ps wwaxr -o pid,stat,%cpu,time,command | awk 'NR<=10'"
alias mails="${EDITOR:-vim} /var/mail/$USER"
alias :q="exit"

# Date and time
alias week='date +%V'
alias iso8601='date -u +"%Y-%m-%dT%H:%M:%SZ"'
alias iso8601-local='date +"%Y-%m-%dT%H:%M:%S%z"'
alias iso8601-date='date +"%Y-%m-%d"'
alias unixtime='date +%s'

# Disk usage
alias dfh='df -h'
alias duh='du -h'

# System info
alias userlist="cut -d: -f1 /etc/passwd | sort"

# Print each function name
alias showfunctions="declare -f | grep '^[a-z].* ()' | sed 's/{\$//'"

# Online check
alias online="ping -c 1 www.example.com &> /dev/null && echo 'Online :)' || echo 'Offline :('"

# Fun
alias joke="curl https://icanhazdadjoke.com"
