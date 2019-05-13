export FZF_DEFAULT_COMMAND="command ag -g '' --path-to-ignore ${DOTFILES}/ignore"

export FZF_CTRL_T_COMMAND="$FZF_DEFAULT_COMMAND"

export FZF_DEFAULT_OPTS="--height=50% --reverse"

export FZF_CTRL_T_OPTS="--no-mouse --preview 'file {}' --preview-window down:1:hidden:wrap --bind '?:toggle-preview'"

export FZF_CTRL_R_OPTS="--no-mouse --preview 'echo {}' --preview-window down:3:hidden:wrap --bind '?:toggle-preview'"

export FZF_ALT_C_OPTS="--no-mouse --exit-0 --preview 'tree -C {} | head -200'"
