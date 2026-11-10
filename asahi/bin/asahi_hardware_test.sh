#!/usr/bin/env bash
# asahi-hardware on a fake sysfs / procfs / device tree (ASAHI_SYS_ROOT) with fake fprintd-list / tuned-adm / journalctl.
set -u
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
fail=0
pass() { printf 'ok  %s\n' "$1"; }
fail_at() { printf 'FAIL %s\n' "$1"; fail=1; }
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
r=$tmp/root
put() { mkdir -p "$(dirname "$r/$1")"; printf '%b' "$2" >"$r/$1"; }
put proc/device-tree/model 'Apple MacBook Pro (14-inch, M2 Pro, 2023)\0'
put proc/device-tree/compatible 'apple,j414s\0apple,t6020\0apple,arm-platform\0'
put proc/device-tree/chosen/asahi,m1n1-stage1-version 'v1.5.2\0'
put proc/device-tree/chosen/u-boot,version '2026.07\0'
put sys/class/dmi/id/product_sku 'Mac14,9\n'
put sys/devices/system/cpu/cpufreq/policy0/related_cpus '0 1 2 3\n'
put sys/devices/system/cpu/cpufreq/policy0/cpuinfo_max_freq '2424000\n'
put sys/devices/system/cpu/cpufreq/policy4/related_cpus '4 5 6 7\n'
put sys/devices/system/cpu/cpufreq/policy4/cpuinfo_max_freq '3264000\n'
put sys/devices/system/cpu/cpufreq/boost '0\n'
put proc/meminfo 'MemTotal:       32437664 kB\n'
put etc/os-release 'PRETTY_NAME="Aurora Fedora Remix 45"\n'
put sys/class/hwmon/hwmon3/name 'macsmc_hwmon\n'
put sys/class/hwmon/hwmon3/power1_label 'Total System Power\n'
put sys/class/hwmon/hwmon3/power1_input '13907677\n'
put sys/class/hwmon/hwmon3/power4_label 'Heatpipe Power\n'
put sys/class/hwmon/hwmon3/power4_input '4453397\n'
put sys/class/hwmon/hwmon3/fan1_input '0\n'
put sys/class/power_supply/macsmc-ac/input_power_limit '89200000\n'
put sys/class/typec/port0/power_role 'source [sink]\n'
put sys/class/typec/port0/device/of_node/connector/label 'USB-C Left Back\0'
put sys/class/typec/port0-partner/identity/id_header '0x5440043e\n'
put sys/class/typec/port0-partner/port0-partner.0/svid 'ff01\n'
put sys/class/typec/port0-partner/port0-partner.0/active 'yes\n'
put sys/class/typec/port1/power_role '[sink]\n'
# Sensors are found by name: the lid angle sits on device0 here, the light sensor on device1 (live: the other way).
put sys/bus/iio/devices/iio:device0/name 'aop-sensors-las\n'
put sys/bus/iio/devices/iio:device0/in_angl_raw '130\n'
put sys/bus/iio/devices/iio:device1/name 'aop-sensors-als\n'
put sys/bus/iio/devices/iio:device1/in_illuminance_input '292.778198\n'
put sys/class/backlight/apple-panel-bl/brightness '275\n'
put sys/class/backlight/apple-panel-bl/max_brightness '500\n'
put sys/devices/platform/soc/396400000.sep/diag/touchid 'ready\n'
put sys/devices/platform/soc/396400000.sep/diag/xart_guard_refusals '0\n'
put sys/bus/pci/devices/0000:01:00.0/vendor '0x14e4\n'
put sys/bus/pci/devices/0000:01:00.0/device '0x4434\n'
put sys/class/drm/card2/device/agx_stats 'busy_ns 1\nutil1 14\npower_mw 323\nrequested_frequency_hz 444000000\n'
mkdir -p "$tmp/bin"
printf '#!/bin/sh\necho "Fingerprints for user u on sensor (press):"\necho " - #0: right-index-finger"\n' >"$tmp/bin/fprintd-list"
printf '#!/bin/sh\necho "Current active profile: balanced"\n' >"$tmp/bin/tuned-adm"
printf '#!/bin/sh\necho "aurora 406400000.gpu:   Active cores: 19"\n' >"$tmp/bin/journalctl"
printf '#!/bin/sh\nexit 1\n' >"$tmp/bin/ethtool"
chmod +x "$tmp/bin/"*
hw() { ASAHI_SYS_ROOT=$r XDG_RUNTIME_DIR=$tmp PATH="$tmp/bin:$PATH" "$ROOT/asahi-hardware" "$@"; }

j=$(hw)
check() {   # jq expression must be true
  if jq -e "$1" >/dev/null <<<"$j"; then pass "$2"; else fail_at "$2: $(jq -c "$3" <<<"$j" 2>&1)"; fi
}
check '.chip == "M2 Pro" and .sku == "Mac14,9" and .model == "Apple MacBook Pro (14-inch, M2 Pro, 2023)"' "Mac: model, chip from compatible" '{chip, sku, model}'
check '.cpu.clusters == [{cores: 4, max_mhz: 2424}, {cores: 4, max_mhz: 3264}] and .cpu.boost == false' "CPU clusters + boost off" '.cpu'
check '.gpu.cores == 19 and .gpu.util == 14 and .gpu.mhz == 444' "GPU: cores (kernel log), load, clock" '.gpu'
check '.mem_gb == 32' "RAM: 30.9 GiB usable reads as the 32 GB config" '.mem_gb'
check '.power.system_w == 13.9 and .power.soc_w == 4.5 and .power.charger_w == 89.2 and .power.ac_w == null' "power rails by label" '.power'
check '.ports[0] | .name == "USB-C Left Back" and .power == "sink" and .vendor == "043e" and .dp == true' "USB-C port: label, charging, partner, DP" '.ports[0]'
check '.ports[1] | .name == "MagSafe" and .partner == false' "unlabelled PD controller = MagSafe" '.ports[1]'
check '.sensors.lux == 293 and .sensors.lid_deg == 130 and .sensors.panel == 55 and .sensors.kbd == null' "sensors (missing kbd light = null)" '.sensors'
check '.sep.touchid == "ready" and .sep.fingers == 1 and .sep.refusals == 0 and .profile == "balanced"' "Touch ID + tuned profile" '{sep, profile}'
check '.radios.wifi == "BCM4388" and .boot.stage1 == "v1.5.2" and .os == "Aurora Fedora Remix 45"' "radios, boot chain, OS" '{radios, boot, os}'
l=$(hw --live)
if jq -e '.power.system_w == 13.9 and (has("model") | not) and (.ports | length) == 2' >/dev/null <<<"$l"; then
  pass "--live: power / ports only"
else
  fail_at "--live: $l"
fi
[ "$fail" -eq 0 ] && echo "all passed" || exit 1
