[[ $OSTYPE != 'Linux' ]] && return

path=(
  "$HOME/.local/bin"
  "$HOME/.local/nodejs/bin"
  $path
)

alias f='xdg-open ./'
alias varwww='cd /var/www/html/'
alias distro='cat /etc/issue'
alias whou='who -u | sort -k 3 --reverse'
realusers(){
  awk -F: '$3 >= 1000 && $3 != 65534 {print $1}' /etc/passwd
}
alias datehelp='for F in {a..z} {A..Z} :z ::z :::z;do echo $F: $(date +%$F);done|sed "/:[\ \t\n]*$/d;/%[a-zA-Z]/d"'
alias swaptop='whatswap | egrep -v "Swap used: 0" |sort -n -k 10'
if [ $commands[smem] ]; then
	alias swaphogs='smem --sort swap --reverse --autosize'
fi

if [ $commands[nvidia-smi] ]; then
	alias wgpu='watch -n 0.1 -d nvidia-smi'
	alias nogpu='export CUDA_VISIBLE_DEVICES=-1'
fi

[ $commands[nvitop] ] && alias ntop='nvitop --monitor auto --gpu-util-thresh 50 80 --mem-util-thresh 60 90'

if [ $commands[xclip] ]; then
	alias pbcopy='xclip -selection clipboard'
	alias pbpaste='xclip -selection clipboard -o'
	alias copypubkey='xclip -selection clipboard < ~/.ssh/id_rsa.pub'
fi
[ $commands[xdg-open] ] && function open() { xdg-open $@; };
