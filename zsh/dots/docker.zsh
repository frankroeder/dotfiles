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

alias dps='docker ps -a'
alias dimg='docker images -a'
alias drmall='docker rm $(docker ps -a -q)'
alias dkillall='docker kill $(docker ps -a -q)'
alias drmiall='docker rmi $(docker images -a -q)'

dcids() {
  local cids
  cids=$(docker ps -a --format "table {{.ID}}\t{{.Image}}\t{{.Status}}\t{{.Names}}" \
    | sed 1d | fzf --exit-0 --query="$1" | awk '{print $1}')
  echo $cids
}
dimgids() {
  local imgids
  imgids=$(docker images -a | sed 1d | fzf --exit-0 --query="$1" | awk '{print $3}')
  echo $imgids
}
d{start,stop,attach,restart,kill,rm} () {
  local cid=$(dcids)
  local fn=${funcstack[1]:1}
  [ -n "$cid" ] && docker $fn "$cid"
}
dlog() {
  local cid=$(dcids)
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
