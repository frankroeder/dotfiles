#!/usr/bin/env bash
# Fixture tests for asahi-temperature. No live sysfs writes.

set -euo pipefail

ROOT="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")" && pwd)"
fail=0
pass() { printf 'ok  %s\n' "$1"; }
fail_at() { printf 'FAIL %s\n' "$1"; fail=1; }

tmp=$(mktemp -d)
cleanup() { rm -rf "$tmp" || true; }
trap cleanup EXIT

hw="$tmp/hwmon"
mkdir -p "$hw/hwmon0" "$hw/hwmon1" "$hw/hwmon2"

printf 'nvme\n' >"$hw/hwmon0/name"
printf 'Composite\n' >"$hw/hwmon0/temp1_label"
printf '34850\n' >"$hw/hwmon0/temp1_input"

printf 'macsmc_hwmon\n' >"$hw/hwmon1/name"
printf 'NAND Flash Temperature\n' >"$hw/hwmon1/temp1_label"
printf '36910\n' >"$hw/hwmon1/temp1_input"
printf 'Battery Hotspot\n' >"$hw/hwmon1/temp2_label"
printf '34500\n' >"$hw/hwmon1/temp2_input"
printf 'Charge Regulator Temp\n' >"$hw/hwmon1/temp3_label"
printf '41970\n' >"$hw/hwmon1/temp3_input"
printf 'WiFi/BT Module Temp\n' >"$hw/hwmon1/temp4_label"
printf '44200\n' >"$hw/hwmon1/temp4_input"
printf 'Total System Power\n' >"$hw/hwmon1/power1_label"
printf '16352218\n' >"$hw/hwmon1/power1_input"
printf 'Heatpipe Power\n' >"$hw/hwmon1/power4_label"
printf '4223743\n' >"$hw/hwmon1/power4_input"
printf 'Fan 1\n' >"$hw/hwmon1/fan1_label"
printf '0\n' >"$hw/hwmon1/fan1_input"
printf '2317\n' >"$hw/hwmon1/fan1_min"
printf '6800\n' >"$hw/hwmon1/fan1_max"
printf 'Fan 2\n' >"$hw/hwmon1/fan2_label"
printf '2400\n' >"$hw/hwmon1/fan2_input"
printf '2317\n' >"$hw/hwmon1/fan2_min"
printf '6800\n' >"$hw/hwmon1/fan2_max"

printf 'SoC Die Temperature\n' >"$hw/hwmon1/temp9_label"
printf '47012\n' >"$hw/hwmon1/temp9_input"
printf 'Charger Input Voltage\n' >"$hw/hwmon1/in0_label"
printf '19681\n' >"$hw/hwmon1/in0_input"
printf 'AC Input Current\n' >"$hw/hwmon1/curr1_label"
printf '767\n' >"$hw/hwmon1/curr1_input"

th="$tmp/thermal"
mkdir -p "$th/cooling_device0" "$th/cooling_device1" "$th/cooling_device2"
printf 'cpufreq-cpu0\n' >"$th/cooling_device0/type"; printf '0\n' >"$th/cooling_device0/cur_state"; printf '5\n' >"$th/cooling_device0/max_state"
printf 'cpufreq-cpu4\n' >"$th/cooling_device1/type"; printf '3\n' >"$th/cooling_device1/cur_state"; printf '16\n' >"$th/cooling_device1/max_state"
printf 'Processor\n' >"$th/cooling_device2/type"; printf '0\n' >"$th/cooling_device2/cur_state"; printf '3\n' >"$th/cooling_device2/max_state"
export ASAHI_THERMAL_ROOT="$th"

printf 'macsmc_battery\n' >"$hw/hwmon2/name"
printf 'temp\n' >"$hw/hwmon2/temp1_label"
printf '34500\n' >"$hw/hwmon2/temp1_input"
printf '0\n' >"$hw/hwmon2/power1_input"

chmod +x "$ROOT/asahi-temperature"

