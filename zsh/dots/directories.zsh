# ZSH-specific directory configuration and aliases
# Common directory aliases are in shared/directories.sh

unsetopt AUTO_CD
setopt AUTO_PUSHD
setopt PUSHD_IGNORE_DUPS
setopt PUSHDMINUS

# complete . and .. special directories
zstyle ':completion:*' special-dirs true
zstyle ':completion:*:default' list-colors ${(s.:.)LS_COLORS}
zstyle ':completion:*:*:cd:*' tag-order local-directories directory-stack path-directories
zstyle ':completion:*:*:cd:*:directory-stack' menu yes select
zstyle ':completion:*:-tilde-:*' group-order 'named-directories' 'path-directories' 'users' 'expand'
zstyle ':completion:*' squeeze-slashes true

# ZSH global aliases for directory navigation (can be used anywhere in command)
alias -g ...='../..'
alias -g ....='../../..'
alias -g .....='../../../..'

# Directory stack shortcuts (zsh-specific)
alias 1='cd -'
alias 2='cd -2'
alias 3='cd -3'
alias 4='cd -4'
alias 5='cd -5'
alias 6='cd -6'
alias 7='cd -7'
alias 8='cd -8'
alias 9='cd -9'

# Show directory stack
alias d='dirs -v | head -10'
