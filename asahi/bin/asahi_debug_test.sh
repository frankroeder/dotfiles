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

# Pin the kernel name; the live one may be Aurora's.
export ASAHI_UNAME_R=7.1.13-402.asahi.fc44.aarch64+16k

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
printf '[Login]\nLidSwitchIgnoreInhibited=no\n' \
  >"$diag/etc/systemd/logind.conf.d/90-asahi-sleep.conf"
mkdir -p "$diag/etc/pam.d"
printf '%s\n' 'auth       optional     pam_gnome_keyring.so' 'session    optional     pam_gnome_keyring.so auto_start' \
  >"$diag/etc/pam.d/login"
: >"$diag/etc/udev/rules.d/99-asahi-charge-limit.rules"
: >"$diag/etc/udev/rules.d/99-asahi-hdmi-lid-inhibit.rules"
: >"$diag/etc/systemd/system/asahi-charge-limit.service"
: >"$diag/etc/systemd/system/asahi-hdmi-lid-inhibit.service"
: >"$diag/dev/dri/card0"
: >"$diag/dev/dri/renderD128"
mkdir -p "$sys/class/video4linux/video1" && echo apple-isp >"$sys/class/video4linux/video1/name"
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
case "$*" in
  "radio wifi") echo "${FAKE_WIFI_RADIO:-enabled}" ;;
  *) echo "wlan0:wifi:${FAKE_WIFI_STATE:-connected}" ;;
esac
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
echo "$out" | jq -e '[.checks[] | select(.id=="logind-lid" and .status=="PASS")] | length == 1' >/dev/null \
  || fail_at "logind-lid PASS"
pass "mocked Fedora Asahi tree is all PASS"

# Aurora: its kernel passes; Stage 2 DTBs without the sep alias (old pin) warn.
cp "$diag/etc/os-release" "$tmp/os-release.asahi"
printf 'PRETTY_NAME="Aurora Fedora Remix 45"\nVARIANT_ID=aurora\n' >"$diag/etc/os-release"
stage2() {
  ASAHI_UNAME_R=7.3.0-27.fc44.aurora.aarch64 PATH="$bin:$PATH" ASAHI_DIAG_ROOT="$diag" ASAHI_PROC_ROOT="$proc" \
    ASAHI_SYS_ROOT="$sys" "$ROOT/asahi-debug" --json | jq -r '[.checks[] | select(.id=="kernel" or .id=="stage2-dtb") | .status] | join(" ")' || true
}
[ "$(stage2)" = "PASS WARN" ] && pass "Aurora kernel PASS, stale Stage 2 DTB WARN" || fail_at "aurora stale stage2 (got $(stage2))"
mkdir -p "$proc/device-tree/aliases" && printf '/soc/sep@396400000\0' >"$proc/device-tree/aliases/sep"
[ "$(stage2)" = "PASS PASS" ] && pass "Aurora Stage 2 with sep alias is PASS" || fail_at "aurora stage2 (got $(stage2))"
rm -rf "$proc/device-tree/aliases"
cp "$tmp/os-release.asahi" "$diag/etc/os-release"

# Wi-Fi switched off on purpose (on ethernet) is fine; unavailable with the radio on is not.
wifi_status() {
  FAKE_WIFI_STATE="$1" FAKE_WIFI_RADIO="$2" PATH="$bin:$PATH" ASAHI_DIAG_ROOT="$diag" ASAHI_PROC_ROOT="$proc" \
    ASAHI_SYS_ROOT="$sys" "$ROOT/asahi-debug" --json | jq -r '.checks[] | select(.id=="wifi-link") | .status' || true
}
[ "$(wifi_status unavailable disabled)" = PASS ] && pass "Wi-Fi radio off is PASS" || fail_at "radio off should PASS"
[ "$(wifi_status unavailable enabled)" = WARN ] && pass "Wi-Fi unavailable with radio on is WARN" || fail_at "unavailable should WARN"
[ "$(wifi_status disconnected enabled)" = PASS ] && pass "Wi-Fi up, not connected is PASS" || fail_at "disconnected should PASS"

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

keyrings="$diag$HOME/.local/share/keyrings"
mkdir -p "$keyrings"
printf '%s\n' '[keyring]' 'display-name=Default keyring' >"$keyrings/Default_keyring.keyring"
mv "$diag/etc/pam.d/login" "$diag/etc/pam.d/login.off"
out=$(PATH="$bin:$PATH" ASAHI_DIAG_ROOT="$diag" ASAHI_PROC_ROOT="$proc" \
  ASAHI_SYS_ROOT="$sys" "$ROOT/asahi-debug" --json) || true
