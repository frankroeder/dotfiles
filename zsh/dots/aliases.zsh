alias cp='nice cp'
alias mv='nice mv'
alias grep='grep --color=auto'

alias src='exec "$SHELL" -l'
alias {dotfiles,dots}='cd $HOME/.dotfiles'
alias tmp='cd $HOME/tmp'
alias vim='$EDITOR'
alias speedtest="wget -O /dev/null http://speed.transip.nl/1gb.bin"
alias vimrc="$EDITOR $HOME/.dotfiles/nvim/{init.vim,plugin/*,lua/*}"
alias localrc="$EDITOR $HOME/.local.zsh"
alias localgit="$EDITOR $HOME/.local.gitconfig"
alias localtmux="$EDITOR $HOME/.local.tmux"
alias localvim="$EDITOR $HOME/.local.vim"

alias hogs="ps wwaxr -o pid,stat,%cpu,time,command | awk 'NR<=10'"
alias mails="$EDITOR /var/mail/$USER"

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
alias ipy='ipython'
alias ippdb='ipython --pprint --pdb'

# open last edited file
alias v0="$EDITOR -c \"normal '0\""
alias online="ping -c 1 www.example.com &> /dev/null && echo 'Online :)' || echo 'Offline :('"

# start plain vim
alias pvim="$EDITOR -u NONE -i NONE -n -N -n"
alias vimlogs='less $HOME/.local/share/nvim/lsp.log /tmp/*.log'
alias nman="MANPAGER='nvim +Man!' man"

alias fixjedi='pip3 install ujson==3.0.0 jedi==0.17.2'
