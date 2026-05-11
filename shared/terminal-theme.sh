#!/usr/bin/env sh
# Shared terminal palette for shell tooling on all platforms.

catppuccin_term_mode="light"
catppuccin_term_os="$(uname -s 2>/dev/null || printf '%s' "")"

if [ "$catppuccin_term_os" = "Darwin" ] && command -v defaults >/dev/null 2>&1; then
  if defaults read -g AppleInterfaceStyle 2>/dev/null | grep -qi dark; then
    catppuccin_term_mode="dark"
  fi
elif [ "$catppuccin_term_os" = "Linux" ] && command -v gsettings >/dev/null 2>&1; then
  if gsettings get org.gnome.desktop.interface color-scheme 2>/dev/null | grep -q "prefer-dark"; then
    catppuccin_term_mode="dark"
  elif gsettings get org.gnome.desktop.interface gtk-theme 2>/dev/null | grep -qi dark; then
    catppuccin_term_mode="dark"
  fi
fi

export CATPPUCCIN_TERM_MODE="$catppuccin_term_mode"

if [ "$catppuccin_term_mode" = "dark" ]; then
  export CATPPUCCIN_TERM_BACKGROUND="#1e1e2e"
  export CATPPUCCIN_TERM_FOREGROUND="#cdd6f4"
  export CATPPUCCIN_TERM_SELECTION_BG="#45475a"
  export CATPPUCCIN_TERM_CURSOR="#89b4fa"

  export CATPPUCCIN_TERM_BLACK="#45475a"
  export CATPPUCCIN_TERM_RED="#f38ba8"
  export CATPPUCCIN_TERM_GREEN="#a6e3a1"
  export CATPPUCCIN_TERM_YELLOW="#f9e2af"
  export CATPPUCCIN_TERM_BLUE="#89b4fa"
  export CATPPUCCIN_TERM_MAGENTA="#f5c2e7"
  export CATPPUCCIN_TERM_CYAN="#94e2d5"
  export CATPPUCCIN_TERM_WHITE="#bac2de"

  export CATPPUCCIN_TERM_BRIGHT_BLACK="#585b70"
  export CATPPUCCIN_TERM_BRIGHT_RED="#f38ba8"
  export CATPPUCCIN_TERM_BRIGHT_GREEN="#a6e3a1"
  export CATPPUCCIN_TERM_BRIGHT_YELLOW="#f9e2af"
  export CATPPUCCIN_TERM_BRIGHT_BLUE="#89b4fa"
  export CATPPUCCIN_TERM_BRIGHT_MAGENTA="#f5c2e7"
  export CATPPUCCIN_TERM_BRIGHT_CYAN="#94e2d5"
  export CATPPUCCIN_TERM_BRIGHT_WHITE="#cdd6f4"
else
  export CATPPUCCIN_TERM_BACKGROUND="#eff1f5"
  export CATPPUCCIN_TERM_FOREGROUND="#4c4f69"
  export CATPPUCCIN_TERM_SELECTION_BG="#bcc0cc"
  export CATPPUCCIN_TERM_CURSOR="#1e66f5"

  export CATPPUCCIN_TERM_BLACK="#5c5f77"
  export CATPPUCCIN_TERM_RED="#d20f39"
  export CATPPUCCIN_TERM_GREEN="#40a02b"
  export CATPPUCCIN_TERM_YELLOW="#df8e1d"
  export CATPPUCCIN_TERM_BLUE="#1e66f5"
  export CATPPUCCIN_TERM_MAGENTA="#ea76cb"
  export CATPPUCCIN_TERM_CYAN="#179299"
  export CATPPUCCIN_TERM_WHITE="#acb0be"

  export CATPPUCCIN_TERM_BRIGHT_BLACK="#7c7f93"
  export CATPPUCCIN_TERM_BRIGHT_RED="#d20f39"
  export CATPPUCCIN_TERM_BRIGHT_GREEN="#40a02b"
  export CATPPUCCIN_TERM_BRIGHT_YELLOW="#df8e1d"
  export CATPPUCCIN_TERM_BRIGHT_BLUE="#1e66f5"
  export CATPPUCCIN_TERM_BRIGHT_MAGENTA="#ea76cb"
  export CATPPUCCIN_TERM_BRIGHT_CYAN="#179299"
  export CATPPUCCIN_TERM_BRIGHT_WHITE="#bcc0cc"
fi

unset catppuccin_term_mode
unset catppuccin_term_os
