! [ $commands[docker] ] && return

alias dredis='docker run -p 6379:6379 redis:latest'
alias dmongodb='docker run -p 27017:27017 mongo:latest'
alias dmysql="docker run -p 3306:3306 -e MYSQL_ALLOW_EMPTY_PASSWORD=1 -d mysql:latest"
alias dbusybox='docker run -it --rm busybox:latest'

d{lab,notebook}() {
  local fn=${funcstack[1]:1}
  local port=8888
  local dockerhome="/home/jovyan/work"
  if [[ $fn = "lab" ]]; then
    docker run --rm -p "$port:$port" -e JUPYTER_ENABLE_LAB=yes \
      -v "$PWD":$dockerhome  jupyter/datascience-notebook:latest \
      start-notebook.sh --NotebookApp.port=$port \
      --NotebookApp.quit_button=False
  else
    docker run --rm -p "$port:$port" -v "$PWD":$dockerhome \
      bassstring/notebook:latest start-notebook.sh --NotebookApp.port=$port
  fi
}
dtf() {
  docker run -it --rm -v "$PWD":/tmp -w /tmp tensorflow/tensorflow:latest python "$1"
}
dpytorch() {
  docker run --rm -it --init --ipc=host \
    --user="$(id -u):$(id -g)" --volume="$PWD:/app" \
    -e NVIDIA_VISIBLE_DEVICES=0 anibali/pytorch:latest python3 "$1"
}

alias drbase='docker run  --rm -it r-base:latest'
alias ffmpeg='docker run --rm -it -v $PWD:/data bassstring/ffmpeg:latest'
alias youtube-dl='docker run --rm -it -v $PWD:/data bassstring/youtube-dl:latest'
alias imagemagick='docker run --rm -it  -v $PWD:/data bassstring/imagemagick:latest'
alias tldr='docker run --rm -it -v ~/.tldr/:/root/.tldr/ nutellinoit/tldr:latest'
alias shellcheck='docker run --rm -v $PWD:/mnt koalaman/shellcheck:latest  -C always -s bash'

alias dps='docker ps'
alias dimg='docker images'
alias drmall='docker rm $(docker ps -a -q)'
alias dkillall='docker kill $(docker ps -a -q)'
alias drmiall='docker rmi $(docker images -a -q)'
alias dsdf='docker system df'
alias dsev='docker system events'
alias dsprune='docker system prune'
alias dtop='docker stats $(docker ps --format="{{.Names}}")'
alias dnet='docker network ls && echo && docker inspect --format "{{\$e := . }}{{with .NetworkSettings}} {{\$e.Name}}
  {{range \$index, \$net := .Networks}}  - {{\$index}}	{{.IPAddress}}
  {{end}}{{end}}" $(docker ps -q)'
alias dtag='docker inspect --format "{{.Name}}
  {{range \$index, \$label := .Config.Labels}}  - {{\$index}}={{\$label}}
  {{end}}" $(docker ps -q)'


dcids() {
  local cids cmd
  if [[ -n $1 ]] then; cmd="docker ps -a"; else cmd="docker ps"; fi
  cids=$(eval "$cmd --format 'table {{.ID}}\t{{.Image}}\t{{.Status}}\t{{.Names}}' \
    | sed 1d | fzf --exit-0 --query='$1'")
  echo $cids | awk '{print $1}'
}
dimgids() {
  local imgids
  imgids=$(docker images -a | sed 1d | fzf --exit-0 --query="$1" | awk '{print $3}')
  echo $imgids
}
drun() {
  local imgids=$(dimgids)
  [ -n "$imgids" ] && docker run $@ $imgids
}
d{start,rm} () {
  local cid=$(dcids 1)
  local fn=${funcstack[1]:1}
  [ -n "$cid" ] && docker $fn "$cid"
}
d{stop,attach,restart,kill} () {
  local cid=$(dcids)
  local fn=${funcstack[1]:1}
  [ -n "$cid" ] && docker $fn "$cid"
}
dlog() {
  local cid=$(dcids 1)
  [ -n "$cid" ] && docker logs -f "$cid"
}
dex{b,z,ec}() {
  local cid=$(dcids)
  local fn=${funcstack[1]:3}
  local shell=
  if [[ "$fn" = "b" ]] then;
    shell=bash;
  elif [[ "$fn" = "z" ]] then;
    shell=zsh;
  else
    shell='sh -c "'$1'"'
  fi
  [ -n "$cid" ] && eval "docker exec -it $cid $shell"
}
drmi() {
  local imgids=$(dimgids)
  [ -n "$imgids" ] && docker rmi "$imgids"
}

! [ $commands[docker-compose] ] && return

alias dcp='docker-compose'
