#!/usr/bin/env bash
# Fixture tests for asahi-cpu {tooltip, cores} JSON. No live writes.

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

# Only tooltip + cores are read (BarHost); sys_panel.js parseCpuTooltip parses these tooltip lines.
echo "$out" | jq -e 'keys == ["cores", "tooltip"]' >/dev/null || fail_at "json is {tooltip, cores}"
echo "$out" | jq -e '.cores | length == 2' >/dev/null || fail_at "two cores"
echo "$out" | jq -e '.cores[0].name == "CPU0" and (.cores[0].percent | . >= 0 and . <= 100)' >/dev/null || fail_at "core0 name/percent"
tip=$(echo "$out" | jq -r '.tooltip')
grep -qx 'Load 1/5/15: 0.10 0.20 0.30' <<<"$tip" || fail_at "tooltip load line"
grep -qx 'Cores: 2' <<<"$tip" || fail_at "tooltip cores line"
grep -q '^Freq avg 1.20 GHz' <<<"$tip" || fail_at "tooltip freq line"
grep -q '^Thermal 44.2 C' <<<"$tip" || fail_at "tooltip thermal line"
grep -q 'Heatpipe 18.0 W' <<<"$tip" || fail_at "tooltip names heatpipe"
grep -q 'no die sensor' <<<"$tip" || fail_at "tooltip explains missing die sensor"
pass "asahi-cpu json"

if [ "$fail" -ne 0 ]; then
  echo "asahi_cpu_test.sh: FAILED"
  echo "$out"
  exit 1
fi
echo "asahi_cpu_test.sh: all ok"
