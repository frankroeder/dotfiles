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

# Session-scoped scale override per output, written by asahi-monitor-scale.
# Empty when none. Consulted by everything that re-enables an output, so a
# hyprctl reload / lid open / HDMI sync does not fall back to monitors.lua.
saved_scale() {
  local f="${ASAHI_SCALE_DIR:-${XDG_RUNTIME_DIR:-/tmp}/asahi-monitor-scale}/$1"
  [ -s "$f" ] && tr -d '[:space:]' <"$f" || true
}

# Offset that lands an output's far edge on the origin: logical extent (pixels
# / scale), negated. Outputs left of / above eDP-1 are anchored by that edge,
# so a pinned x/y overlaps the panel as soon as the scale changes ("Your
# monitor layout is set up incorrectly ... overlaps with other monitor(s)").
anchor_offset() {
  awk -v n="$1" -v s="$2" 'BEGIN { printf "%d", -n / s }'
}
