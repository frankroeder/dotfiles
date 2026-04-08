#!/usr/bin/env sh
# Shared terminal palette for shell tooling on all platforms.

dank_term_mode="light"
dank_term_os="$(uname -s 2>/dev/null || printf '%s' "")"

if [ "$dank_term_os" = "Darwin" ] && command -v defaults >/dev/null 2>&1; then
  if defaults read -g AppleInterfaceStyle 2>/dev/null | grep -qi dark; then
    dank_term_mode="dark"
  fi
elif [ "$dank_term_os" = "Linux" ] && command -v gsettings >/dev/null 2>&1; then
  if gsettings get org.gnome.desktop.interface color-scheme 2>/dev/null | grep -q "prefer-dark"; then
    dank_term_mode="dark"
  elif gsettings get org.gnome.desktop.interface gtk-theme 2>/dev/null | grep -qi dark; then
    dank_term_mode="dark"
  fi
fi

export DANK_TERM_MODE="$dank_term_mode"

if [ "$dank_term_mode" = "dark" ]; then
  export DANK_TERM_BACKGROUND="#1e1e2e"
  export DANK_TERM_FOREGROUND="#cdd6f4"
  export DANK_TERM_SELECTION_BG="#45475a"
  export DANK_TERM_CURSOR="#89b4fa"

  export DANK_TERM_BLACK="#45475a"
  export DANK_TERM_RED="#f38ba8"
  export DANK_TERM_GREEN="#a6e3a1"
  export DANK_TERM_YELLOW="#f9e2af"
  export DANK_TERM_BLUE="#89b4fa"
  export DANK_TERM_MAGENTA="#f5c2e7"
  export DANK_TERM_CYAN="#94e2d5"
  export DANK_TERM_WHITE="#bac2de"

  export DANK_TERM_BRIGHT_BLACK="#585b70"
  export DANK_TERM_BRIGHT_RED="#f38ba8"
  export DANK_TERM_BRIGHT_GREEN="#a6e3a1"
  export DANK_TERM_BRIGHT_YELLOW="#f9e2af"
  export DANK_TERM_BRIGHT_BLUE="#89b4fa"
  export DANK_TERM_BRIGHT_MAGENTA="#f5c2e7"
  export DANK_TERM_BRIGHT_CYAN="#94e2d5"
  export DANK_TERM_BRIGHT_WHITE="#cdd6f4"
else
  export DANK_TERM_BACKGROUND="#eff1f5"
  export DANK_TERM_FOREGROUND="#4c4f69"
  export DANK_TERM_SELECTION_BG="#bcc0cc"
  export DANK_TERM_CURSOR="#1e66f5"

  export DANK_TERM_BLACK="#5c5f77"
  export DANK_TERM_RED="#d20f39"
  export DANK_TERM_GREEN="#40a02b"
  export DANK_TERM_YELLOW="#df8e1d"
  export DANK_TERM_BLUE="#1e66f5"
  export DANK_TERM_MAGENTA="#ea76cb"
  export DANK_TERM_CYAN="#179299"
  export DANK_TERM_WHITE="#acb0be"

  export DANK_TERM_BRIGHT_BLACK="#7c7f93"
  export DANK_TERM_BRIGHT_RED="#d20f39"
  export DANK_TERM_BRIGHT_GREEN="#40a02b"
  export DANK_TERM_BRIGHT_YELLOW="#df8e1d"
  export DANK_TERM_BRIGHT_BLUE="#1e66f5"
  export DANK_TERM_BRIGHT_MAGENTA="#ea76cb"
  export DANK_TERM_BRIGHT_CYAN="#179299"
  export DANK_TERM_BRIGHT_WHITE="#bcc0cc"
fi

unset dank_term_mode
unset dank_term_os
