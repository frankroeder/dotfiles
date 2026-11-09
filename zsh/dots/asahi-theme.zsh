# Asahi autotheme palette (CATPPUCCIN_TERM_*): prompt/fzf read it below.
# No-op off-Asahi: the file only exists where asahi-autotheme runs.
_asahi_theme_colors="${XDG_STATE_HOME:-$HOME/.local/state}/asahi-theme/colors.env"
[[ -r "$_asahi_theme_colors" ]] && source "$_asahi_theme_colors"
unset _asahi_theme_colors
