# https://github.com/odedlaz/tmux-onedark-theme/blob/master/tmux-onedark-theme.tmux

onedark_black="#282c34"
onedark_blue="#61afef"
onedark_yellow="#e5c07b"
onedark_red="#e06c75"
onedark_white="#aab2bf"
onedark_green="#98c379"
onedark_visual_grey="#3e4452"
onedark_comment_grey="#5c6370"

set-option -g message-style "fg=$onedark_white"
set-option -g message-style "bg=$onedark_black"
set-option -g message-command-style "fg=$onedark_white"
set-option -g message-command-style "bg=$onedark_black"

setw -g window-status-style "fg=$onedark_black"
setw -g window-status-style "bg=$onedark_black"
setw -g window-status-current-style "none"

setw -g window-status-activity-style "bg=$onedark_black"
setw -g window-status-activity-style "fg=$onedark_black"

set -g window-style "fg=$onedark_comment_grey"
set -g window-active-style "fg=$onedark_white"

set -g pane-border-style "fg=$onedark_white"
set -g pane-border-style "bg=$onedark_black"
set -g pane-active-border-style "fg=$onedark_green"
set -g pane-active-border-style "bg=$onedark_black"

set -g display-panes-active-colour "$onedark_yellow"
set -g display-panes-colour "$onedark_blue"

set -g status-fg "$onedark_white"
set -g status-bg "$onedark_black"
set -g status-style none
