#!/usr/bin/env bash
# asahi-hardware on a fake sysfs / procfs / device tree (ASAHI_SYS_ROOT) with fake fprintd-list / journalctl.
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
put proc/device-tree/serial-number 'C02TEST123\0'
put proc/device-tree/chosen/asahi,m1n1-stage1-version 'v1.5.2\0'
put proc/device-tree/chosen/u-boot,version '2026.07\0'
put sys/class/dmi/id/product_sku 'Mac14,9\n'
put sys/devices/system/cpu/cpufreq/policy0/related_cpus '0 1 2 3\n'
put sys/devices/system/cpu/cpufreq/policy0/cpuinfo_max_freq '2424000\n'
put sys/devices/system/cpu/cpufreq/policy4/related_cpus '4 5 6 7\n'
put sys/devices/system/cpu/cpufreq/policy4/cpuinfo_max_freq '3264000\n'
put sys/devices/system/cpu/cpufreq/policy0/scaling_cur_freq '1752000\n'
put sys/devices/system/cpu/cpufreq/policy0/scaling_governor 'schedutil\n'
put sys/devices/system/cpu/cpufreq/policy4/scaling_cur_freq '948000\n'
put sys/class/typec/port0/power_role 'source [sink]\n'
put sys/class/typec/port0/device/of_node/connector/label 'USB-C Left Back\0'
put sys/class/typec/port0-partner/identity/id_header '0x5440043e\n'
put sys/class/typec/port0-partner/port0-partner.0/svid 'ff01\n'
put sys/class/typec/port0-partner/port0-partner.0/active 'yes\n'
put sys/class/typec/port1/power_role '[sink]\n'
put sys/class/typec/port1/power_operation_mode 'default\n'
put sys/class/typec/port1/data_role '[device]\n'
# port0 negotiated PD and has a USB controller (a device link names it). Behind it: a hub (left out) and a network
# adapter; the mouse hangs on another port's controller.
put sys/class/typec/port0/power_operation_mode 'usb_power_delivery\n'
put sys/class/typec/port0/data_role '[host] device\n'
put sys/class/typec/port0/supplier:platform:702280000.usb/uevent ''
usb() {   # usb <controller> <bus path> <class> <product> <speed>
  put "sys/devices/platform/soc/$1/xhci/$2/bDeviceClass" "$3\n"
  put "sys/devices/platform/soc/$1/xhci/$2/product" "$4\n"
  put "sys/devices/platform/soc/$1/xhci/$2/speed" "$5\n"
  mkdir -p "$r/sys/bus/usb/devices"
  ln -s "../../../devices/platform/soc/$1/xhci/$2" "$r/sys/bus/usb/devices/${2##*/}"
}
usb 702280000.usb usb2/2-1 09 'USB3.2 Hub' 5000
usb 702280000.usb usb2/2-1/2-1.4 00 'USB 10/100/1000 LAN' 5000
usb f02280000.usb usb5/5-1 00 'Gaming Mouse' 12
put sys/power/suspend_stats/success '11\n'
put sys/power/suspend_stats/fail '2\n'
put sys/power/suspend_stats/last_failed_errno '-16\n'
put state/asahi/idle.log '2026-11-11 09:00:00 at 150: dim\n2026-11-11 10:03:35 slept 0h42m on AC, gained 0.50 Wh\n2026-11-11 10:04:08 slept 2h8m, used 3.81 Wh (1.78 W)\n2026-11-11 10:04:55 wake\n'
put state-ac/asahi/idle.log '2026-11-11 10:03:35 slept 0h42m on AC, gained 0.50 Wh\n'
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
printf '#!/bin/sh\necho "aurora 406400000.gpu:   Active cores: 19"\n' >"$tmp/bin/journalctl"
printf '#!/bin/sh\nexit 1\n' >"$tmp/bin/ethtool"
chmod +x "$tmp/bin/"*
hw() { ASAHI_SYS_ROOT=$r XDG_RUNTIME_DIR=$tmp XDG_STATE_HOME=${STATE:-/state} PATH="$tmp/bin:$PATH" "$ROOT/asahi-hardware" "$@"; }

