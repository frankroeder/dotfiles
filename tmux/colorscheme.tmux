# Catppuccin (Mocha)
thm_bg="#1e1e2e"
thm_fg="#cdd6f4"
thm_cyan="#89dceb"
thm_black="#181825"
thm_gray="#313244"
thm_magenta="#cba6f7"
thm_pink="#f5c2e7"
thm_red="#f38ba8"
thm_green="#a6e3a1"
thm_yellow="#f9e2af"
thm_blue="#89b4fa"
thm_orange="#fab387"
thm_black4="#585b70"

# ----------------------------=== Theme ===--------------------------

# status
set -g status-position top
set -g status "on"
set -g status-bg "${thm_bg}"
set -g status-justify "left"

# messages
set -g message-style fg="${thm_cyan}",bg="${thm_gray}",align="centre"
set -g message-command-style fg="${thm_cyan}",bg="${thm_gray}",align="centre"

# panes
set -g pane-border-style fg="${thm_gray}"
set -g pane-active-border-style fg="${thm_blue}"

# windows
setw -g window-status-activity-style fg="${thm_fg}",bg="${thm_bg}",none
setw -g window-status-separator ""
setw -g window-status-style fg="${thm_fg}",bg="${thm_bg}",none

# current_dir
setw -g window-status-format "#[fg=$thm_bg,bg=$thm_blue] #I #[fg=$thm_fg,bg=$thm_gray] #W #[default]"
setw -g window-status-current-format "#[fg=$thm_bg,bg=$thm_orange] #I #[fg=$thm_fg,bg=$thm_bg] #W #[default]"

# --------=== Modes
setw -g clock-mode-colour "${thm_blue}"
setw -g mode-style "fg=${thm_pink} bg=${thm_black4} bold"

# vim: set filetype=tmux:
