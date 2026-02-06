# container CLI shortcuts
# https://github.com/apple/container/tree/main
! [ $commands[container] ] && return

alias cbusybox='container run -it --rm busybox:latest'
alias crbase='container run  --rm -it r-base:latest'

alias cls='container ls'
alias cils='container images ls'
alias crmall='container rm --all'
alias ckillall='container kill $(container ls -a -q)'
alias crmiall='container images rm $(container images ls -q)'
alias csls='container system logs'

cname() {
  local names cmd
  if [[ -n $1 ]] then; cmd="container ls -a"; else cmd="container ls"; fi
  name=$(eval "$cmd --format json --all | jq -r '.[] | select(.status == \"running\") | .configuration.id' | fzf --exit-0 --query='$1'")
  echo $name
}
cimgname() {
  local imgname
  imgname=$(container images ls -q | fzf --exit-0 --query="$1")
  echo $imgname
}
crun() {
  local cimgname=$(cimgname)
  echo "select $cimgname"
  [ -n "$cimgname" ] && container run $@ $cimgname
}
c{start,rm} () {
  local cn=$(cname 1)
  local fn=${funcstack[1]:1}
  [ -n "$cn" ] && container $fn "$cn"
}
c{stop,inspect,kill,delete} () {
  local cn=$(cname)
  local fn=${funcstack[1]:1}
  [ -n "$cn" ] && container $fn "$cn"
}
clogs() {
  local cn=$(cname)
  [ -n "$cn" ] && container logs --follow "$cn"
}
cex{b,z,ec}() {
  local cn=$(cname)
  local fn=${funcstack[1]:3}
  local shell=
  if [[ "$fn" = "b" ]] then;
    shell=bash;
  elif [[ "$fn" = "z" ]] then;
    shell=zsh;
  else
    shell='sh -c "'$1'"'
  fi
  [ -n "$cn" ] && eval "container exec -it $cn $shell"
}
crmi() {
  local imgname=$(cimgname)
  [ -n "$imgname" ] && container images rm "$imgname"
}