j=$(hw)
check() {   # [--arg name value] <jq expression that must be true> <what> <what to print on failure>
  local args=()
  if [ "$1" = --arg ]; then args=(--arg "$2" "$3"); shift 3; fi
  if jq -e "${args[@]}" "$1" >/dev/null <<<"$j"; then pass "$2"; else fail_at "$2: $(jq -c "$3" <<<"$j" 2>&1)"; fi
}
check '.sku == "Mac14,9" and .model == "Apple MacBook Pro (14-inch, M2 Pro, 2023)"' "Mac: model, SKU" '{sku, model}'
check '.cpu.clusters == [{cores: 4, max_mhz: 2424}, {cores: 4, max_mhz: 3264}]' "CPU clusters" '.cpu'
check '.cpu.governor == "schedutil" and .cpu_mhz == [1752, 948]' "CPU: governor, one live clock per cluster" '{cpu, cpu_mhz}'
check '.serial == "C02TEST123"' "serial number from the device tree" '.serial'
check '.gpu.cores == 19 and .gpu.util == 14 and .gpu.mhz == 444' "GPU: cores (kernel log), load, clock" '.gpu'
check '[has("power", "ssd", "os", "mem_gb", "chip", "profile")] == [false, false, false, false, false, false]' \
  "nothing another pane owns (power rails, SSD, OS, memory, chip, profile)" 'keys'
check --arg k "$(uname -r)" '.kernel == $k and .page_kb > 0' "kernel release + page size (the wanted overlap with the Dashboard)" '{kernel, page_kb}'
check '.ports[0] | .name == "USB-C Left Back" and .power == "sink" and .vendor == "043e" and .dp == true' "USB-C port: label, charging, partner, DP" '.ports[0]'
check '.ports[1] | .name == "MagSafe" and .partner == false' "unlabelled PD controller = MagSafe" '.ports[1]'
check '.ports[0] | .pd == true and .data == "host" and .devices == [{name: "USB 10/100/1000 LAN", mbps: 5000}]' \
  "port: PD, data role, the devices behind its controller (no hubs, no other port's)" '.ports[0]'
check '.ports[1] | .pd == false and .data == "" and .devices == []' "MagSafe: no PD yet, no data lines, no devices" '.ports[1]'
check '.sleep == {ok: 11, failed: 2, last_errno: -16, last: {at: "2026-11-11 10:04:08", minutes: 128, ac: false, used_wh: 3.81, w: 1.78, gained_wh: null}}' \
  "sleep: kernel counters + the last sleep in idle.log" '.sleep'
j=$(STATE=/state-ac hw)
check '.sleep.last == {at: "2026-11-11 10:03:35", minutes: 42, ac: true, used_wh: null, w: null, gained_wh: 0.5}' "sleep on AC: gained, no rate" '.sleep'
j=$(STATE=/nowhere hw)
check '.sleep.last == null and .sleep.ok == 11' "no idle.log: counters only" '.sleep'
check '.sensors.lux == 293 and .sensors.lid_deg == 130 and .sensors.panel == 55 and .sensors.kbd == null' "sensors (missing kbd light = null)" '.sensors'
check '.sep.touchid == "ready" and .sep.fingers == 1 and .sep.refusals == 0' "Touch ID" '.sep'
check '.radios.wifi == "BCM4388" and .boot.stage1 == "v1.5.2" and .boot.uboot == "2026.07"' "Wi-Fi chip, boot chain" '{radios, boot}'
l=$(hw --live)
if jq -e '.gpu.util == 14 and (has("model") | not) and (.ports | length) == 2 and .cpu_mhz == [1752, 948]
    and (.ports[0].devices | length) == 1 and (has("sleep") | not) and .sensors.lid_deg == 130' >/dev/null <<<"$l"; then
  pass "--live: CPU clocks / GPU / ports / sensors only"
else
  fail_at "--live: $l"
fi
[ "$fail" -eq 0 ] && echo "all passed" || exit 1
