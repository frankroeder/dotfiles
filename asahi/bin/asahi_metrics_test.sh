#!/usr/bin/env bash
# Fixture tests for asahi-metrics. No live sysfs writes.

set -euo pipefail

ROOT="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")" && pwd)"
fail=0
pass() { printf 'ok  %s\n' "$1"; }
fail_at() { printf 'FAIL %s\n' "$1"; fail=1; }

tmp=$(mktemp -d)
cleanup() { rm -rf "$tmp" || true; }
trap cleanup EXIT

chmod +x "$ROOT/asahi-metrics"

"$ROOT/asahi-metrics" --help >/dev/null 2>&1 && fail_at "help should exit 2" || pass "usage"

proc="$tmp/proc"
sys="$tmp/sys"
mkdir -p "$proc" "$sys/class/block/nvme0n1/device" "$sys/class/block/nvme0n1p1" "$sys/class/block/zram0/device"
printf '1\n' >"$sys/class/block/nvme0n1p1/partition"
# /proc/diskstats: major minor name ... read_sectors(6) ... write_sectors(10)
printf '259 0 nvme0n1 0 0 2000 0 0 0 4000 0 0 0 0\n' >"$proc/diskstats"
printf '259 1 nvme0n1p1 0 0 100 0 0 0 100 0 0 0 0\n' >>"$proc/diskstats"
printf '251 0 zram0 0 0 900 0 0 0 900 0 0 0 0\n' >>"$proc/diskstats"

state="$tmp/metrics.stat"
now=$(date +%s%3N)
case "$now" in '' | *[!0-9]*) now=1000000 ;; esac
prev=$((now - 2000))
# 2s earlier: 512000/1024000 disk bytes.
printf '%s 512000 1024000\n' "$prev" >"$state"

out=$(ASAHI_PROC_ROOT="$proc" ASAHI_SYS_ROOT="$sys" ASAHI_METRICS_STATE="$state" "$ROOT/asahi-metrics")
echo "$out" | jq -e 'keys == ["disk"]' >/dev/null || fail_at "only disk rates (the Storage pane reads nothing else)"
echo "$out" | jq -e '.disk.devices == ["nvme0n1"]' >/dev/null || fail_at "physical nvme only"
# 512000 B over a bit more than 2 s: at most 256000 B/s (partition or zram sectors would push it past).
echo "$out" | jq -e '.disk.read_bps > 0 and .disk.read_bps <= 256000 and .disk.write_bps > 0' >/dev/null || fail_at "disk rates from delta"
pass "metrics snapshot"

# Second sample with no elapsed time should not go negative.
printf '999999999999 1024000 2048000\n' >"$state"
out=$(ASAHI_PROC_ROOT="$proc" ASAHI_SYS_ROOT="$sys" ASAHI_METRICS_STATE="$state" "$ROOT/asahi-metrics")
echo "$out" | jq -e '.disk.read_bps == 0 and .disk.write_bps == 0' >/dev/null || fail_at "future prev sample yields 0"
pass "no negative rates"

if [ "$fail" -ne 0 ]; then
  echo "asahi_metrics_test.sh: FAILED"
  exit 1
fi
echo "asahi_metrics_test.sh: all ok"
