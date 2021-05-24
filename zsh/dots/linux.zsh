[[ $OSTYPE != 'Linux' ]] && return

path=(
  "$HOME/.local/bin"
  "$HOME/bin"
  "$HOME/bin/njs"
  $path
)

alias varwww='cd /var/www/html/'
alias distro='cat /etc/issue'
alias whou='who -u | sort -k 3 --reverse'
alias datehelp='for F in {a..z} {A..Z} :z ::z :::z;do echo $F: $(date +%$F);done|sed "/:[\ \t\n]*$/d;/%[a-zA-Z]/d"'
alias swaptop='whatswap | egrep -v "Swap used: 0" |sort -n -k 10'

[ $commands[nvidia-smi] ] && alias wgpu='watch -n 0.1 -d nvidia-smi'

if [ $commands[xsel] ]; then
    alias pbcopy='xsel --clipboard --input'
    alias pbpaste='xsel --clipboard --output'
    alias open=xdg-open
fi
