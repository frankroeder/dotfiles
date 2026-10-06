#!/usr/bin/env bash
# Smoke tests for asahi-timemachine. Fake restic / sftp / notify-send, no drive, no network.

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TM="$ROOT/asahi-timemachine"
fail=0
pass() { printf 'ok  %s\n' "$1"; }
fail_at() { printf 'FAIL %s\n' "$1"; fail=1; }

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
mkdir -p "$tmp/bin" "$tmp/cfg/asahi-timemachine" "$tmp/home"
# FAKE_FAIL=<subcommand>: that restic subcommand exits 1 without any stderr (e.g. SIGKILL / OOM).
cat >"$tmp/bin/restic" <<'EOF'
#!/bin/bash
echo "restic $*" >>"$TM_LOG"
case "$*" in *" $FAKE_FAIL "*) [ -n "$FAKE_FAIL" ] && exit 1 ;; esac
case "$*" in
  *" ls "*) printf '%s\n' '{"struct_type":"snapshot"}' \
    '{"struct_type":"node","name":"h","type":"dir","path":"/h","mtime":"x"}' \
    '{"struct_type":"node","name":"b.txt","type":"file","path":"/h/b.txt","size":3,"mtime":"x"}' \
    '{"struct_type":"node","name":"A","type":"dir","path":"/h/A","mtime":"x"}' ;;
  *" snapshots "*) echo '[{"short_id":"aa","time":"2026-10-01T00:00:00Z","paths":["/h"]},{"short_id":"bb","time":"2026-10-02T00:00:00Z","paths":["/h"]}]' ;;
esac
EOF
cat >"$tmp/bin/notify-send" <<'EOF'
#!/bin/sh
echo "notify $*" >>"$TM_LOG"
EOF
# sftp batch output: the old rsync dir listing + df (KiB); FAKE_SFTP=empty = no rsync dirs, no df.
cat >"$tmp/bin/sftp" <<'EOF'
#!/bin/sh
[ "$FAKE_SFTP" = empty ] && exit 1
printf '%s\n' 'sftp> -ls -1 /x' '/x/fedora-home-backup-2026-09-28' '/x/restic' 'sftp> -df /x/restic' \
  '        Size         Used        Avail       (root)    %Capacity' '        1000          400          600          600          40%'
