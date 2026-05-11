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

case "${CATPPUCCIN_TERM_MODE:-light}" in
  dark)
    prompt_pure_color path "${CATPPUCCIN_TERM_BRIGHT_BLUE:-blue}"
    prompt_pure_color user "${CATPPUCCIN_TERM_BRIGHT_BLACK:-242}"
    prompt_pure_color user:root "${CATPPUCCIN_TERM_RED:-red}"
    prompt_pure_color host "${CATPPUCCIN_TERM_BRIGHT_BLACK:-242}"
    prompt_pure_color git:branch "${CATPPUCCIN_TERM_MAGENTA:-magenta}"
    prompt_pure_color git:branch:cached "${CATPPUCCIN_TERM_YELLOW:-yellow}"
    prompt_pure_color git:dirty "${CATPPUCCIN_TERM_YELLOW:-yellow}"
    prompt_pure_color git:action "${CATPPUCCIN_TERM_RED:-red}"
    prompt_pure_color git:arrow "${CATPPUCCIN_TERM_CYAN:-cyan}"
    prompt_pure_color git:stash "${CATPPUCCIN_TERM_MAGENTA:-magenta}"
    prompt_pure_color execution_time "${CATPPUCCIN_TERM_YELLOW:-yellow}"
    prompt_pure_color prompt:success "${CATPPUCCIN_TERM_GREEN:-green}"
    prompt_pure_color prompt:error "${CATPPUCCIN_TERM_RED:-red}"
    prompt_pure_color prompt:continuation "${CATPPUCCIN_TERM_BRIGHT_BLACK:-242}"
    prompt_pure_color suspended_jobs "${CATPPUCCIN_TERM_RED:-red}"
    prompt_pure_color virtualenv "${CATPPUCCIN_TERM_MAGENTA:-magenta}"
    ;;
  *)
    prompt_pure_color path "${CATPPUCCIN_TERM_BLUE:-blue}"
    prompt_pure_color user "${CATPPUCCIN_TERM_BLACK:-242}"
    prompt_pure_color user:root "${CATPPUCCIN_TERM_RED:-red}"
    prompt_pure_color host "${CATPPUCCIN_TERM_BLACK:-242}"
    prompt_pure_color git:branch "${CATPPUCCIN_TERM_MAGENTA:-magenta}"
    prompt_pure_color git:branch:cached "${CATPPUCCIN_TERM_CYAN:-cyan}"
    prompt_pure_color git:dirty "${CATPPUCCIN_TERM_RED:-red}"
    prompt_pure_color git:action "${CATPPUCCIN_TERM_RED:-red}"
    prompt_pure_color git:arrow "${CATPPUCCIN_TERM_CYAN:-cyan}"
    prompt_pure_color git:stash "${CATPPUCCIN_TERM_MAGENTA:-magenta}"
    prompt_pure_color execution_time "${CATPPUCCIN_TERM_YELLOW:-yellow}"
    prompt_pure_color prompt:success "${CATPPUCCIN_TERM_GREEN:-green}"
    prompt_pure_color prompt:error "${CATPPUCCIN_TERM_RED:-red}"
    prompt_pure_color prompt:continuation "${CATPPUCCIN_TERM_BLACK:-242}"
    prompt_pure_color suspended_jobs "${CATPPUCCIN_TERM_RED:-red}"
    prompt_pure_color virtualenv "${CATPPUCCIN_TERM_MAGENTA:-magenta}"
    ;;
esac

unfunction prompt_pure_color

# remove color-inverter % when output doesn't include trailing newline
unsetopt PROMPT_CR PROMPT_SP
setopt INTERACTIVECOMMENTS
