autoload -U colors && colors

_dank_zsh_colors="${XDG_CACHE_HOME:-$HOME/.cache}/DankMaterialShell/zsh-colors.zsh"

_dank_reload_colors() {
  [[ -r "$_dank_zsh_colors" ]] && source "$_dank_zsh_colors"
}

_dank_reload_colors

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

_dank_reload_zsh_theme() {
  _dank_reload_colors
  [[ -r "${DOTFILES:-$HOME/.dotfiles}/zsh/dots/prompt.zsh" ]] && source "${DOTFILES:-$HOME/.dotfiles}/zsh/dots/prompt.zsh"
  zle && zle reset-prompt
}

TRAPURG() {
  _dank_reload_zsh_theme
  return 0
}
