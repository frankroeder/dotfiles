# Catppuccino
# https://github.com/Pocco81/Catppuccino.nvim/blob/main/lua/catppuccino/color_schemes/catppuccino.lua

BACKGROUND="#0e171c"
FOREGROUND="#abb2bf" # e.g., text
FG_GUTTER="#3b4261"
BLACK="#393b44"
GRAY="#2a2e36"
RED="#c94f6d"
GREEN="#97c374"
YELLOW="#dbc074"
BLUE="#61afef"
MAGENTA="#c678dd"
CYAN="#63cdcf"
WHITE="#dfdfe0"
ORANGE="#f4a261"
PINK="#d67ad2"
BLACK_BR="#7f8c98"
RED_BG="#e06c75",
GREEN_BR="#58cd8b"
YELLOW_BR="#ffe37e"
BLUE_BR="#84cee4"
MAGENTA_BR="#b8a1e3"
CYAN_BR="#59f0ff"
WHITE_BR="#fdebc3"
ORANGE_BR="#f6a878"
PINK_BR="#df97db"
COMMENT="#526175"

## set status bar
set -g status-style "fg=$FOREGROUND,bg=$BACKGROUND"
setw -g window-status-current-style "bg=$BACKGROUND,fg=$FOREGROUND"

## highlight active window
# style of default windows
setw -g window-style "fg=$COMMENT"
# style of active window
setw -g window-active-style "fg=$WHITE"
setw -g pane-active-border-style ''

## highlight activity in status bar
setw -g window-status-activity-style "fg=$CYAN,bg=$BACKGROUND"

## pane border and colors
set -g pane-active-border-style "bg=$BACKGROUND,fg=$ORANGE"
set -g pane-border-style "bg=$BACKGROUND"
set -g pane-border-style "fg=$ORANGE"

set -g clock-mode-colour "$GREEN"
set -g clock-mode-style 24

set -g message-style "bg=$WHITE,fg=$BACKGROUND"
set -g message-command-style "bg=$WHITE,fg=$BACKGROUND"

# message bar or "prompt"
set -g message-style "bg=$BACKGROUND"
set -g message-style "fg=$YELLOW"

set -g mode-style "bg=$YELLOW,fg=$BLACK"

# make background window look like white tab
set-window-option -g window-status-style "bg=default,fg=white"
set-window-option -g window-status-style none
set-window-option -g window-status-format "#[fg=$BLUE,bg=$BACKGROUND] #I #[fg=$WHITE,bg=$BACKGROUND] #W #[default]"

# make foreground window look like bold yellow foreground tab
set-window-option -g window-status-current-style none
set-window-option -g window-status-current-format "#[fg=$ORANGE,bg=$GRAY] #I #[fg=#cccccc,bg=$GRAY] #W #[default]"

# active terminal yellow border, non-active white
set -g pane-border-style "bg=default,fg=#999999"
set -g pane-active-border-style fg="$ORANGE"

# vim: set filetype=tmux:
