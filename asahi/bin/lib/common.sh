#!/usr/bin/env bash
# Helpers shared by the asahi-* scripts. Source, do not execute:
#
#   . "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/lib/common.sh"
#
# readlink -f so a script invoked through a symlink (e.g. the
# ~/.local/bin/asahi-battery-alertd link) still finds this file.

# Panel backlight. apple-panel-bl is the Asahi name; fall back to whatever
# /sys/class/backlight offers so the scripts still work on other hardware.
display_device() {
  local device="${ASAHI_BACKLIGHT_DEVICE:-apple-panel-bl}"
  local path

  if brightnessctl --device="$device" info >/dev/null 2>&1; then
    printf "%s\n" "$device"
    return 0
  fi

  for path in /sys/class/backlight/*; do
    [ -e "$path" ] || continue
    basename "$path"
    return 0
  done

  return 1
}

keyboard_device() {
  local device="${ASAHI_KEYBOARD_BACKLIGHT_DEVICE:-kbd_backlight}"
  local path

  if brightnessctl --device="$device" info >/dev/null 2>&1; then
    printf "%s\n" "$device"
    return 0
  fi

  for path in /sys/class/leds/*kbd_backlight*; do
    [ -e "$path" ] || continue
    basename "$path"
    return 0
  done

  return 1
}

# Empty when Hyprland is not reachable. Must never return non-zero: callers do
# `mon="$(focused_monitor)"` under `set -euo pipefail`, where a failing pipeline
# aborts the script before their own `[ -n "$mon" ]` guard can report it.
focused_monitor() {
  hyprctl monitors -j 2>/dev/null \
    | jq -r '.[] | select(.focused == true).name // empty' 2>/dev/null \
    || true
}