EOF
# The SFTP reachability probe (`timeout 5 bash -c "</dev/tcp/…"`) succeeds unless FAKE_OFFLINE is set;
# every other timeout call just runs its command.
cat >"$tmp/bin/timeout" <<'EOF'
#!/bin/sh
case "$*" in */dev/tcp/*) [ -z "$FAKE_OFFLINE" ] ;; *) shift; exec "$@" ;; esac
EOF
chmod +x "$tmp/bin"/*
echo pw >"$tmp/cfg/asahi-timemachine/password"
printf '%s\n' 'TM_SFTP=nobody@127.0.0.1' 'TM_SFTP_PATH=/x/restic' 'TM_LABEL=asahi-tm-test-nolabel' >"$tmp/cfg/asahi-timemachine/config"

tm() {
  HOME="$tmp/home" PATH="$tmp/bin:$PATH" TM_LOG="$tmp/restic.log" XDG_CONFIG_HOME="$tmp/cfg" XDG_STATE_HOME="$tmp/state" "$TM" "$@"
}
state="$tmp/state/asahi/timemachine.json"

if bash -n "$TM"; then pass "bash -n"; else fail_at "bash -n"; fi

: >"$tmp/restic.log"
FAKE_OFFLINE=1 tm run --force >/dev/null
if [ "$(jq -r .state "$state")" = offline ] && ! grep -q "^restic" "$tmp/restic.log"; then
  pass "no drive, host unreachable → offline, no restic"
else
  fail_at "offline: $(cat "$state") / $(cat "$tmp/restic.log")"
fi

echo '{"state":"ok","last_success":"'"$(date -u -d '-2 days' +%FT%TZ)"'"}' >"$state"
tm run >/dev/null
if [ "$(jq -r .state "$state")" = ok ]; then
  pass "timer run skips when last success < 3 days"
else
  fail_at "recent skip: $(cat "$state")"
fi
echo '{"state":"ok","last_success":"'"$(date -u -d '-4 days' +%FT%TZ)"'"}' >"$state"
FAKE_OFFLINE=1 tm run >/dev/null
if [ "$(jq -r .state "$state")" = offline ]; then
  pass "timer run tries when last success > 3 days"
else
  fail_at "recent skip: $(cat "$state")"
fi

echo '{"state":"running"}' >"$state"
if [ "$(tm status | jq -r '.state + " " + (.running | tostring) + " " + (.ready | tostring)')" = "interrupted false true" ]; then
  pass "stale running state → interrupted"
else
  fail_at "status: $(tm status)"
fi
rm -f "$state"
if [ "$(tm status | jq -r '.ready')" = true ] && [ ! -e "$state" ]; then
  pass "status without a state file: reads only"
else
  fail_at "status no state: $(tm status)"
fi

if [ "$(tm ls aa /h | jq -c 'map(.name)')" = '["A","b.txt"]' ]; then
  pass "ls: direct children, dirs first, no self"
else
  fail_at "ls: $(tm ls aa /h)"
fi

ov="$(tm overview)"
if [ "$(jq -c '[.snapshots[0].id, .legacy, .disk.avail]' <<<"$ov")" = '["bb",["fedora-home-backup-2026-09-28"],614400]' ]; then
  pass "overview: snapshots newest first, rsync dirs, drive space (one sftp session)"
else
  fail_at "overview: $ov"
fi
if [ "$(FAKE_SFTP=empty tm overview | jq -c '[.legacy, .disk]')" = '[[],null]' ]; then
  pass "overview: no rsync dirs / sftp error → [] and null, not a crash"
else
  fail_at "overview empty sftp: $(FAKE_SFTP=empty tm overview)"
fi

: >"$tmp/restic.log"
out="$(tm restore aa '/h/a[1].txt')"
if grep -qF -- '--include /h/a\[1\].txt' "$tmp/restic.log" && [ "$out" = "$tmp/home/Restored/2026-10-01-aa/h/a[1].txt" ]; then
  pass "restore: glob characters escaped, target under ~/Restored"
else
  fail_at "restore: $out / $(cat "$tmp/restic.log")"
fi

: >"$tmp/restic.log"
tm run --force >/dev/null
if [ "$(jq -r '.state + " " + (.overview.legacy | join(","))' "$state")" = "ok fedora-home-backup-2026-09-28" ] \
  && grep -q 'Backup started' "$tmp/restic.log" && grep -q 'Backup done' "$tmp/restic.log" \
  && grep -q 'forget .*--prune' "$tmp/restic.log"; then
  pass "run: ok state, legacy list, start/done notifications, first run prunes"
else
  fail_at "run: $(cat "$state") / $(cat "$tmp/restic.log")"
fi
: >"$tmp/restic.log"
tm run --force >/dev/null
if grep -q 'forget' "$tmp/restic.log" && ! grep -q -- '--prune' "$tmp/restic.log"; then
  pass "prune at most weekly"
else
  fail_at "prune: $(cat "$tmp/restic.log")"
fi

before="$(jq -r .last_success "$state")"
sleep 1
FAKE_FAIL=forget tm run --force >/dev/null
if [ "$(jq -r .state "$state")" = ok ] && [ "$(jq -r .last_success "$state")" != "$before" ]; then
  pass "forget failing (lock) keeps the saved snapshot ok"
else
  fail_at "forget fail: $(cat "$state")"
fi

: >"$tmp/restic.log"
rc=0
FAKE_FAIL=backup tm run --force >/dev/null || rc=$?
if [ "$rc" = 1 ] && [ "$(jq -r '.state + " " + .error' "$state")" = "failed restic exited 1" ] \
  && grep -q 'notify .*-u critical Backup failed' "$tmp/restic.log"; then
  pass "backup failing with empty stderr → failed state, exit code, critical notification"
else
  fail_at "backup fail: rc=$rc $(cat "$state") / $(cat "$tmp/restic.log")"
fi

if [ "$fail" -ne 0 ]; then
  echo "failed"
  exit 1
fi
echo "all passed"
