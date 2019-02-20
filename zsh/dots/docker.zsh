# Docker Shortcuts
# ------------------------------------------------------------------------------

alias docker-redis='docker run -p 6379:6379 redis'
alias docker-mongodb='docker run -p 27017:27017 mongo'
alias docker-purge-container='docker rm $(docker ps -a -q)'
alias docker-purge-images='docker rmi $(docker images -q)'

docker-mysql() {
  docker run -p 3306:3306 -e MYSQL_ALLOW_EMPTY_PASSWORD=1 -d mysql
}
docker-tf-jupyter() {
  docker run -u $(id -u):$(id -g) -it -p 8888:8888 \
    tensorflow/tensorflow:nightly-py3-jupyter
}

# execute a given pythonfile in a docker tf container
docker-tf() {
  docker run -it --rm -v $PWD:/tmp -w /tmp tensorflow/tensorflow python $1
}
