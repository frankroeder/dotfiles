# Nord
# set -g status-bg black
# set -g status-fg white
# set -g status-style none
# set -g pane-border-style bg=black
# set -g pane-border-style fg=black
# set -g pane-active-border-style bg=black
# set -g pane-active-border-style fg=brightblack
# set -g display-panes-colour black
# set -g display-panes-active-colour brightblack
# setw -g clock-mode-colour cyan
# set -g message-style fg=cyan
# set -g message-style bg=brightblack
# set -g message-command-style fg=cyan
# set -g message-command-style bg=brightblack

# https://github.com/odedlaz/tmux-onedark-theme/blob/master/tmux-onedark-theme.tmux

onedark_black="#282c34"
onedark_blue="#61afef"
onedark_yellow="#e5c07b"
onedark_red="#e06c75"
onedark_white="#aab2bf"
onedark_green="#98c379"
onedark_visual_grey="#3e4452"
onedark_comment_grey="#5c6370"

set-option "message-fg" "$onedark_white"
set-option "message-bg" "$onedark_black"
set-option "message-command-fg" "$onedark_white"
set-option "message-command-bg" "$onedark_black"

setw "window-status-fg" "$onedark_black"
setw "window-status-bg" "$onedark_black"
setw "window-status-attr" "none"

setw "window-status-activity-bg" "$onedark_black"
setw "window-status-activity-fg" "$onedark_black"
setw "window-status-activity-attr" "none"

set "window-style" "fg=$onedark_comment_grey"
set "window-active-style" "fg=$onedark_white"

set "pane-border-fg" "$onedark_white"
set "pane-border-bg" "$onedark_black"
set "pane-active-border-fg" "$onedark_green"
set "pane-active-border-bg" "$onedark_black"

set "display-panes-active-colour" "$onedark_yellow"
set "display-panes-colour" "$onedark_blue"

set "status-bg" "$onedark_black"
set "status-fg" "$onedark_white"
