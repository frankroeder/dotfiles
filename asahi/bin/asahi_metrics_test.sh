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
mkdir -p "$proc/net" "$sys/class/block/nvme0n1/device" "$sys/class/block/nvme0n1p1" "$sys/class/block/zram0/device"
printf '1\n' >"$sys/class/block/nvme0n1p1/partition"
printf '10578.11 114781.38\n' >"$proc/uptime"
# /proc/diskstats: major minor name ... read_sectors(6) ... write_sectors(10)
printf '259 0 nvme0n1 0 0 2000 0 0 0 4000 0 0 0 0\n' >"$proc/diskstats"
printf '259 1 nvme0n1p1 0 0 100 0 0 0 100 0 0 0 0\n' >>"$proc/diskstats"
printf 'Iface\tDestination\tGateway\tFlags\tRefCnt\tUse\tMetric\tMask\tMTU\tWindow\tIRTT\n' >"$proc/net/route"
printf 'wlan0\t00000000\t0101A8C0\t0003\t0\t0\t600\t00000000\t0\t0\t0\n' >>"$proc/net/route"
printf 'Inter-| Receive | Transmit\n' >"$proc/net/dev"
printf ' face |bytes packets errs drop fifo frame compressed multicast|bytes packets errs drop fifo colls carrier compressed\n' >>"$proc/net/dev"
printf '  lo: 1000 10 0 0 0 0 0 0 1000 10 0 0 0 0 0 0\n' >>"$proc/net/dev"
printf 'wlan0: 5000 20 0 0 0 0 0 0 7000 30 0 0 0 0 0 0\n' >>"$proc/net/dev"

state="$tmp/metrics.stat"
now=$(date +%s%3N)
case "$now" in '' | *[!0-9]*) now=1000000 ;; esac
prev=$((now - 2000))
# 2s earlier: 512000/1024000 disk bytes, 1000/2000 net bytes.
printf '%s 512000 1024000 1000 2000\n' "$prev" >"$state"

out=$(ASAHI_PROC_ROOT="$proc" ASAHI_SYS_ROOT="$sys" ASAHI_METRICS_STATE="$state" "$ROOT/asahi-metrics")
echo "$out" | jq -e '.disk.devices == ["nvme0n1"]' >/dev/null || fail_at "physical nvme only"
echo "$out" | jq -e '.net.iface == "wlan0"' >/dev/null || fail_at "default-route iface"
echo "$out" | jq -e '.uptime_s == 10578' >/dev/null || fail_at "uptime seconds"
echo "$out" | jq -e '.load == null' >/dev/null || fail_at "load stays on asahi-cpu"
echo "$out" | jq -e '.disk.read_bps > 0 and .disk.write_bps > 0' >/dev/null || fail_at "disk rates from delta"
echo "$out" | jq -e '.net.rx_bps > 0 and .net.tx_bps > 0' >/dev/null || fail_at "net rates from delta"
echo "$out" | jq -e '.filesystems | type == "array"' >/dev/null || fail_at "filesystems array"
pass "metrics snapshot"

# Second sample with no elapsed time should not go negative.
printf '999999999999 1024000 2048000 5000 7000\n' >"$state"
out=$(ASAHI_PROC_ROOT="$proc" ASAHI_SYS_ROOT="$sys" ASAHI_METRICS_STATE="$state" "$ROOT/asahi-metrics")
echo "$out" | jq -e '.disk.read_bps == 0 and .net.rx_bps == 0' >/dev/null || fail_at "future prev sample yields 0"
pass "no negative rates"

if [ "$fail" -ne 0 ]; then
  echo "asahi_metrics_test.sh: FAILED"
  exit 1
fi
echo "asahi_metrics_test.sh: all ok"
