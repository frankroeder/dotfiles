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
# FAKE_FAIL=<subcommand>: that restic subcommand exits ${FAKE_RC:-1}, printing $FAKE_ERR (default: nothing,
# e.g. SIGKILL / OOM). Restore creates the --include path under --target unless FAKE_RESTORE_EMPTY is set.
cat >"$tmp/bin/restic" <<'EOF'
#!/bin/bash
echo "restic $*" >>"$TM_LOG"
case "$*" in *" $FAKE_FAIL "*) [ -n "$FAKE_FAIL" ] && { [ -n "$FAKE_ERR" ] && echo "$FAKE_ERR" >&2; exit "${FAKE_RC:-1}"; } ;; esac
case "$*" in
  *" restore "*)
    [ -n "$FAKE_RESTORE_EMPTY" ] && exit 0
    while [ $# -gt 0 ]; do case "$1" in --include) inc="$2"; shift ;; --target) tgt="$2"; shift ;; esac; shift; done
    inc="$(printf '%s' "$inc" | sed 's/\\\(.\)/\1/g')"
    mkdir -p "$tgt$(dirname "$inc")" && touch "$tgt$inc" ;;
  *" stats "*) echo '{"total_size":500,"total_uncompressed_size":900}' ;;
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
rc=0
tm ls aa /nope >/dev/null || rc=$?
if [ "$rc" = 4 ]; then
  pass "ls: folder not in the snapshot → exit 4"
else
  fail_at "ls missing: rc=$rc"
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
if grep -qF -- '--include /h/a\[1\].txt' "$tmp/restic.log" && [ "$out" = "$tmp/home/Restored/2026-10-01-aa/h/a[1].txt" ] \
  && [ -e "$out" ] && [ "$(jq -r .last_restore "$state")" = "$out" ]; then
  pass "restore: glob characters escaped, target under ~/Restored, recorded as last_restore"
else
  fail_at "restore: $out / $(cat "$tmp/restic.log")"
fi
out2="$(tm restore aa '/h/a[1].txt')"
if [ "$out2" != "$out" ] && [ -e "$out2" ] && [ "${out2#"$tmp/home/Restored/2026-10-01-aa-"}" != "$out2" ]; then
  pass "restore: same path again → new folder, first copy untouched"
else
  fail_at "restore twice: $out2"
fi
rc=0
FAKE_RESTORE_EMPTY=1 tm restore bb '/h/x.txt' >/dev/null 2>&1 || rc=$?
if [ "$rc" = 1 ] && [ ! -e "$tmp/home/Restored/2026-10-01-bb" ] && grep -q 'notify .*Restore failed' "$tmp/restic.log"; then
  pass "restore: nothing matched → exit 1, empty folder removed, notification"
else
  fail_at "restore empty: rc=$rc $(ls "$tmp/home/Restored")"
fi

: >"$tmp/restic.log"
tm run --force >/dev/null
if [ "$(jq -r '.state + " " + (.overview.legacy | join(","))' "$state")" = "ok fedora-home-backup-2026-09-28" ] \
  && grep -q 'Backup started' "$tmp/restic.log" && grep -q 'Backup done' "$tmp/restic.log" \
  && grep -q 'forget .*--prune' "$tmp/restic.log" && grep -q 'restic .* unlock' "$tmp/restic.log" \
  && grep -q 'check --read-data-subset' "$tmp/restic.log" && [ "$(jq -c '[.repo.size, .last_run.unreadable, .housekeeping]' "$state")" = '[500,0,null]' ]; then
  pass "run: ok state, legacy list, start/done notifications, unlock, first run prunes + checks, repo size"
else
  fail_at "run: $(cat "$state") / $(cat "$tmp/restic.log")"
fi
: >"$tmp/restic.log"
tm run --force >/dev/null
if grep -q 'forget' "$tmp/restic.log" && ! grep -q -- '--prune' "$tmp/restic.log" && ! grep -q ' check ' "$tmp/restic.log"; then
  pass "prune at most weekly, check at most monthly"
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

: >"$tmp/restic.log"
rc=0
FAKE_FAIL=backup FAKE_RC=10 tm run --force >/dev/null 2>&1 || rc=$?
if [ "$rc" = 0 ] && [ "$(jq -r .state "$state")" = offline ] && ! grep -q 'critical' "$tmp/restic.log"; then
  pass "rc 10 (host up, drive on it missing) → offline, not failed"
else
  fail_at "rc 10: rc=$rc $(cat "$state")"
fi

# Timer runs below: make a backup due.
jq --arg t "$(date -u -d '-4 days' +%FT%TZ)" '.last_success = $t' "$state" >"$state.x" && mv "$state.x" "$state"
: >"$tmp/restic.log"
rc=0
FAKE_FAIL=backup FAKE_ERR='Fatal: failed to refresh lock in time' tm run >/dev/null 2>&1 || rc=$?
if [ "$rc" = 0 ] && [ "$(jq -r .state "$state")" = interrupted ] && ! grep -q 'notify' "$tmp/restic.log"; then
  pass "lid close mid-run (lock refresh) → interrupted, timer run silent"
else
  fail_at "interrupted: rc=$rc $(cat "$state") / $(cat "$tmp/restic.log")"
fi

: >"$tmp/restic.log"
FAKE_FAIL=backup FAKE_ERR='boom' tm run >/dev/null 2>&1 || true
FAKE_FAIL=backup FAKE_ERR='boom' tm run >/dev/null 2>&1 || true
if [ "$(grep -c 'critical Backup failed' "$tmp/restic.log")" = 1 ] && ! grep -q 'Backup started' "$tmp/restic.log"; then
  pass "same failure on hourly retries → one critical notification, no start notices"
else
  fail_at "notify once: $(cat "$tmp/restic.log")"
fi

: >"$tmp/restic.log"
jq --arg t "$(date -u -d '-11 days' +%FT%TZ)" '.state = "ok" | .last_success = $t | del(.warned, .overdue)' "$state" >"$state.x" && mv "$state.x" "$state"
FAKE_OFFLINE=1 tm run >/dev/null
FAKE_OFFLINE=1 tm run >/dev/null
if [ "$(jq -r .overdue "$state")" = true ] && [ "$(grep -c 'critical No backup for 10 days' "$tmp/restic.log")" = 1 ]; then
  pass "offline for > 10 days → overdue flag, one critical notification"
else
  fail_at "overdue: $(cat "$state") / $(cat "$tmp/restic.log")"
fi
tm run --force >/dev/null 2>&1
if [ "$(jq -r '.overdue // "cleared"' "$state")" = cleared ]; then
  pass "success clears overdue"
else
  fail_at "overdue clear: $(cat "$state")"
fi

jq '.housekeeping = true' "$state" >"$state.x" && mv "$state.x" "$state"
flock "$tmp/state/asahi/timemachine.lock" sleep 3 &
sleep 0.5
if [ "$(tm status | jq -c '[.running, .cleaning]')" = '[false,true]' ]; then
  pass "status: lock held after the snapshot → cleaning, not running"
else
  fail_at "cleaning: $(tm status | jq -c '[.running, .cleaning, .state]')"
fi
wait

if [ "$fail" -ne 0 ]; then
  echo "failed"
  exit 1
fi
echo "all passed"
