# Exports
# ------------------------------------------------------------------------------

if [[ -f "$(command -v nvim)" ]]; then
  export EDITOR='nvim'
else
  export EDITOR='vi'
fi

export VISUAL=$EDITOR
export BROWSER=/Applications/Safari.app
export CLICOLOR=1
export BLOCKSIZE=1k
export MANPAGER='less -X'

export HISTSIZE=10000
export HISTFILESIZE=${HISTSIZE}
export HISTCONTROL=ignoreboth
export HISTIGNORE="&:[bf]g:clear:history:exit:q:pwd:wget *:ls:ll:la:cd"

# FZF
export FZF_DEFAULT_COMMAND="ag -g '' --path-to-ignore ${DOTFILES}/ignore"

export FZF_CTRL_T_COMMAND="$FZF_DEFAULT_COMMAND"

export FZF_DEFAULT_OPTS="--height=50% --reverse"

export FZF_CTRL_T_OPTS="--no-mouse --preview 'file {}' --preview-window down:1:hidden:wrap 
  --bind '?:toggle-preview'"

export FZF_CTRL_R_OPTS="--no-mouse --preview 'echo {}' --preview-window down:3:hidden:wrap
  --bind '?:toggle-preview'"

export FZF_ALT_C_OPTS="--no-mouse --exit-0 --preview 'tree -C {} | head -200'"

# HOMEBREW
export HOMEBREW_NO_INSECURE_REDIRECT=1
export HOMEBREW_NO_ANALYTICS=1
export HOMEBREW_CASK_OPTS=--require-sha

# GO
export GOPATH="$HOME/Documents/golang"
export GOROOT="$(brew --prefix golang)/libexec"

export GPG_TTY=$(tty)