out=$(ASAHI_HWMON_ROOT="$hw" "$ROOT/asahi-temperature")
echo "$out" | grep -q 'WiFi/BT Module Temp' || fail_at "human lists wifi temp"
echo "$out" | grep -q '44.20°C' || fail_at "human scales milli-C"
echo "$out" | grep -q 'Heatpipe Power' || fail_at "human lists heatpipe"
echo "$out" | grep -q '4.22 W' || fail_at "human scales micro-W"
echo "$out" | grep -q 'Fan 1' || fail_at "human lists fans"
echo "$out" | grep -q '^    2317–6800 RPM$' || fail_at "human fan range line"
echo "$out" | grep -qx '  nvme               Composite                      34.85°C   '"$hw"'/hwmon0/temp1_input' \
  || fail_at "human row format (TempPane parses it)"
echo "$out" | grep -q "SoC Die Temperature is the chip's own °C" || fail_at "human explains the die sensor"
echo "$out" | grep -qx '  macsmc_hwmon       Charger Input Voltage          19.68 V   '"$hw"'/hwmon1/in0_input' || fail_at "human charger volts"
echo "$out" | grep -qx 'Throttle: cpufreq-cpu0 0/5 cpufreq-cpu4 3/16' || fail_at "human throttle line (cpufreq only)"
# HID/battery power rails must not leak into the SMC power section.
echo "$out" | grep -F 'macsmc_battery' | grep -q ' W ' && fail_at "battery power rail should be omitted" || true
pass "human output lists temps, heatpipe, fans"

"$ROOT/asahi-temperature" --nope >/dev/null 2>&1 && fail_at "bad flag should fail" || pass "usage"

js=$(ASAHI_HWMON_ROOT="$hw" "$ROOT/asahi-temperature" --json)
echo "$js" | jq -e 'keys == ["amps", "cooling", "fans", "power", "temps", "volts"]' >/dev/null \
  || fail_at "json is {temps, power, fans, volts, amps, cooling}"
echo "$js" | jq -e '.volts[] | select(.label == "Charger Input Voltage") | .value == 19.68 and .unit == "V"' >/dev/null || fail_at "json volts"
echo "$js" | jq -e '.amps[0].value == 0.77 and .amps[0].unit == "A"' >/dev/null || fail_at "json amps"
echo "$js" | jq -e '.cooling == [{type: "cpufreq-cpu0", cur: 0, max: 5}, {type: "cpufreq-cpu4", cur: 3, max: 16}]' >/dev/null \
  || fail_at "json cooling (cpufreq only)"
echo "$js" | jq -e '.temps[] | select(.label == "WiFi/BT Module Temp") | .value == 44.2 and .unit == "C"' >/dev/null \
  || fail_at "json wifi temp"
echo "$js" | jq -e '.power[] | select(.label == "Heatpipe Power") | .value == 4.22 and .unit == "W"' >/dev/null \
  || fail_at "json heatpipe watts"
echo "$js" | jq -e '.power | map(.label) | index("Total System Power")' >/dev/null || fail_at "json has system power"
echo "$js" | jq -e '[.fans[].label] | index("Fan 1") and index("Fan 2")' >/dev/null || fail_at "json has both fans"
echo "$js" | jq -e '.fans[] | select(.label=="Fan 2") | .value == 2400 and .min == 2317 and .max == 6800' >/dev/null \
  || fail_at "json fan bounds"
echo "$js" | jq -e '[.temps[].name] | index("nvme") and index("macsmc_battery")' >/dev/null || fail_at "json temps include nvme+battery"
echo "$js" | jq -e '[.power[].name] | unique == ["macsmc_hwmon"]' >/dev/null || fail_at "json power is macsmc only"
pass "json output"

empty="$tmp/empty"
mkdir -p "$empty"
empty_js=$(ASAHI_HWMON_ROOT="$empty" ASAHI_THERMAL_ROOT="$empty" "$ROOT/asahi-temperature" --json)
echo "$empty_js" | jq -e '. == {temps: [], power: [], fans: [], volts: [], amps: [], cooling: []}' >/dev/null \
  || fail_at "empty tree is empty json"
pass "empty hwmon tree"

if [ "$fail" -ne 0 ]; then
  echo "asahi_temperature_test.sh: FAILED"
  exit 1
fi
echo "asahi_temperature_test.sh: all ok"
