[ -z "$HISTFILE" ] && HISTFILE="$HOME/.zsh_history"

HISTSIZE=2000                 # lines of history to keep in memory
SAVEHIST=10000                # lines of history to save to disk
HISTCONTROL=ignoreboth
HISTORY_IGNORE=(
  "clear"
  "history"
  "exit"
  "pwd"
  "wget *"
  "ls"
  "l"
  "la"
  "lsd"
  "lla"
  "cd"
  "c"
  "rg *"
  ":q"
  "del *"
  "alias"
  "lstcp"
  "lsudp"
  "gcmsg"
  "dalle3"
  "gptvision"
)

setopt HIST_IGNORE_ALL_DUPS
setopt EXTENDED_HISTORY       # record timestamp of command in HISTFILE
setopt HIST_IGNORE_SPACE      # ignore commands that start with space
setopt HIST_VERIFY            # Do not execute immediately upon history expansion
setopt INC_APPEND_HISTORY     # add commands to HISTFILE in order of execution
setopt SHARE_HISTORY          # share command history across shells
setopt HIST_REDUCE_BLANKS
setopt HIST_FCNTL_LOCK

zstyle ':completion:*:history-words' stop yes
zstyle ':completion:*:history-words' remove-all-dups yes
zstyle ':completion:*:history-words' list false
zstyle ':completion:*:history-words' menu yes
