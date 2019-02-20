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
export TERM=screen-256color

# neovim
export XDG_CONFIG_HOME="$HOME/.config"

export HISTSIZE=100000
export HISTFILESIZE=${HISTSIZE}
export HISTCONTROL=ignoreboth
export HISTIGNORE="&:[bf]g:clear:history:exit:q:pwd:wget *:ls:ll:la:cd"

# FZF
export FZF_DEFAULT_COMMAND="ag -g '' --path-to-ignore ${DOTFILES}/ignore"
export FZF_CTRL_T_COMMAND="$FZF_DEFAULT_COMMAND"
export FZF_DEFAULT_OPTS="--reverse --inline-info --cycle"

# HOMEBREW
export HOMEBREW_NO_INSECURE_REDIRECT=1
export HOMEBREW_NO_ANALYTICS=1
export HOMEBREW_CASK_OPTS=--require-sha

# GO
export GOPATH="$HOME/Documents/golang"
export GOROOT="$(brew --prefix golang)/libexec"

export GPG_TTY=$(tty)
