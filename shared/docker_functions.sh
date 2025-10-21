#!/usr/bin/env sh
# Docker aliases and functions shared between bash and zsh

! command -v docker >/dev/null 2>&1 && return

# Basic docker aliases
alias dps='docker ps'
alias dimg='docker images'
alias drmall='docker rm $(docker ps -a -q)'
alias dkillall='docker kill $(docker ps -a -q)'
alias drmiall='docker rmi $(docker images -a -q)'
alias dsdf='docker system df'
alias dsev='docker system events'

# Docker helper functions (require fzf for interactive selection)

# Docker container ID selector
dcids() {
  if ! command -v fzf >/dev/null 2>&1; then
    echo "fzf is required for this function"
    return 1
  fi

  local cids cmd
  if [ -n "$1" ]; then
    cmd="docker ps -a"
  else
    cmd="docker ps"
  fi
  cids=$(eval "$cmd --format 'table {{.ID}}\t{{.Image}}\t{{.Status}}\t{{.Names}}' \
    | sed 1d | fzf --exit-0 --query='$1'")
  echo "$cids" | awk '{print $1}'
}

# Docker image ID selector
dimgids() {
  if ! command -v fzf >/dev/null 2>&1; then
    echo "fzf is required for this function"
    return 1
  fi

  local imgids
  imgids=$(docker images -a | sed 1d | fzf --exit-0 --query="$1" | awk '{print $3}')
  echo "$imgids"
}

# Docker run with fzf image selection
drun() {
  local imgids=$(dimgids)
  [ -n "$imgids" ] && docker run "$@" "$imgids"
}

# Docker start with fzf
dstart() {
  local cid=$(dcids 1)
  [ -n "$cid" ] && docker start "$cid"
}

# Docker rm with fzf
drm_container() {
  local cid=$(dcids 1)
  [ -n "$cid" ] && docker rm "$cid"
}

# Docker stop with fzf
dstop() {
  local cid=$(dcids)
  [ -n "$cid" ] && docker stop "$cid"
}

# Docker attach with fzf
dattach() {
  local cid=$(dcids)
  [ -n "$cid" ] && docker attach "$cid"
}

# Docker restart with fzf
drestart() {
  local cid=$(dcids)
  [ -n "$cid" ] && docker restart "$cid"
}

# Docker kill with fzf
dkill() {
  local cid=$(dcids)
  [ -n "$cid" ] && docker kill "$cid"
}

# Docker logs with fzf
dlog() {
  local cid=$(dcids 1)
  [ -n "$cid" ] && docker logs -f "$cid"
}

# Docker exec bash with fzf
dexb() {
  local cid=$(dcids)
  [ -n "$cid" ] && docker exec -it "$cid" bash
}

# Docker exec zsh with fzf
dexz() {
  local cid=$(dcids)
  [ -n "$cid" ] && docker exec -it "$cid" zsh
}

# Docker exec sh with fzf
dexsh() {
  local cid=$(dcids)
  [ -n "$cid" ] && docker exec -it "$cid" sh
}

# Docker rmi with fzf
drmi() {
  local imgids=$(dimgids)
  [ -n "$imgids" ] && docker rmi "$imgids"
}

# Docker notebook launcher
dnotebook() {
  local port=${1:-8889}
  docker run --rm -p "$port:$port" -v "$PWD":/home/jovyan/work \
        bassstring/notebook:latest start-notebook.sh --NotebookApp.port="$port"
}

# Docker lab launcher
dlab() {
  local port=8888
  local dockerhome="/home/jovyan/work"
  docker run --rm -p "$port:$port" -e JUPYTER_ENABLE_LAB=yes \
    -v "$PWD":$dockerhome  jupyter/datascience-notebook:latest \
    start-notebook.sh --NotebookApp.port=$port \
    --NotebookApp.quit_button=False
}
