#!/usr/bin/env bash
# Smoke tests for asahi-debug. No live hardware writes.

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
fail=0
pass() { printf 'ok  %s\n' "$1"; }
fail_at() { printf 'FAIL %s\n' "$1"; fail=1; }

tmp=$(mktemp -d)
cleanup() { rm -rf "$tmp" || true; }
trap cleanup EXIT

chmod +x "$ROOT/asahi-debug"

"$ROOT/asahi-debug" --nope 2>/dev/null && fail_at "bad flag should fail" || pass "usage"

# Non-Apple /proc must refuse before any Fedora/Hyprland checks.
mkdir -p "$tmp/empty-proc"
if ASAHI_PROC_ROOT="$tmp/empty-proc" "$ROOT/asahi-debug" >/dev/null 2>&1; then
  fail_at "empty proc should exit 2"
else
  pass "refuses without Apple device-tree"
fi

# A mocked Apple tree plus command stubs — Fedora checks, not pacman/iwd/SDDM.
diag="$tmp/root"
proc="$tmp/proc"
sys="$tmp/sys"
bin="$tmp/bin"
mkdir -p "$diag/etc/NetworkManager/conf.d" \
  "$diag/etc/systemd/sleep.conf.d" \
  "$diag/etc/systemd/logind.conf.d" \
  "$diag/etc/udev/rules.d" \
  "$diag/etc/systemd/system" \
  "$diag/dev/dri" \
  "$diag/usr/share/vulkan/icd.d" \
  "$diag/sys/class/backlight/apple-panel-bl" \
  "$diag/sys/class/power_supply/macsmc-battery" \
  "$diag/sys/bus/hid/drivers/apple" \
  "$proc/device-tree" \
  "$sys/module/hid_apple/parameters" \
  "$sys/module/appledrm/parameters" \
  "$bin"

printf 'apple,j314s\0' >"$proc/device-tree/compatible"
printf 'Apple MacBook Pro (14-inch, M1 Pro, 2021)\0' >"$proc/device-tree/model"
cat >"$diag/etc/os-release" <<'EOF'
NAME="Fedora Linux"
PRETTY_NAME="Fedora Asahi Remix 44 (Forty Four)"
VARIANT="Asahi Remix"
EOF
printf 'wifi.powersave = 2\n' >"$diag/etc/NetworkManager/conf.d/asahi-wifi-powersave.conf"
printf '[Sleep]\nAllowHibernation=no\n' >"$diag/etc/systemd/sleep.conf.d/10-asahi-no-hibernate.conf"
printf '[Login]\nHandlePowerKey=ignore\n' >"$diag/etc/systemd/logind.conf.d/10-asahi-sleep.conf"
: >"$diag/etc/udev/rules.d/99-asahi-charge-limit.rules"
: >"$diag/etc/systemd/system/asahi-charge-limit.service"
: >"$diag/dev/dri/card0"
: >"$diag/dev/dri/renderD128"
: >"$diag/dev/video0"
: >"$diag/usr/share/vulkan/icd.d/asahi_icd.aarch64.json"
printf '80\n' >"$diag/sys/class/backlight/apple-panel-bl/brightness"
printf '255\n' >"$diag/sys/class/backlight/apple-panel-bl/max_brightness"
printf '80\n' >"$diag/sys/class/power_supply/macsmc-battery/capacity"
printf 'Charging\n' >"$diag/sys/class/power_supply/macsmc-battery/status"
printf '1\n' >"$sys/module/hid_apple/parameters/fnmode"
printf 'Y\n' >"$sys/module/appledrm/parameters/show_notch"

# Stubs are #!/bin/sh: a bash shebang + PATH uname mock recurses through Lmod.
cat >"$bin/rpm" <<'EOF'
#!/bin/sh
pkg=$1
[ "$pkg" = "-q" ] && pkg=$2
case "${pkg:-}" in
  kernel-16k) echo "kernel-16k-7.1.6-400.asahi.fc44.aarch64" ;;
  speakersafetyd) echo "speakersafetyd-2.0.1-1.fc44.aarch64" ;;
  asahi-audio) echo "asahi-audio-4.1-1.fc44.noarch" ;;
  pipewire) echo "pipewire-1.4.0-1.fc44.aarch64" ;;
  wireplumber) echo "wireplumber-0.5.8-1.fc44.aarch64" ;;
  NetworkManager) echo "NetworkManager-1.52.0-1.fc44.aarch64" ;;
  mesa-vulkan-drivers) echo "mesa-vulkan-drivers-26.1.8-1.fc44.aarch64" ;;
  *) exit 1 ;;
