#!/usr/bin/env bash

c() { builtin cd "$@"; ls; }

# Create directory and cd into it
mcd () {
  mkdir -p "$@" && cd "$_"
}
# ls with file permissions in octal format
lla(){
 	ls -l "$@" | awk '
    {
      k=0;
      for (i=0;i<=8;i++)
        k+=((substr($1,i+2,1)~/[rwx]/) *2^(8-i));
      if (k)
        printf("%0o ",k);
      printf(" %9s  %3s %2s %5s  %6s  %s %s %s\n", $3, $6, $7, $8, $5, $9,$10, $11);
    }'
}
extract () {
  if [ -f $1 ] ; then
    case $1 in
      *.tar.bz2)   tar xjf $1     ;;
      *.tar.gz)    tar xzf $1     ;;
      *.bz2)       bunzip2 $1     ;;
      *.rar)       unrar e $1     ;;
      *.gz)        gunzip $1      ;;
      *.tar)       tar xf $1      ;;
      *.tbz2)      tar xjf $1     ;;
      *.tgz)       tar xzf $1     ;;
      *.zip)       unzip $1       ;;
      *.Z)         uncompress $1  ;;
      *.7z)        7z x $1        ;;
      *)     echo "'$1' cannot be extracted via extract()" ;;
    esac
  else
    echo "'$1' is not a valid file"
  fi
}
ii() {
  echo -e "\n${ORANGE}You are logged on:$RESET"; hostname
  echo -e "\n${LIGHT_BLUE}Additionnal information:$RESET " ; uname -a
  echo -e "\n${LIGHT_BLUE}Users logged on:$RESET " ; w -h
  echo -e "\n${LIGHT_BLUE}Current date :$RESET " ; date
  echo -e "\n${LIGHT_BLUE}Machine stats :$RESET " ; uptime
  echo -e "\n${LIGHT_BLUE}IP for Inter Connection:$RESET"; curl -4 icanhazip.com
}
del () {
  command mv "$@" ~/.Trash
}
emptytrash() {
  rm -rfv ~/.Trash/* ;\
}

# Overwrite man with different color
man() {
	env \
		LESS_TERMCAP_mb=$(printf "\e[1;34m") \
		LESS_TERMCAP_md=$(printf "\e[1;34m") \
		LESS_TERMCAP_me=$(printf "\e[0m") \
		LESS_TERMCAP_se=$(printf "\e[0m") \
		LESS_TERMCAP_so=$(printf "\e[1;44;33m") \
		LESS_TERMCAP_ue=$(printf "\e[0m") \
		LESS_TERMCAP_us=$(printf "\e[1;32m") \
			man "$@"
}
# v - fuzzy vim
v(){
  local files
  IFS=$'\n' files=($(fzf-tmux --query="$1" --multi --select-1 --exit-0))
  [[ -n "$files" ]] && ${EDITOR:-vim} "${files[@]}"
}

# flog - fuzzy commit logs
glz() {
  git log --graph --color=always \
      --format="%C(auto)%h%d %s %C(black)%C(bold)%cr" "$@" |
  fzf --ansi --no-sort --reverse --tiebreak=index --bind=ctrl-s:toggle-sort \
      --bind "ctrl-m:execute:
                (grep -o '[a-f0-9]\{7\}' | head -1 |
                xargs -I % sh -c 'git show --color=always % | less -R') << 'FZF-EOF'
                {}
  FZF-EOF"
}

# Get cheat sheet of command from cheat.sh. cheat <cmd>
cheat() {
  curl https://cheat.sh/$@
}

retry() {
  while true; do $@; sleep 1; done
}

dcids() {
  local cids cmd
  if [ -n "$1" ]
  then
    cmd="docker ps -a";
  else
    cmd="docker ps";
  fi
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
dnotebook() {
  local port=${1-8889}
  docker run --rm -p "$port:$port" -v "$PWD":/home/jovyan/work \
        bassstring/notebook:latest start-notebook.sh --NotebookApp.port=$port
}
