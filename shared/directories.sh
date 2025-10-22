#!/usr/bin/env sh
# Directory navigation and listing aliases shared between bash and zsh

# ls with colors (OS-specific flags)
if [ "$(uname -s)" = "Linux" ]; then
  alias ls='ls --color=auto'
else
  alias ls='ls -G'
fi

# ls variations
alias l='ls -lah'
alias la='ls -a'
alias l.='ls -d .*'
alias lsd='ls -d */'

# Navigation
alias ..='cd ..'
alias ...='cd ../..'
alias ....='cd ../../..'
alias .....='cd ../../../..'
alias ......='cd ../../../../..'
alias -- -='cd -'

# Directory operations
alias md='mkdir -p'
alias rd='rmdir'

# Disk usage
alias dud='du -d 1 -h | sort -hr'
alias dul='du -hsx * | sort -rh | head -15'
alias duf='du -sh'
