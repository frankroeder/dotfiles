autoload -U colors && colors

for COLOR in RED GREEN YELLOW BLUE MAGENTA CYAN BLACK WHITE; do
  eval $COLOR='$fg_no_bold[${(L)COLOR}]'
  eval BOLD_$COLOR='$fg_bold[${(L)COLOR}]'
done
eval RESET='$reset_color'

if (( $+commands[gdircolors] )); then
  eval "$(gdircolors -b "${HOME}/.dircolors" 2>/dev/null || gdircolors -b)"
elif (( $+commands[dircolors] )); then
  eval "$(dircolors -b "${HOME}/.dircolors" 2>/dev/null || dircolors -b)"
else
  unset LS_COLORS
fi

unset GREP_COLORS
export ZSH_AUTOSUGGEST_HIGHLIGHT_STYLE="fg=${DANK_TERM_BRIGHT_BLACK:-242},italic"
typeset -gA ZSH_HIGHLIGHT_STYLES
ZSH_HIGHLIGHT_STYLES[comment]="fg=${DANK_TERM_BRIGHT_BLACK:-242},italic"
ZSH_HIGHLIGHT_STYLES[path]="fg=${DANK_TERM_BLUE:-blue},underline"
ZSH_HIGHLIGHT_STYLES[globbing]="fg=${DANK_TERM_BLUE:-blue}"
ZSH_HIGHLIGHT_STYLES[history-expansion]="fg=${DANK_TERM_MAGENTA:-magenta}"
ZSH_HIGHLIGHT_STYLES[single-quoted-argument]="fg=${DANK_TERM_YELLOW:-yellow}"
ZSH_HIGHLIGHT_STYLES[double-quoted-argument]="fg=${DANK_TERM_YELLOW:-yellow}"
ZSH_HIGHLIGHT_STYLES[dollar-quoted-argument]="fg=${DANK_TERM_YELLOW:-yellow}"
ZSH_HIGHLIGHT_STYLES[command-substitution-delimiter]="fg=${DANK_TERM_MAGENTA:-magenta}"
ZSH_HIGHLIGHT_STYLES[process-substitution-delimiter]="fg=${DANK_TERM_MAGENTA:-magenta}"
ZSH_HIGHLIGHT_STYLES[back-quoted-argument-delimiter]="fg=${DANK_TERM_MAGENTA:-magenta}"
ZSH_HIGHLIGHT_STYLES[unknown-token]="fg=${DANK_TERM_RED:-red},bold"
ZSH_HIGHLIGHT_STYLES[arg0]="fg=${DANK_TERM_GREEN:-green}"

export CLICOLOR=1
