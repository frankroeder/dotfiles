#!/usr/bin/env bash
# Fixture tests for asahi-cpu heatpipe + per-core JSON. No live writes.

set -euo pipefail

ROOT="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")" && pwd)"
fail=0
pass() { printf 'ok  %s\n' "$1"; }
fail_at() { printf 'FAIL %s\n' "$1"; fail=1; }

tmp=$(mktemp -d)
cleanup() { rm -rf "$tmp" || true; }
trap cleanup EXIT

chmod +x "$ROOT/asahi-cpu"

hw="$tmp/hwmon"
stat="$tmp/stat"
load="$tmp/loadavg"
freq="$tmp/cpu"
state="$tmp/state"
mkdir -p "$hw/hwmon1" "$freq/cpu0/cpufreq" "$state"

printf 'macsmc_hwmon\n' >"$hw/hwmon1/name"
printf 'WiFi/BT Module Temp\n' >"$hw/hwmon1/temp4_label"
printf '44200\n' >"$hw/hwmon1/temp4_input"
printf 'Heatpipe Power\n' >"$hw/hwmon1/power4_label"
printf '18000000\n' >"$hw/hwmon1/power4_input"

printf 'cpu 3357 0 4323 422382 0 0 0 0 0 0\n' >"$stat"
printf 'cpu0 1000 0 500 100000 0 0 0 0 0 0\n' >>"$stat"
printf 'cpu1 800 0 400 90000 0 0 0 0 0 0\n' >>"$stat"
printf '0.10 0.20 0.30 1/100 1\n' >"$load"
printf '1200000\n' >"$freq/cpu0/cpufreq/scaling_cur_freq"

# Previous sample so the first run produces a real percentage.
printf 'cpu 3000 0 400000\n' >"$state/cpu.stat"
printf 'cpu0 900 0 95000\n' >>"$state/cpu.stat"
printf 'cpu1 700 0 85000\n' >>"$state/cpu.stat"

out=$(
  ASAHI_HWMON_ROOT="$hw" \
  ASAHI_PROC_STAT="$stat" \
  ASAHI_PROC_LOADAVG="$load" \
  ASAHI_CPUFREQ_ROOT="$freq" \
  ASAHI_CPU_STATE_DIR="$state" \
  "$ROOT/asahi-cpu"
)

echo "$out" | jq -e '.percentage >= 0 and .percentage <= 100' >/dev/null || fail_at "percentage band"
echo "$out" | jq -e '.cores | length == 2' >/dev/null || fail_at "two cores"
echo "$out" | jq -e '.cores[0].name == "CPU0"' >/dev/null || fail_at "core0 name"
echo "$out" | jq -e '.heatpipe_w == 18.0' >/dev/null || fail_at "heatpipe watts"
echo "$out" | jq -e '.temp_c == 44.2' >/dev/null || fail_at "hottest exposed temp"
echo "$out" | jq -e '.class == "warning"' >/dev/null || fail_at "15 W heatpipe is warning"
echo "$out" | jq -e '.text | test("CPU [0-9]+%")' >/dev/null || fail_at "text is CPU percent"
echo "$out" | jq -e '.text | test("C$") | not' >/dev/null || fail_at "text must not append peripheral °C"
echo "$out" | jq -r '.tooltip' | grep -q 'Heatpipe 18.0 W' || fail_at "tooltip names heatpipe"
echo "$out" | jq -r '.tooltip' | grep -q 'no die sensor' || fail_at "tooltip explains missing die sensor"
pass "asahi-cpu json"

if [ "$fail" -ne 0 ]; then
  echo "asahi_cpu_test.sh: FAILED"
  echo "$out"
  exit 1
fi
echo "asahi_cpu_test.sh: all ok"
