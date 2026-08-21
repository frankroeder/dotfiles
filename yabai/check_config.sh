#!/usr/bin/env bash
# Structural checks for yabai + related bar wiring (drives real shipped files).
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
fail=0

ok() { printf 'ok  %s\n' "$1"; }
bad() { printf 'FAIL %s\n' "$1"; fail=1; }

# --- window_rules: every signal --add must carry label= ---
rules="$ROOT/yabai/window_rules"
if [[ ! -f $rules ]]; then
  bad "missing $rules"
else
  # shellcheck disable=SC2016
  while IFS= read -r line; do
    # strip leading whitespace; skip comments
    trimmed="${line#"${line%%[![:space:]]*}"}"
    [[ $trimmed == \#* ]] && continue
    [[ $trimmed =~ signal[[:space:]]+--add ]] || continue
    if [[ $trimmed =~ label= ]]; then
      ok "labelled signal: ${trimmed:0:80}"
    else
      bad "unlabelled signal --add: $trimmed"
    fi
  done < <(grep -E 'signal[[:space:]]+--add' "$rules" || true)

  if grep -qE "space --focus next" "$rules"; then
    bad "Ghostty/Finder space thrash still present in window_rules"
  else
    ok "no space thrash workaround in window_rules"
  fi

  if grep -q 'label=float_non_resizable' "$rules"; then
    ok "float_non_resizable labelled"
  else
    bad "float_non_resizable label missing"
  fi

  if grep -q 'label=native_tab_created' "$rules" && grep -q 'label=native_tab_destroyed' "$rules"; then
    ok "native_tab signals labelled"
  else
    bad "native_tab create/destroy signals missing"
  fi
fi

tab_helper="$ROOT/yabai/native_tab.sh"
if [[ -x $tab_helper ]]; then
  ok "native_tab.sh executable"
else
  bad "native_tab.sh missing or not executable"
fi

# --- yabairc: anim/opacity smooth defaults ---
rc="$ROOT/yabai/yabairc"
if [[ ! -f $rc ]]; then
  bad "missing $rc"
else
  if grep -qE 'window_animation_duration[[:space:]]+0(\.0)?' "$rc"; then
    ok "window_animation_duration 0"
  else
    bad "window_animation_duration not zeroed"
  fi
  if grep -qE 'window_opacity[[:space:]]+off' "$rc"; then
    ok "window_opacity off"
  else
    bad "window_opacity not off"
  fi
  # active (non-comment) signal --add lines must carry label=
  while IFS= read -r line; do
    trimmed="${line#"${line%%[![:space:]]*}"}"
    [[ $trimmed == \#* ]] && continue
    [[ $trimmed =~ signal[[:space:]]+--add ]] || continue
    if [[ $trimmed =~ label= ]]; then
      :
    else
      bad "yabairc unlabelled: $trimmed"
    fi
  done < <(grep -E 'signal[[:space:]]+--add' "$rc" || true)
  ok "yabairc active signal --add lines labelled"
fi

# --- yabai_spaces: window_moved must not call updateLayout ---
spaces="$ROOT/sketchybar/top/items/yabai_spaces.lua"
if [[ ! -f $spaces ]]; then
  bad "missing $spaces"
else
  if grep -nE 'subscribe\("window_moved",\s*updateLayout\)' "$spaces"; then
    bad "window_moved still wired to updateLayout"
  else
    ok "window_moved not full updateLayout"
  fi
  if grep -q 'subscribe("window_moved"' "$spaces"; then
    ok "window_moved still subscribed (membership/pill path)"
  else
    bad "window_moved subscription missing entirely"
  fi
fi
if grep -q 'BOTTOM_RESERVE' "$ROOT/yabai/yabairc" && grep -q 'bar_y_offset' "$ROOT/yabai/yabairc"; then
  ok "external_bar bottom includes bar_y_offset"
else
  bad "external_bar bottom missing bar_y_offset pad"
fi
if grep -q 'expand_height' "$ROOT/yabai/yabairc"; then
  ok "external_bar top includes island expand_height"
else
  bad "external_bar top missing island expand_height"
fi

# --- arrange-displays: no hard-coded /opt/homebrew ---
arr="$ROOT/yabai/arrange-displays.sh"
if [[ ! -f $arr ]]; then
  bad "missing $arr"
else
  if grep -q '/opt/homebrew' "$arr"; then
    bad "arrange-displays hard-codes /opt/homebrew"
  else
    ok "arrange-displays uses command -v paths"
  fi
fi

if [[ $fail -ne 0 ]]; then
  printf '\n%d check(s) failed\n' "$fail"
  exit 1
fi
printf '\nall checks passed\n'
