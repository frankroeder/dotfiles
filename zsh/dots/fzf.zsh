# Setup fzf
if [[ ! "$PATH" == */Users/$USER/.fzf/bin* ]]; then
  export PATH="${PATH:+${PATH}:}$HOME/.fzf/bin"
fi

# Auto-completion
[[ $- == *i* ]] && source "$HOME/.fzf/shell/completion.zsh" 2> /dev/null

# Key bindings
source "$HOME/.fzf/shell/key-bindings.zsh"

! [ $commands[fzf] ] && return

export FZF_TMUX=1

if [ $commands[ag] ]; then
  export FZF_DEFAULT_COMMAND="command ag -g '' --hidden --path-to-ignore ${DOTFILES}/ignore"
fi

export FZF_CTRL_T_COMMAND="$FZF_DEFAULT_COMMAND"

export FZF_DEFAULT_OPTS="
--no-mouse
--reverse
"

export FZF_CTRL_T_OPTS="
--preview 'file {}'
--preview-window down:1:hidden:wrap
--bind '?:toggle-preview'
--header 'Press ? for details'
"

export FZF_CTRL_R_OPTS="
--sort
--preview 'echo {}'
--preview-window down:3:hidden:wrap
--bind '?:toggle-preview'
--bind 'ctrl-y:execute-silent(echo -n {2..} | pbcopy)+abort'
--header 'Press ? for wrapped view or CTRL-Y to copy into clipboard'
"

export FZF_ALT_C_OPTS="
--exit-0
--preview 'tree -C {} 2> /dev/null'
"

bindkey '^Z' fzf-cd-widget
