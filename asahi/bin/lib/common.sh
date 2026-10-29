#!/usr/bin/env bash
# Helpers shared by the asahi-* scripts. Source, do not execute:
#
#   . "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/lib/common.sh"
#
# readlink -f so a script invoked through a symlink (e.g. the
# ~/.local/bin/asahi-battery-alertd link) still finds this file.

# Volume/brightness key step: 1 % at or below 5 %, else 5 %. Lowering from 6-9 lands on 5 first
# so the fine range is always reached (7 -> 5 -> 4). +1 / -1 (Shift) are 1 %. Clamped to $3 (default 0)..100.
step_percent() {
  local t
  case "$2" in
    raise) if [ "$1" -lt 5 ]; then t=$(($1 + 1)); else t=$(($1 + 5)); fi ;;
    lower) if [ "$1" -le 5 ]; then t=$(($1 - 1)); elif [ "$1" -lt 10 ]; then t=5; else t=$(($1 - 5)); fi ;;
    +1) t=$(($1 + 1)) ;;
    -1) t=$(($1 - 1)) ;;
    *) echo "unsupported step: $2" >&2; return 1 ;;
  esac
  if [ "$t" -lt "${3:-0}" ]; then t=${3:-0}; fi
  if [ "$t" -gt 100 ]; then t=100; fi
  echo "$t"
}

# Panel backlight. apple-panel-bl is the Asahi name; fall back to whatever
# /sys/class/backlight offers so the scripts still work on other hardware.
display_device() {
  local device=apple-panel-bl
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
  local device=kbd_backlight
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

# Ramp a backlight/LED from -> to in 10 writes ~25 ms apart (~0.3 s, macOS fades the keys).
# Smoothstep easing f(t) = 3t² - 2t³ with t = i/steps: slow start and end, no jump at low levels.
fade_brightness() {
  local device=$1 from=$2 to=$3 steps=10 i value last=$2
  for ((i = 1; i <= steps; i++)); do
    value=$((from + (to - from) * (3 * i * i * steps - 2 * i * i * i) / (steps * steps * steps)))
    if ((value == last)); then continue; fi
    brightnessctl --quiet --device="$device" set "$value" >/dev/null 2>&1 || return 0
    last=$value
    if ((i < steps)); then sleep 0.025; fi
  done
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

# logind's lid state (Apple SMC switch).
lid_closed() {
  busctl get-property org.freedesktop.login1 /org/freedesktop/login1 org.freedesktop.login1.Manager LidClosed 2>/dev/null \
    | grep -q true
}

# An enabled output besides eDP-1. FALLBACK is Hyprland's placeholder once no real output is left
# (USB-C unplug in clamshell): counting it kept eDP off and the closed lid awake.
external_on() {
  hyprctl monitors -j 2>/dev/null | jq -e 'any(.[]; .name != "eDP-1" and .name != "FALLBACK" and .disabled != true)' >/dev/null
}

# asahi-idle-brightness's lock: idle dim/off/restore, the brightness keys and keyboard auto never interleave.
brightness_lock() { printf '%s\n' "${XDG_RUNTIME_DIR:-/tmp}/asahi-idle-brightness.lock"; }

# First line of file $2 into the variable named $1, trimmed, without a fork; empty when unreadable.
read_line() {
  local _line=""
  if [ -r "$2" ]; then { read -r _line <"$2"; } 2>/dev/null || true; fi
  printf -v "$1" '%s' "$_line"
}

# A hwmon *_input's label into the variable named $1: its *_label file, else the stem (temp4_input -> temp4).
sensor_label() {
  local _stem=${2##*/}
  read_line "$1" "${2%_input}_label"
  if [ -z "${!1}" ]; then printf -v "$1" '%s' "${_stem%_input}"; fi
}

# A Mains supply online (charger in).
on_ac() {
  local p type online
  for p in "${ASAHI_PSY_DIR:-/sys/class/power_supply}"/*; do
    read_line type "$p/type"
    read_line online "$p/online"
    if [ "$type" = Mains ] && [ "$online" = 1 ]; then return 0; fi
  done
  return 1
}

# This session's hyprlock. A nested-preview hyprlock runs on another WAYLAND_DISPLAY and must not
# count: asahi-lock skipped the real lock and asahi-idle suspended unlocked while one ran.
hyprlock_running() {
  pgrep -u "$UID" -x --env "WAYLAND_DISPLAY=${WAYLAND_DISPLAY:-wayland-1}" hyprlock >/dev/null
}

# Pid in pid file $1 while that process lives, else nothing (and a stale file is removed).
live_pid() {
  local pid=""
  if [ -r "$1" ]; then read -r pid <"$1" || true; fi
  if [[ $pid =~ ^[0-9]+$ ]] && kill -0 "$pid" 2>/dev/null; then
    echo "$pid"
  else
    rm -f "$1"
  fi
}

# Signal $2 to pid $1, wait up to $3 tenths of a second for it to exit, then SIGKILL.
stop_pid() {
  local i
  kill -"$2" "$1" 2>/dev/null || true
  for ((i = 0; i < $3; i++)); do
    kill -0 "$1" 2>/dev/null || return 0
    sleep 0.1
  done
  kill -KILL "$1" 2>/dev/null || true
}

# Leave fullscreen / maximized ($1: `hyprctl activewindow -j`) before floating or resizing a window.
# JSON fullscreen is 1 maximized, 2 fullscreen; the dispatcher wants the names.
unset_fullscreen() {
  local mode
  case "$(jq -r '.fullscreen // 0' <<<"$1")" in
    0 | null) return 0 ;;
    1) mode=maximized ;;
    *) mode=fullscreen ;;
  esac
  hyprctl dispatch "hl.dsp.window.fullscreen({ mode = \"$mode\", action = \"unset\" })" >/dev/null
}

# Focus the first Hyprland client matching jq condition $1 (more args go to jq, e.g. --arg); fails when none does.
focus_client() {
  local address
  address=$(hyprctl clients -j 2>/dev/null | jq -r "${@:2}" "first(.[] | select($1)) | .address // empty" 2>/dev/null || true)
  [ -n "$address" ] || return 1
  hyprctl dispatch "hl.dsp.focus({ window = \"address:$address\" })" >/dev/null
}

# Decode a screen region (asahi-cmd-ocr / -qr): asahi-capture-region, then grim at scale $1 (empty: grim's
# default) piped into the decoder "${@:2}". Sets $decoded; a cancelled pick exits the caller.
# timeout: grim blocks on a DPMS-off output.
decode_region() {
  local selection grim_args=()
  selection="$("$(dirname "${BASH_SOURCE[0]}")/../asahi-capture-region" region || true)"
  [ -n "$selection" ] || exit 0
  if [ -n "$1" ]; then grim_args=(-s "$1"); fi
  # shellcheck disable=SC2034  # read by the caller
  decoded="$(timeout 5 grim "${grim_args[@]}" -g "$selection" - | "${@:2}" 2>/dev/null || true)"
}
