HISTFILE=~/.zsh_history
HISTSIZE=6000
SAVEHIST=$HISTSIZE
HISTCONTROL=ignoreboth
HISTIGNORE="&:[bf]g:clear:history:exit:q:pwd:wget *:ls:ll:la:cd"

setopt hist_ignore_all_dups
setopt hist_reduce_blanks
setopt hist_ignore_dups
setopt hist_ignore_space

zstyle ':completion:*:history-words' remove-all-dups yes
