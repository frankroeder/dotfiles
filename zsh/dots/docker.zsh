alias docker-redis='docker run -p 6379:6379 redis'
alias docker-mongodb='docker run -p 27017:27017 mongo'
alias docker-purge-container='docker rm $(docker ps -a -q)'
alias docker-purge-images='docker rmi $(docker images -q)'
