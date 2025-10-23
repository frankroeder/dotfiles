#!/usr/bin/env sh
# Common environment variables shared between bash and zsh

# Editor - prefer nvim, fallback to vim, then vi
if command -v nvim >/dev/null 2>&1; then
  export EDITOR="nvim"
elif command -v vim >/dev/null 2>&1; then
  export EDITOR="vim"
else
  export EDITOR="vi"
fi
export VISUAL="${EDITOR}"

# Locale settings
export LANG="en_US.UTF-8"
export LC_ALL="$LANG"

# Less settings
export LESS='-XFRx2'
export PAGER='less'
export MANPAGER='less'

# History settings (bash will override some of these)
export HISTSIZE=10000
export SAVEHIST=10000

# FZF default options (if fzf is available)
if command -v fzf >/dev/null 2>&1; then
  export FZF_DEFAULT_OPTS="--reverse --inline-info --cycle"
fi
