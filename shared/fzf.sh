#!/usr/bin/env sh
# FZF-based functions shared between bash and zsh
# Requires fzf to be installed

! command -v fzf >/dev/null 2>&1 && return

# Get env value with fzf
fenv() {
  local out
  out=$(env | fzf)
  echo "$out" | cut -d= -f2
}

# Remove file with fzf
frm() {
  local file
  file=$(fzf --cycle +m) && rm -rfi "$file"
}

# Fuzzy file search and edit with vim
v() {
  local files
  files=$(fzf --query="$1" -m --no-mouse --select-1 --exit-0 \
    --preview 'head -100 {}' --preview-window \
    right:hidden --bind '?:toggle-preview')
  [ -n "$files" ] && ${EDITOR:-vi} $files
}

# Fuzzy git log (requires git and fzf)
glz() {
  if ! command -v git >/dev/null 2>&1; then
    echo "git is not installed"
    return 1
  fi
  if ! git rev-parse --git-dir > /dev/null 2>&1; then
    echo "Not inside git repo"
    return 1
  fi
  git log --graph --color=always \
      --format="%C(auto)%h%d %s %C(black)%C(bold)%cr" "$@" |
      fzf --ansi --reverse \
      --preview "echo {} | grep -o '[a-f0-9]\{7\}' | head -1 |
      xargs -I % sh -c 'git show --color=always % | head -200 '" |
      grep -o '[a-f0-9]\{7\}'
}

# List aliases with optional search or fzf
showalias() {
  local ALIASES
  ALIASES=$(alias | sed "s/^\([^=]*\)=\(.*\)/\1 => \2/" | sed "s/['|\']//g" | sort)
  if [ -n "$1" ]; then
    echo "$ALIASES" | grep "$1"
  else
    echo "$ALIASES" | fzf
  fi
}