esac
EOF
cat >"$bin/NetworkManager" <<'EOF'
#!/bin/sh
[ "$1" = --print-config ] && echo "wifi.backend=wpa_supplicant"
EOF
cat >"$bin/nmcli" <<'EOF'
#!/bin/sh
echo "wlan0:wifi:connected"
EOF
cat >"$bin/wpctl" <<'EOF'
#!/bin/sh
printf '%s\n' "Filters:" " │  42. audio_effect.sink [Audio/Sink]" "Streams:"
EOF
cat >"$bin/systemctl" <<'EOF'
#!/bin/sh
if [ "$1" = is-active ] && [ "$2" = --quiet ] && [ "$3" = speakersafetyd ]; then exit 0; fi
if [ "$1" = is-active ] && [ "$2" = --quiet ] && [ "$3" = bluetooth ]; then exit 0; fi
if [ "$1" = is-enabled ] && [ "$2" = sshd.service ]; then echo masked; exit 0; fi
exit 1
EOF
cat >"$bin/modinfo" <<'EOF'
#!/bin/sh
[ "$2" = hid_magicmouse ] && echo "(builtin)"
EOF
cat >"$bin/ps" <<'EOF'
#!/bin/sh
printf '%s\n' "data-loop.0         20  RR"
EOF
chmod +x "$bin"/*

out=$(PATH="$bin:$PATH" ASAHI_DIAG_ROOT="$diag" ASAHI_PROC_ROOT="$proc" \
  ASAHI_SYS_ROOT="$sys" "$ROOT/asahi-debug" --json) || true

echo "$out" | jq -e '.failed == 0' >/dev/null || fail_at "json failed==0 (got $out)"
echo "$out" | jq -e '[.checks[] | select(.id=="fedora-asahi" and .status=="PASS")] | length == 1' >/dev/null \
  || fail_at "fedora-asahi PASS"
echo "$out" | jq -e '[.checks[] | select(.id=="wifi-backend" and .status=="PASS")] | length == 1' >/dev/null \
  || fail_at "wifi-backend expects wpa_supplicant"
echo "$out" | jq -e '[.checks[] | select(.id=="sshd" and .status=="PASS")] | length == 1' >/dev/null \
  || fail_at "sshd masked is PASS"
echo "$out" | jq -e '[.checks[] | select(.id=="getty-autologin" and .status=="PASS")] | length == 1' >/dev/null \
  || fail_at "getty-autologin PASS when drop-in is absent"
echo "$out" | jq -e '.checks | any(.id | test("pacman|iwd|sddm|omarchy-version"))' >/dev/null \
  && fail_at "must not emit Arch/omarchy checks" || pass "no pacman/iwd/sddm/omarchy checks"
echo "$out" | jq -e '[.checks[] | select(.id=="audio-dsp" and .status=="PASS")] | length == 1' >/dev/null \
  || fail_at "audio-dsp PASS on asahi-audio filter"
pass "mocked Fedora Asahi tree is all PASS"

# iwd is a warning, not the required backend.
cat >"$bin/NetworkManager" <<'EOF'
#!/bin/sh
[ "$1" = --print-config ] && echo "wifi.backend=iwd"
EOF
chmod +x "$bin/NetworkManager"
out=$(PATH="$bin:$PATH" ASAHI_DIAG_ROOT="$diag" ASAHI_PROC_ROOT="$proc" \
  ASAHI_SYS_ROOT="$sys" "$ROOT/asahi-debug" --json) || true
echo "$out" | jq -e '[.checks[] | select(.id=="wifi-backend" and .status=="WARN")] | length == 1' >/dev/null \
  || fail_at "iwd backend should WARN on Fedora"
pass "iwd wifi backend is WARN, not FAIL"

mkdir -p "$diag/etc/systemd/system/getty@tty1.service.d"
printf '%s\n' 'ExecStart=-/usr/sbin/agetty --autologin nobody' \
  >"$diag/etc/systemd/system/getty@tty1.service.d/10-asahi-autologin.conf"
out=$(PATH="$bin:$PATH" ASAHI_DIAG_ROOT="$diag" ASAHI_PROC_ROOT="$proc" \
  ASAHI_SYS_ROOT="$sys" "$ROOT/asahi-debug" --json) || true
echo "$out" | jq -e '[.checks[] | select(.id=="getty-autologin" and .status=="FAIL")] | length == 1' >/dev/null \
  || fail_at "getty-autologin FAIL when leftover drop-in exists"
pass "leftover tty1 autologin is FAIL"
rm -f "$diag/etc/systemd/system/getty@tty1.service.d/10-asahi-autologin.conf"

if grep -Eiq '[[:space:]]pacman([[:space:]]|$)|systemctl[^[:space:]]* sddm' "$ROOT/asahi-debug"; then
  fail_at "asahi-debug still calls pacman or sddm"
else
  pass "asahi-debug does not call pacman or sddm"
fi

if [ "$fail" -ne 0 ]; then
  echo "asahi_debug_test.sh: FAILED"
  exit 1
fi
echo "asahi_debug_test.sh: all ok"
