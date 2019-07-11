# Edit the current command line in $EDITOR
autoload -U edit-command-line
zle -N edit-command-line
bindkey '\C-x\C-e' edit-command-line

# vim mode keybindings
# https://dougblack.io/words/zsh-vi-mode.html
# press <ESC> to switch to NORMAL mode
bindkey -v
export KEYTIMEOUT=2

# Vim-like behavior
bindkey -M vicmd "^R" redo
bindkey -M vicmd "^A" increment-number
bindkey -M vicmd "ca" change-around
bindkey -M vicmd "ci" change-in
bindkey -M vicmd "cc" vi-change-whole-line
bindkey -M vicmd "di" delete-in
bindkey -M vicmd "da" delete-around

bindkey '^?' backward-delete-char       # backspace
bindkey '^h' backward-delete-char       # ctrl-h
bindkey '^w' backward-kill-word         # ctrl-w
bindkey "^K" kill-whole-line            # ctrl-k
bindkey "^A" beginning-of-line          # ctrl-a
bindkey "^E" end-of-line                # ctrl-e
bindkey "^D" delete-char                # ctrl-d
bindkey "^F" forward-char               # ctrl-f
bindkey "^B" backward-char              # ctrl-b
bindkey "[B" history-search-forward     # down arrow
bindkey "[A" history-search-backward    # up arrow

bindkey '^[[Z' reverse-menu-complete

bindkey ' ' magic-space                 # [Space] - do history expansion
bindkey '^[[1;5C' forward-word          # [Ctrl-RightArrow] - move forward one word
bindkey '^[[1;5D' backward-word         # [Ctrl-LeftArrow] - move backward one word

bindkey '^ ' autosuggest-accept         # accept the current zsh-autosuggestion
