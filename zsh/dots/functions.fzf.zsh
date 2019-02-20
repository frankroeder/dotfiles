# Fuzzy Functions
# ------------------------------------------------------------------------------
 
# v - fuzzy vim
v(){
  local files
  IFS=$'\n' files=($(fzf-tmux --query="$1" --multi --select-1 --exit-0))
  [[ -n "$files" ]] && ${EDITOR:-vim} "${files[@]}"
}

# vz - fuzzy vim with preview
vz() {
  local file
  file="$(ag -g "$1" --ignore={'*node_modules*','*venv*'} | fzf -1 -0 --sort \
    --preview 'head -100 {}' +m)" && $EDITOR "${file}" || return 1
}

# fo - fuzzy open file
fo() {
  open "$(fzf -1 -0 --sort +m)" || return 1
}

# fkill - fuzzy kill process
fkill() {
  local pid
  pid=$(ps -ef | sed 1d | fzf -m | awk '{print $2}')
  if [ "x$pid" != "x" ]
  then
    echo $pid | xargs kill -${1:-9}
  fi
}

# flog - fuzzy commit logs
flog() {
  git log --graph --color=always \
      --format="%C(auto)%h%d %s %C(black)%C(yellow)%cr" "$@" |
  fzf --ansi --no-sort --reverse --tiebreak=index --bind=ctrl-s:toggle-sort \
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
