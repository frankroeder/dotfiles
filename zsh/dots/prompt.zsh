autoload -U promptinit; promptinit
# prompt pure

PURE_GIT_PULL=1
PURE_GIT_UNTRACKED_DIRTY=1
PURE_PROMPT_SYMBOL='➜'
PURE_GIT_DOWN_ARROW='↓'
PURE_GIT_UP_ARROW='↑'
RPROMPT='%*'

# Adaptive Pure palettes. Tune the two blocks below independently.
prompt_pure_color() {
  zstyle ":prompt:pure:$1" color "$2"
}

case "${DANK_TERM_MODE:-light}" in
  dark)
    prompt_pure_color path "${DANK_TERM_BRIGHT_BLUE:-blue}"
    prompt_pure_color user "${DANK_TERM_BRIGHT_BLACK:-242}"
    prompt_pure_color user:root "${DANK_TERM_RED:-red}"
    prompt_pure_color host "${DANK_TERM_BRIGHT_BLACK:-242}"
    prompt_pure_color git:branch "${DANK_TERM_MAGENTA:-magenta}"
    prompt_pure_color git:branch:cached "${DANK_TERM_YELLOW:-yellow}"
    prompt_pure_color git:dirty "${DANK_TERM_YELLOW:-yellow}"
    prompt_pure_color git:action "${DANK_TERM_RED:-red}"
    prompt_pure_color git:arrow "${DANK_TERM_CYAN:-cyan}"
    prompt_pure_color git:stash "${DANK_TERM_MAGENTA:-magenta}"
    prompt_pure_color execution_time "${DANK_TERM_YELLOW:-yellow}"
    prompt_pure_color prompt:success "${DANK_TERM_GREEN:-green}"
    prompt_pure_color prompt:error "${DANK_TERM_RED:-red}"
    prompt_pure_color prompt:continuation "${DANK_TERM_BRIGHT_BLACK:-242}"
    prompt_pure_color suspended_jobs "${DANK_TERM_RED:-red}"
    prompt_pure_color virtualenv "${DANK_TERM_MAGENTA:-magenta}"
    ;;
  *)
    prompt_pure_color path "${DANK_TERM_BLUE:-blue}"
    prompt_pure_color user "${DANK_TERM_BLACK:-242}"
    prompt_pure_color user:root "${DANK_TERM_RED:-red}"
    prompt_pure_color host "${DANK_TERM_BLACK:-242}"
    prompt_pure_color git:branch "${DANK_TERM_MAGENTA:-magenta}"
    prompt_pure_color git:branch:cached "${DANK_TERM_CYAN:-cyan}"
    prompt_pure_color git:dirty "${DANK_TERM_RED:-red}"
    prompt_pure_color git:action "${DANK_TERM_RED:-red}"
    prompt_pure_color git:arrow "${DANK_TERM_CYAN:-cyan}"
    prompt_pure_color git:stash "${DANK_TERM_MAGENTA:-magenta}"
    prompt_pure_color execution_time "${DANK_TERM_YELLOW:-yellow}"
    prompt_pure_color prompt:success "${DANK_TERM_GREEN:-green}"
    prompt_pure_color prompt:error "${DANK_TERM_RED:-red}"
    prompt_pure_color prompt:continuation "${DANK_TERM_BLACK:-242}"
    prompt_pure_color suspended_jobs "${DANK_TERM_RED:-red}"
    prompt_pure_color virtualenv "${DANK_TERM_MAGENTA:-magenta}"
    ;;
esac

unfunction prompt_pure_color

# remove color-inverter % when output doesn't include trailing newline
unsetopt PROMPT_CR PROMPT_SP
setopt INTERACTIVECOMMENTS
