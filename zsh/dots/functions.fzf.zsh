# Fuzzy Functions
# ------------------------------------------------------------------------------

# v - fuzzy vim with preview
v(){
  local files
  IFS=$'\n' files=($(fzf-tmux --query="$1" -m --no-mouse --select-1 --exit-0 \
    --preview 'head -100 {}' --preview-window \
      right:hidden --bind '?:toggle-preview'))
  [[ -n "$files" ]] && ${EDITOR:-vim} "${files[@]}"
}

# fo - fuzzy open file
fo() {
  file="$(fzf -1 -0 --sort +m)"
  [[ -n "$file" ]] && open $file
}

# fkill - fuzzy kill process
fkill() {
  local pid
  pid=$(ps -ef | sed 1d | fzf -m --no-mouse | awk '{print $2}')
  if [ "x$pid" != "x" ]
  then
    echo $pid | xargs kill -${1:-9}
  fi
}

# flog - fuzzy commit logs
flog() {
  git log --graph --color=always \
      --format="%C(auto)%h%d %s %C(black)%C(yellow)%cr" "$@" |
  fzf --ansi +s --reverse --tiebreak=index --bind=ctrl-s:toggle-sort \
      --bind "ctrl-m:execute:
                (grep -o '[a-f0-9]\{7\}' | head -1 |
                xargs -I % sh -c 'git show --color=always % | less -R') << 'FZF-EOF'
                {}
  FZF-EOF"
}

# flog - fuzzy commit logs with preview
flogz() {
  git log --pretty=oneline --abbrev-commit |
    fzf --preview 'echo {} | cut -f 1 -d " " | xargs git show --color=always'
}
