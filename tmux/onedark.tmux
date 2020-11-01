# https://github.com/odedlaz/tmux-onedark-theme/blob/master/tmux-onedark-theme.tmux

ONEDARK_BLACK="#282c34"
ONEDARK_WHITE="#aab2bf"
ONEDARK_LIGHTRED="#e06c75"
ONEDARK_DARKRED="#be5046"
ONEDARK_GREEN="#98c379"
ONEDARK_LIGHTYELLOW="#e5c07b"
ONEDARK_DARKYELLOW="#d19a66"
ONEDARK_BLUE="#61afef"
ONEDARK_MAGENTA="#c678dd"
ONEDARK_CYAN="#56b6c2"
ONEDARK_GUTTER_GREY="#4b5263"
ONEDARK_COMMENT_GREY="#5c6370"

set -g message-style "fg=$ONEDARK_WHITE,bg=$ONEDARK_BLACK"
set -g message-command-style "fg=$ONEDARK_WHITE,bg=$ONEDARK_BLACK"

setw -g window-status-style "fg=$ONEDARK_WHITE,bg=$ONEDARK_BLACK"
setw -g window-status-current-style "bg=$ONEDARK_GUTTER_GREY"

setw -g window-status-activity-style "fg=$ONEDARK_WHITE,bg=$ONEDARK_BLACK"

set -g window-style "fg=$ONEDARK_COMMENT_GREY"
set -g window-active-style "fg=$ONEDARK_WHITE"

setw -g window-status-format "#[fg=$ONEDARK_BLACK,bg=$ONEDARK_BLACK,nobold,nounderscore,noitalics]#[fg=$ONEDARK_WHITE,bg=$ONEDARK_BLACK]#I  #W#[fg=$ONEDARK_BLACK,bg=$ONEDARK_BLACK,nobold,nounderscore,noitalics]"
setw -g window-status-current-format "#[fg=$ONEDARK_BLACK,bg=$ONEDARK_GUTTER_GREY,nobold,nounderscore,noitalics]#[fg=$ONEDARK_BLUE,bg=$ONEDARK_GUTTER_GREY,nobold]#I  #W#[fg=$ONEDARK_GUTTER_GREY,bg=$ONEDARK_BLACK,nobold,nounderscore,noitalics]"

set -g pane-border-style "fg=$ONEDARK_WHITE,bg=$ONEDARK_BLACK"
set -g pane-active-border-style "fg=$ONEDARK_WHITE,bg=$ONEDARK_BLACK"
set -g display-panes-active-colour "$ONEDARK_LIGHTYELLOW"
set -g display-panes-colour "$ONEDARK_BLUE"

set -g status-style "fg=$ONEDARK_WHITE,bg=$ONEDARK_BLACK"
