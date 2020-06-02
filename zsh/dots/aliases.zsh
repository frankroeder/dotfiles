alias cp='nice cp'
alias mv='nice mv'
alias grep='grep --color=auto'

alias src='exec "$SHELL" -l'
alias {dotfiles,dots}='cd ~/.dotfiles'
alias tmp='cd ~/tmp'
alias vim='$EDITOR'
alias speedtest="wget -O /dev/null http://speed.transip.nl/100mb.bin"
alias vimrc="$EDITOR ~/.dotfiles/nvim/{init.vim,plugin/*}"
alias localrc="if [[ -a ~/.local.zsh ]]; then $EDITOR ~/.local.zsh; fi"
alias localgit="if [[ -a ~/.local.gitconfig ]]; then $EDITOR ~/.local.gitconfig; fi"
alias localtmux="if [[ -a ~/.local.tmux ]]; then $EDITOR ~/.local.tmux; fi"
alias localvim="if [[ -a ~/.local.vim ]]; then $EDITOR ~/.local.vim; fi"

# CPU and MEM Monitoring
alias cpu="top -F -R -o cpu"
alias mem="top -F -o rsize"
alias hogs="ps wwaxr -o pid,stat,%cpu,time,command | awk 'NR<=10'"

# Print each PATH entry on a separate line
alias path='echo -e ${PATH//:/\\n}'

# Print each function name
alias showfunctions="declare -f | grep '^[a-z].* ()' | sed 's/{$//'"
alias ag="ag --path-to-ignore $DOTFILES/ignore"
alias :q="exit"
alias ipd="curl -sS ipinfo.io  2>/dev/null | jq ."
alias -g @="| grep -i"
alias joke="curl https://icanhazdadjoke.com"

# Get week number
alias week='date +%V'

alias npmls='npm ls --depth=0'
alias npmlsg='npm ls --depth=0 -g'

alias dfh='df -h'
alias copypubkey='pbcopy < ~/.ssh/id_rsa.pub'
alias ipy='ipython'
alias ippdb='ipython --pprint --pdb'

# open last edited file
alias v0="$EDITOR -c \"normal '0\""
alias online="ping -c 1 www.example.com &> /dev/null && echo 'Online :)' || echo 'Offline :('"

# start plain vim
alias pvim="$EDITOR -u NONE -i NONE -n -N -n"