echo "$out" | jq -e '[.checks[] | select(.id=="keyring-pam" and .status=="FAIL")] | length == 1' >/dev/null &&
  echo "$out" | jq -e '[.checks[] | select(.id=="keyring-plaintext" and .status=="WARN")] | length == 1' >/dev/null &&
  pass "missing keyring PAM is FAIL, plaintext keyring is WARN" || fail_at "keyring checks (got $out)"
mv "$diag/etc/pam.d/login.off" "$diag/etc/pam.d/login"
rm -f "$keyrings/Default_keyring.keyring"

# xART guard: off on an M2 = WARN (FileVault macOS at risk), refusals = WARN, level 1 with none = PASS.
xart() {
  rm -rf "$sys/devices/platform/soc/396400000.sep"
  mkdir -p "$sys/devices/platform/soc/396400000.sep/diag"
  echo "$1" >"$sys/devices/platform/soc/396400000.sep/diag/xart_guard"
  echo "$2" >"$sys/devices/platform/soc/396400000.sep/diag/xart_guard_refusals"
  echo "${3:-unverified}" >"$sys/devices/platform/soc/396400000.sep/diag/matching"
  PATH="$bin:$PATH" ASAHI_DIAG_ROOT="$diag" ASAHI_PROC_ROOT="$proc" ASAHI_SYS_ROOT="$sys" "$ROOT/asahi-debug" --json |
    jq -r '.checks[] | select(.id=="xart-guard") | .status' || true
}
printf 'apple,j414s\0apple,t6020\0' >"$proc/device-tree/compatible.xart"
mv "$proc/device-tree/compatible" "$proc/device-tree/compatible.orig" 2>/dev/null
cp "$proc/device-tree/compatible.xart" "$proc/device-tree/compatible"
got="$(xart 1 0) $(xart 0 0) $(xart 1 3) $(xart 1 0 blocked)"
[ "$got" = "PASS WARN WARN WARN" ] && pass "xART guard: level 1 PASS, off on M2 WARN, refusals WARN, matching blocked WARN" ||
  fail_at "xART guard (got $got)"
rm -rf "$sys/devices/platform/soc/396400000.sep" "$proc/device-tree/compatible.xart"
if [ -e "$proc/device-tree/compatible.orig" ]; then
  mv "$proc/device-tree/compatible.orig" "$proc/device-tree/compatible"
else
  rm -f "$proc/device-tree/compatible"
fi

# Disk encryption: root on LUKS = PASS, plain root = WARN; a LUKS header copy on /boot = WARN.
printf '#!/bin/sh\necho "/dev/mapper/fedora_crypt[/root]"\n' >"$bin/findmnt"
printf '#!/bin/sh\n[ -n "$FAKE_PLAIN" ] && { echo btrfs; echo; exit 0; }\nprintf "btrfs\\ncrypto_LUKS\\n\\n"\n' >"$bin/lsblk"
chmod +x "$bin/findmnt" "$bin/lsblk"
enc() {
  PATH="$bin:$PATH" ASAHI_DIAG_LSBLK=1 ASAHI_DIAG_ROOT="$diag" ASAHI_PROC_ROOT="$proc" ASAHI_SYS_ROOT="$sys" "$ROOT/asahi-debug" --json |
    jq -r '[.checks[] | select(.id=="root-encrypted" or .id=="boot-secrets") | .status] | join(" ")' || true
}
mkdir -p "$diag/boot"
got1=$(enc); got2=$(FAKE_PLAIN=1 enc); : >"$diag/boot/luks-header-backup.img"; got3=$(enc); rm -f "$diag/boot/luks-header-backup.img"
[ "$got1|$got2|$got3" = "PASS|WARN|PASS WARN" ] && pass "encryption: LUKS root PASS, plain WARN, header copy on /boot WARN" ||
  fail_at "encryption checks (got $got1|$got2|$got3)"
rm -f "$bin/findmnt" "$bin/lsblk"

