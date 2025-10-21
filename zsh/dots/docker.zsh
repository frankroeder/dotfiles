# Zsh-specific docker configuration (common docker functions are in shared/docker_functions.sh)
! [ $commands[docker] ] && return

# Docker container shortcuts (zsh-specific aliases)
dsgpt(){
  docker run --rm --env OPENAI_API_KEY --volume gpt-cache:/tmp/shell_gpt ghcr.io/ther1d/shell_gpt "$*"
}
alias dredis='docker run -p 6379:6379 redis:latest'
alias dmongodb='docker run -p 27017:27017 mongo:latest'
alias dmysql="docker run -p 3306:3306 -e MYSQL_ALLOW_EMPTY_PASSWORD=1 -d mysql:latest"
alias dbusybox='docker run -it --rm busybox:latest'

# TensorFlow runner
dtf() {
  docker run -it --rm -v "$PWD":/tmp -w /tmp tensorflow/tensorflow:latest python "$1"
}

# PyTorch runner
dpytorch() {
  docker run --rm -it --init --ipc=host \
    --user="$(id -u):$(id -g)" --volume="$PWD:/app" \
    -e NVIDIA_VISIBLE_DEVICES=0 anibali/pytorch:latest python3 "$1"
}

# Containerized tools
alias drbase='docker run  --rm -it r-base:latest'
alias dffmpeg='docker run --rm -it -v $PWD:/data bassstring/ffmpeg:latest'
alias dyoutube-dl='docker run --rm -it -v $PWD:/data bassstring/youtube-dl:latest'
alias dimagemagick='docker run --rm -it  -v $PWD:/data bassstring/imagemagick:latest'
alias dtldr='docker run --rm -it -v ~/.tldr/:/root/.tldr/ nutellinoit/tldr:latest'
alias dshellcheck='docker run --rm -v $PWD:/mnt koalaman/shellcheck:latest  -C always -s bash'

# System management
alias dsprune='docker system prune'
alias dtop='docker stats $(docker ps --format="{{.Names}}")'
alias dnet='docker network ls && echo && docker inspect --format "{{\$e := . }}{{with .NetworkSettings}} {{\$e.Name}}
  {{range \$index, \$net := .Networks}}  - {{\$index}}	{{.IPAddress}}
  {{end}}{{end}}" $(docker ps -q)'
alias dtag='docker inspect --format "{{.Name}}
  {{range \$index, \$label := .Config.Labels}}  - {{\$index}}={{\$label}}
  {{end}}" $(docker ps -q)'

# Docker-compose
! [ $commands[docker-compose] ] && return
alias dcp='docker-compose'
