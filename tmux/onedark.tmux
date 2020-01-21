# https://github.com/odedlaz/tmux-onedark-theme/blob/master/tmux-onedark-theme.tmux

onedark_black="#282c34"
onedark_blue="#61afef"
onedark_yellow="#e5c07b"
onedark_red="#e06c75"
onedark_white="#aab2bf"
onedark_green="#98c379"
onedark_visual_grey="#3e4452"
onedark_comment_grey="#5c6370"

set -g message-style "fg=$onedark_white,bg=$onedark_black"
set -g message-command-style "fg=$onedark_white,bg=$onedark_black"

setw -g window-status-style "fg=$onedark_white,bg=$onedark_black"
setw -g window-status-current-style "bg=$onedark_visual_grey"
setw -g window-status-attr "none"

setw -g window-status-activity-style "fg=$onedark_white,bg=$onedark_black"
setw -g window-status-activity-attr "none"

set -g window-style "fg=$onedark_comment_grey"
set -g window-active-style "fg=$onedark_white"


set window-status-format "#[fg=$onedark_black,bg=$onedark_black,nobold,nounderscore,noitalics]#[fg=$onedark_white,bg=$onedark_black]#I  #W#[fg=$onedark_black,bg=$onedark_black,nobold,nounderscore,noitalics]"
setw -g window-status-current-format "#[fg=$onedark_black,bg=$onedark_visual_grey,nobold,nounderscore,noitalics]#[fg=$onedark_white,bg=$onedark_visual_grey,nobold]#I  #W#[fg=$onedark_visual_grey,bg=$onedark_black,nobold,nounderscore,noitalics]"

set -g pane-border-style "fg=$onedark_white,bg=$onedark_black"
set -g pane-active-border-style "fg=$onedark_white,bg=$onedark_black"
set -g display-panes-active-colour "$onedark_yellow"
set -g display-panes-colour "$onedark_blue"

set -g status-style "fg=$onedark_white,bg=$onedark_black"

set -g status-attr "none"
set -g status-left-attr "none"
