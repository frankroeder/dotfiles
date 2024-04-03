! [ $commands[fzf] ] && return

if [ $commands[rg] ]; then
  export FZF_DEFAULT_COMMAND="command rg --files --hidden --color=never --follow --ignore-file ${DOTFILES}/ignore"
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
