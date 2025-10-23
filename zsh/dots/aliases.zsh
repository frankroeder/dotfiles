# Zsh-specific aliases (common aliases are in shared/aliases.sh)

alias {src,refresh}='exec "$SHELL" -l'
# forcibly rebuild zcompdump
alias rezcomp='rm -f $HOME/.zcompdump; compinit'
alias vimrc="$EDITOR $HOME/.dotfiles/nvim/{init.lua,plugin/*,lua/*}"
alias localrc="$EDITOR $HOME/.local.zsh"
alias localgit="$EDITOR $HOME/.local.gitconfig"
alias localtmux="$EDITOR $HOME/.local.tmux"
alias localnvim="$EDITOR $HOME/.localnvim.lua"

[[ $commands[rg] ]] && alias rg="rg --pretty --colors 'match:bg:235,220,170' --ignore-file $DOTFILES/ignore"
alias -g @="| grep -i"

if [[ $commands[npm] ]]; then
  alias npmls='npm ls --depth=0'
  alias npmlsg='npm ls --depth=0 --location=global'
fi

# Neovim-specific aliases
alias v0="$EDITOR '+execute \"normal 1\<c-o>\"'"
alias vh{,ist}="$EDITOR '+FzfLua oldfiles'"
alias vhelp="$EDITOR '+FzfLua help_tags'"
alias pvim="$EDITOR -u NONE -i NONE -n -N -n"
alias vimlogs='tail -F $HOME/.local/state/nvim/{luasnip.log,lsp.log} /tmp/*.log $HOME/.cache/nvim/lsp.log'
alias nman="MANPAGER='nvim --cmd \"set laststatus=0 \" +\"set statuscolumn= nowrap laststatus=0\" +Man!' man"
alias pnvim="nvim -u $DOTFILES/nvim/vanilla.lua"

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
