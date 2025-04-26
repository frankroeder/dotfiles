alias cp='nice cp'
alias mv='nice mv'
alias grep='grep --color=auto'

[[ -d "$HOME/Documents" ]] && alias repos='cd $HOME/Documents'
[[ -d "$HOME/Downloads" ]] && alias dl='cd $HOME/Downloads'

alias {src,refresh}='exec "$SHELL" -l'
# forcibly rebuild zcompdump
alias rezcomp='rm -f $HOME/.zcompdump; compinit'
alias {dotfiles,dots}='cd $HOME/.dotfiles'
alias tmp='cd $HOME/tmp'
alias vim=${EDITOR}
alias speedtest="wget -O /dev/null http://speed.transip.nl/1gb.bin"
alias vimrc="$EDITOR $HOME/.dotfiles/nvim/{init.lua,plugin/*,lua/*}"
alias localrc="$EDITOR $HOME/.local.zsh"
alias localgit="$EDITOR $HOME/.local.gitconfig"
alias localtmux="$EDITOR $HOME/.local.tmux"
alias localnvim="$EDITOR $HOME/.localnvim.lua"

alias hogs="ps wwaxr -o pid,stat,%cpu,time,command | awk 'NR<=10'"
alias mails="$EDITOR /var/mail/$USER"

# Print each function name
alias showfunctions="declare -f | grep '^[a-z].* ()' | sed 's/{$//'"
[[ $commands[rg] ]] && alias rg="rg --pretty --colors 'match:bg:235,220,170' --ignore-file $DOTFILES/ignore"
alias :q="exit"
[[ $commands[jq] ]] && alias ipd="curl -sS ipinfo.io  2>/dev/null | jq ."
alias -g @="| grep -i"
alias joke="curl https://icanhazdadjoke.com"

# Get week number
alias week='date +%V'
alias iso8601='date -u +"%Y-%m-%dT%H:%M:%SZ"'
alias iso8601-local='date +"%Y-%m-%dT%H:%M:%S%z"'
alias iso8601-date='date +"%Y-%m-%d"'
alias unixtime='date +%s'

if [[ $commands[npm] ]]; then
  alias npmls='npm ls --depth=0'
  alias npmlsg='npm ls --depth=0 --location=global'
fi

alias dfh='df -h'

# open last edited file
alias v0="$EDITOR '+execute \"normal 1\<c-o>\"'"
alias vh{,ist}="$EDITOR '+FzfLua oldfiles'"
alias vhelp="$EDITOR '+FzfLua help_tags'"
alias online="ping -c 1 www.example.com &> /dev/null && echo 'Online :)' || echo 'Offline :('"

# start plain vim
alias pvim="$EDITOR -u NONE -i NONE -n -N -n"
alias vimlogs='tail -F $HOME/.local/state/nvim/{luasnip.log,lsp.log} /tmp/*.log $HOME/.cache/nvim/lsp.log'
alias nman="MANPAGER='nvim --cmd \"set laststatus=0 \" +\"set statuscolumn= nowrap laststatus=0\" +Man!' man"

alias userlist="cut -d: -f1 /etc/passwd | sort"
alias sshconfig="$EDITOR $HOME/.ssh/config"

# Copies the contents of all files in the current directory to clipboard
llmcopy() {

  # Construct find command to exclude directories
  find . -type f \( \! -path "*/.git/*" \! -path "*/build/*" \! -path "*/node_modules/*" \
                 \! -path "*/dist/*" \! -path "*/.venv/*" \! -path "*/__pycache__/*" \) \
    \! -name "*.jpg" \! -name "*.jpeg" \! -name "*.png" \
    \! -name "*.gif" \! -name "*.bmp" \! -name "*.tiff" \
    \! -name "*.mp4" \! -name "*.mov" \! -name "*.avi" \
    \! -name "*.wmv" \! -name "*.mkv" \! -name ".DS_Store" \
    \! -name "uv.lock" \
    -print0 | \
  while IFS= read -r -d '' file; do
    echo "=== $file ==="
    cat "$file"
    echo
  done | pbcopy
}
