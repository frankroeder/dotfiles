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
  # fzf with -m returns multiple files separated by newlines
  files=$(fzf --query="$1" -m --no-mouse --select-1 --exit-0 \
    --preview 'head -100 {}' --preview-window \
    right:hidden --bind '?:toggle-preview')
  # Open all selected files in a single editor instance
  [ -n "$files" ] && ${EDITOR:-vi} $(echo "$files")
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
      fzf --ansi -d 95% --reverse \
      --preview "echo {} | grep -o '[a-f0-9]\\{7\\}' | head -1 |
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
# fkill - kill processes - list only the ones you can kill. Modified the earlier script.
fkill() {
    local pid
    local signal="${1:-9}" # Default to signal 9 (KILL) if not provided
    local list_cmd

    # 1. OS & User Detection for Process Listing
    if [ "$UID" != "0" ]; then
        # Standard User: List only user processes
        # compatible with both macOS and Linux
        list_cmd="ps -f -u $(id -u)"
    else
        # Root: List all processes
        list_cmd="ps -ef"
    fi

    # 2. Run FZF
    # --header-lines=1: Treats the first line (headers) as sticky
    # --preview: Shows full details using ps with wide output (-ww) to see full args
    pid=$(eval "$list_cmd" | fzf \
        --multi \
        --reverse \
        --header-lines=1 \
        --preview 'ps -p {2} -ww -f' \
        --preview-window='right:50%:wrap' \
        | awk '{print $2}')

    # 3. Kill Logic
    if [ -n "$pid" ]; then
        # Confirmation message with count
        local count=$(echo "$pid" | wc -w | xargs)
        echo "Killing $count process(es) with signal -$signal..."

        echo "$pid" | xargs kill "-$signal"

        # Check if kill was successful
        if [ $? -eq 0 ]; then
             echo "✅ Process(es) killed."
        else
             echo "❌ Failed to kill process(es)."
        fi
    fi
}
# Fuzzy search shell history and execute
fhist() {
  eval $(history | fzf --tac | sed 's/^ *[0-9]* *//')
}
