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
echo "$out" | grep -q 'Hottest:' || fail_at "human has hottest"
echo "$out" | grep -q 'Heatpipe:' || fail_at "human has heatpipe headline"
echo "$out" | grep -q 'no die °C' || fail_at "human explains missing SoC die sensor"
# HID/battery power rails must not leak into the SMC power section.
echo "$out" | grep -F 'macsmc_battery' | grep -q ' W ' && fail_at "battery power rail should be omitted" || true
pass "human output lists temps, heatpipe, fans"

"$ROOT/asahi-temperature" --nope >/dev/null 2>&1 && fail_at "bad flag should fail" || pass "usage"

js=$(ASAHI_HWMON_ROOT="$hw" "$ROOT/asahi-temperature" --json)
echo "$js" | jq -e '.hottest.label == "WiFi/BT Module Temp"' >/dev/null || fail_at "json hottest is wifi"
echo "$js" | jq -e '.hottest.value == 44.20' >/dev/null || fail_at "json hottest value"
echo "$js" | jq -e '.heatpipe.label == "Heatpipe Power"' >/dev/null || fail_at "json heatpipe label"
echo "$js" | jq -e '.heatpipe.value == 4.22' >/dev/null || fail_at "json heatpipe watts"
echo "$js" | jq -e '.power | map(.label) | index("Total System Power")' >/dev/null || fail_at "json has system power"
echo "$js" | jq -e '[.fans[].label] | index("Fan 1") and index("Fan 2")' >/dev/null || fail_at "json has both fans"
echo "$js" | jq -e '.fans[] | select(.label=="Fan 2") | .value == 2400 and .min == 2317 and .max == 6800' >/dev/null \
  || fail_at "json fan bounds"
echo "$js" | jq -e '[.temps[].name] | index("nvme") and index("macsmc_battery")' >/dev/null || fail_at "json temps include nvme+battery"
echo "$js" | jq -e '[.power[].name] | unique == ["macsmc_hwmon"]' >/dev/null || fail_at "json power is macsmc only"
pass "json output"

empty=$(mktemp -d)
empty_js=$(ASAHI_HWMON_ROOT="$empty" "$ROOT/asahi-temperature" --json)
echo "$empty_js" | jq -e '.temps == [] and .heatpipe == null and .hottest == null' >/dev/null || fail_at "empty tree is empty json"
pass "empty hwmon tree"

if [ "$fail" -ne 0 ]; then
  echo "asahi_temperature_test.sh: FAILED"
  exit 1
fi
echo "asahi_temperature_test.sh: all ok"
