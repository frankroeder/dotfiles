# source fuzzy file search - fzf
[ -f ~/.fzf.zsh ] && source ~/.fzf.zsh

[ $+commands[fzf] -eq 0 ] && return

export FZF_TMUX=1

export FZF_DEFAULT_COMMAND="command ag -g '' --path-to-ignore ${DOTFILES}/ignore"

export FZF_CTRL_T_COMMAND="$FZF_DEFAULT_COMMAND"

export FZF_DEFAULT_OPTS="--reverse"

export FZF_CTRL_T_OPTS="--no-mouse --preview 'file {}' --preview-window down:1:hidden:wrap --bind '?:toggle-preview' --header 'Press ? for details'"

export FZF_CTRL_R_OPTS="--no-mouse --sort --preview 'echo {}' --preview-window down:3:hidden:wrap --bind '?:toggle-preview' --header 'Press ? for wrapped view'"

export FZF_ALT_C_OPTS="--no-mouse --exit-0 --preview 'tree -C {} | head -200'"
