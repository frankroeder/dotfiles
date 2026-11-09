(( ${+commands[fzf]} )) || return

bindkey '^Z' fzf-cd-widget

# Asahi wallpaper palette (asahi-theme.zsh loads first; stock fzf elsewhere).
if [[ -n "$CATPPUCCIN_TERM_BACKGROUND" ]]; then
  export FZF_DEFAULT_OPTS="${FZF_DEFAULT_OPTS:+$FZF_DEFAULT_OPTS }--color=bg:$CATPPUCCIN_TERM_BACKGROUND,\
fg:$CATPPUCCIN_TERM_FOREGROUND,hl:$CATPPUCCIN_TERM_BLUE,fg+:$CATPPUCCIN_TERM_FOREGROUND,\
bg+:$CATPPUCCIN_TERM_SELECTION_BG,hl+:$CATPPUCCIN_TERM_BLUE,info:$CATPPUCCIN_TERM_YELLOW,\
prompt:$CATPPUCCIN_TERM_GREEN,pointer:$CATPPUCCIN_TERM_CURSOR,marker:$CATPPUCCIN_TERM_MAGENTA,\
spinner:$CATPPUCCIN_TERM_MAGENTA"
fi
