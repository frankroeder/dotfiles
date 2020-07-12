[[ $OSTYPE != 'Linux' ]] && return

path=("$HOME/.local/bin" $path)
path=("$HOME/bin" $path)

alias varwww='cd /var/www/html/'
alias mails="vim /var/mail/$USER"
alias distro='cat /etc/issue'
alias whou='who -u | sort -k 3 --reverse'

[ $commands[nvidia-smi] ] && alias wgpu='watch -n 0.1 -d nvidia-smi'
