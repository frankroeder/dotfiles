[ $+commands[docker] -eq 0 ] && return

alias docker-redis='docker run -p 6379:6379 redis'
alias docker-mongodb='docker run -p 27017:27017 mongo'
alias docker-mysql="docker run -p 3306:3306 -e MYSQL_ALLOW_EMPTY_PASSWORD=1 -d mysql"

docker-tf() {
  docker run -it --rm -v "$PWD":/tmp -w /tmp tensorflow/tensorflow python "$1"
}
docker-pytorch() {
  docker run --rm -it --init --ipc=host \
    --user="$(id -u):$(id -g)" --volume="$PWD:/app" \
    -e NVIDIA_VISIBLE_DEVICES=0 anibali/pytorch python3 "$1"
}

alias ffmpeg='docker run --rm -i -t -v $PWD:/tmp/workdir jrottenberg/ffmpeg'
alias youtube-dl='docker run --rm -i -t -v $PWD:/data vimagick/youtube-dl'

alias dps='docker ps'
alias dimg='docker images'
alias drmall='docker rm $(docker ps -a -q)'
alias dkillall='docker kill $(docker ps -a -q)'
alias drmiall='docker rmi $(docker images -a -q)'
alias dsdf='docker system df'
alias dsev='docker system events'

dcids() {
  local cids
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
dexb() {
  local cid=$(dcids)
  [ -n "$cid" ] && docker exec -it "$cid" bash
}
drmi() {
  local imgids=$(dimgids)
  [ -n "$imgids" ] && docker rmi "$imgids"
}

[ $+commands[docker-compose] -eq 0 ] && return

alias dcp='docker-compose'
