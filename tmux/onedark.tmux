# https://github.com/odedlaz/tmux-onedark-theme/blob/master/tmux-onedark-theme.tmux

ONEDARK_BLACK="#282c34"
ONEDARK_BLUE="#61afef"
ONEDARK_YELLOW="#e5c07b"
ONEDARK_RED="#e06c75"
ONEDARK_WHITE="#aab2bf"
ONEDARK_GREEN="#98c379"
ONEDARK_VISUAL_GREY="#3e4452"
ONEDARK_COMMENT_GREY="#5c6370"

set -g message-style "fg=$ONEDARK_WHITE,bg=$ONEDARK_BLACK"
set -g message-command-style "fg=$ONEDARK_WHITE,bg=$ONEDARK_BLACK"

setw -g window-status-style "fg=$ONEDARK_WHITE,bg=$ONEDARK_BLACK"
setw -g window-status-current-style "bg=$ONEDARK_VISUAL_GREY"

setw -g window-status-activity-style "fg=$ONEDARK_WHITE,bg=$ONEDARK_BLACK"

set -g window-style "fg=$ONEDARK_COMMENT_GREY"
set -g window-active-style "fg=$ONEDARK_WHITE"


setw -g window-status-format "#[fg=$ONEDARK_BLACK,bg=$ONEDARK_BLACK,nobold,nounderscore,noitalics]#[fg=$ONEDARK_WHITE,bg=$ONEDARK_BLACK]#I  #W#[fg=$ONEDARK_BLACK,bg=$ONEDARK_BLACK,nobold,nounderscore,noitalics]"
setw -g window-status-current-format "#[fg=$ONEDARK_BLACK,bg=$ONEDARK_VISUAL_GREY,nobold,nounderscore,noitalics]#[fg=$ONEDARK_WHITE,bg=$ONEDARK_VISUAL_GREY,nobold]#I  #W#[fg=$ONEDARK_VISUAL_GREY,bg=$ONEDARK_BLACK,nobold,nounderscore,noitalics]"

set -g pane-border-style "fg=$ONEDARK_WHITE,bg=$ONEDARK_BLACK"
set -g pane-active-border-style "fg=$ONEDARK_WHITE,bg=$ONEDARK_BLACK"
set -g display-panes-active-colour "$ONEDARK_YELLOW"
set -g display-panes-colour "$ONEDARK_BLUE"

set -g status-style "fg=$ONEDARK_WHITE,bg=$ONEDARK_BLACK"
