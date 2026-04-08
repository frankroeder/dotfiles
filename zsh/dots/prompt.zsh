autoload -U promptinit; promptinit
# prompt pure

PURE_GIT_PULL=1
PURE_GIT_UNTRACKED_DIRTY=1
PURE_PROMPT_SYMBOL='➜'
PURE_GIT_DOWN_ARROW='↓'
PURE_GIT_UP_ARROW='↑'

zstyle :prompt:pure:path color "${DANK_TERM_CURSOR:-#006399}"
zstyle :prompt:pure:git:branch color "${DANK_TERM_BRIGHT_BLUE:-#89b4fa}"
zstyle :prompt:pure:git:branch:cached color "${DANK_TERM_RED:-#91002e}"
zstyle :prompt:pure:git:dirty color "${DANK_TERM_BRIGHT_RED:-#f38ba8}"
zstyle :prompt:pure:git:action color "${DANK_TERM_BRIGHT_CYAN:-#94e2d5}"
zstyle :prompt:pure:git:arrow color "${DANK_TERM_CURSOR:-#006399}"
zstyle :prompt:pure:git:stash color "${DANK_TERM_CURSOR:-#006399}"
zstyle :prompt:pure:host color "${DANK_TERM_BRIGHT_BLACK:-#7b7f82}"
zstyle :prompt:pure:user color "${DANK_TERM_BRIGHT_BLACK:-#7b7f82}"
zstyle :prompt:pure:virtualenv color "${DANK_TERM_BRIGHT_BLACK:-#7b7f82}"
zstyle :prompt:pure:prompt:success color "${DANK_TERM_CURSOR:-#006399}"
zstyle :prompt:pure:prompt:error color "${DANK_TERM_RED:-#91002e}"
zstyle :prompt:pure:execution_time color "${DANK_TERM_BRIGHT_CYAN:-#94e2d5}"
RPROMPT="%F{${DANK_TERM_BRIGHT_BLACK:-#7b7f82}}%*%f"

# remove color-inverter % when output doesn't include trailing newline
unsetopt PROMPT_CR PROMPT_SP
setopt INTERACTIVECOMMENTS
