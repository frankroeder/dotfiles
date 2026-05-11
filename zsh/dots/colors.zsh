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

export CLICOLOR=1