# Direct asserts: mic MONO, hid_apple bound, kmscon on tty1, apple-isp camera.
dbg_status() {
  PATH="$bin:$PATH" ASAHI_DIAG_ROOT="$diag" ASAHI_PROC_ROOT="$proc" ASAHI_SYS_ROOT="$sys" "$ROOT/asahi-debug" --json |
    jq -r --arg id "$1" '[.checks[] | select(.id == $id) | .status] | join(" ")' || true
}
cp "$bin/wpctl" "$tmp/wpctl.orig"; cp "$bin/systemctl" "$tmp/systemctl.orig"
printf '#!/bin/sh\n[ "$1" = inspect ] && { echo "  audio.position = \\"[ MONO ]\\""; exit 0; }\nexec "%s/wpctl.orig" "$@"\n' "$tmp" >"$bin/wpctl"
mono=$(dbg_status mic-mono)
printf '#!/bin/sh\n[ "$1" = inspect ] && { echo "  audio.position = \\"[ FL FR ]\\""; exit 0; }\nexec "%s/wpctl.orig" "$@"\n' "$tmp" >"$bin/wpctl"
stereo=$(dbg_status mic-mono)
cp "$tmp/wpctl.orig" "$bin/wpctl"
printf '#!/bin/sh\n[ "$1" = is-enabled ] && [ "$2" = kmsconvt@tty1.service ] && { echo enabled; exit 0; }\n' >"$bin/systemctl"
printf 'exec "%s/systemctl.orig" "$@"\n' "$tmp" >>"$bin/systemctl"
kmscon=$(dbg_status getty-kmscon)
cp "$tmp/systemctl.orig" "$bin/systemctl"
nokmscon=$(dbg_status getty-kmscon)
hid=$(dbg_status hid-apple); mv "$diag/sys/bus/hid/drivers/apple" "$tmp/apple.drv"; nohid=$(dbg_status hid-apple)
mv "$tmp/apple.drv" "$diag/sys/bus/hid/drivers/apple"
cam=$(dbg_status camera); echo avd >"$sys/class/video4linux/video1/name"; nocam=$(dbg_status camera)
echo apple-isp >"$sys/class/video4linux/video1/name"
got="$mono $stereo | $kmscon|$nokmscon | $hid $nohid | $cam $nocam"
[ "$got" = "PASS WARN | FAIL| | PASS FAIL | PASS WARN" ] && pass "mic MONO, kmscon on tty1, hid_apple bound, apple-isp camera" ||
  fail_at "direct asserts (got $got)"

# Thunderbolt: a device bolt has not authorised (TB3 dock USB / Ethernet) = WARN.
printf '#!/bin/sh\nprintf " ● Dock\\n   ├─ status:          %%s\\n" "${FAKE_BOLT:-authorized}"\n' >"$bin/boltctl"
chmod +x "$bin/boltctl"
tb_ok=$(dbg_status thunderbolt); tb_wait=$(FAKE_BOLT=connected dbg_status thunderbolt)
rm -f "$bin/boltctl"
[ "$tb_ok $tb_wait" = "PASS WARN" ] && pass "thunderbolt: authorised PASS, awaiting approval WARN" || fail_at "thunderbolt (got $tb_ok $tb_wait)"

# Watch list: SKIP while the upstream piece is missing, WARN / PASS once it arrives.
aur=$(grep -q '^VARIANT_ID=aurora' "$diag/etc/os-release" 2>/dev/null && echo yes || true)
[ -n "$aur" ] || echo 'VARIANT_ID=aurora' >>"$diag/etc/os-release"
printf '#!/bin/sh\necho "  key store: sealed"\n' >"$bin/aurora-fido"
printf '#!/bin/sh\necho "[{\\"name\\": \\"eDP-1\\", \\"vrr\\": ${FAKE_VRR:-false}}]"\n' >"$bin/hyprctl.watch"
[ -e "$bin/hyprctl" ] && cp "$bin/hyprctl" "$tmp/hyprctl.orig"
cp "$bin/hyprctl.watch" "$bin/hyprctl"; chmod +x "$bin/aurora-fido" "$bin/hyprctl"
watch() { echo "$(dbg_status watch-sep-key) $(dbg_status watch-vrr)"; }
w1=$(watch); mkdir -p "$diag/dev"; : >"$diag/dev/sep-key"; w2=$(FAKE_VRR=true watch)
printf '#!/bin/sh\necho "  key store: sep-key"\n' >"$bin/aurora-fido"; w3=$(dbg_status watch-sep-key); rm -f "$diag/dev/sep-key"
rm -f "$bin/aurora-fido" "$bin/hyprctl.watch"
if [ -e "$tmp/hyprctl.orig" ]; then mv "$tmp/hyprctl.orig" "$bin/hyprctl"; else rm -f "$bin/hyprctl"; fi
[ -n "$aur" ] || sed -i '/^VARIANT_ID=aurora$/d' "$diag/etc/os-release"
[ "$w1|$w2|$w3" = "SKIP SKIP|WARN PASS|PASS" ] &&
  pass "watch list: SKIP while absent, WARN (sep-key, sealed store) / PASS (VRR; sep-key, store moved) once there" ||
  fail_at "watch list (got $w1|$w2|$w3)"

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
