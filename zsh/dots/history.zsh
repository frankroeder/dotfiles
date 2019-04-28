[ -z "$HISTFILE" ] && HISTFILE="$HOME/.zsh_history"
HISTSIZE=6000
SAVEHIST=$HISTSIZE
HISTCONTROL=ignoreboth
HISTIGNORE="&:[bf]g:clear:history:exit:q:pwd:wget *:ls:ll:la:cd"

setopt hist_ignore_all_dups
setopt extended_history       # record timestamp of command in HISTFILE
setopt hist_ignore_space      # ignore commands that start with space
setopt hist_verify            # show command with history expansion to user before running it
setopt inc_append_history     # add commands to HISTFILE in order of execution
setopt share_history          # share command history across shells
setopt hist_reduce_blanks

zstyle ':completion:*:history-words' stop yes
zstyle ':completion:*:history-words' remove-all-dups yes
zstyle ':completion:*:history-words' list false
zstyle ':completion:*:history-words' menu yes
