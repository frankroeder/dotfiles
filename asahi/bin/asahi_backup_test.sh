#!/usr/bin/env bash
# Smoke tests for asahi-backup dest writes. No live USB, no real sudo.

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BK="$ROOT/asahi-backup"
fail=0
pass() { printf 'ok  %s\n' "$1"; }
fail_at() { printf 'FAIL %s\n' "$1"; fail=1; }

chmod +x "$BK"

if bash -n "$BK"; then
  pass "bash -n"
else
  fail_at "bash -n (unmatched quote?)"
fi

if grep -q '/dev/sda1' "$BK"; then
  fail_at "sda1 fallback still present"
else
  pass "no sda1 fallback"
fi

if "$BK" --help >/dev/null; then
  pass "help"
else
  fail_at "help"
fi

if grep -F -q 'as_dest mkdir -p "$dest"' "$BK"; then
  pass "dest mkdir goes through as_dest"
else
  fail_at "dest mkdir does not use as_dest"
fi

if grep -E '^[[:space:]]*mkdir -p "\$dest"' "$BK"; then
  fail_at "bare mkdir -p dest still present"
else
  pass "no bare mkdir dest"
fi

tmp=$(mktemp -d)
cleanup() { rm -rf "$tmp" || true; }
trap cleanup EXIT

bin="$tmp/bin"
mkdir -p "$bin"
sudo_log="$tmp/sudo.log"

cat >"$bin/udisksctl" <<'EOF'
#!/bin/sh
echo "udisksctl stub should not run" >&2
exit 1
EOF

cat >"$bin/rsync" <<'EOF'
#!/bin/bash
logf=
dry=0
src=
dst=
for a in "$@"; do
  case "$a" in
    --log-file=*) logf="${a#--log-file=}" ;;
    --dry-run) dry=1 ;;
    --*) ;;
    *)
      src=$dst
      dst=$a
      ;;
  esac
done
if [ -n "$logf" ]; then
  printf '%s\n' "Number of files: 1" "Total file size: 1" >"$logf"
fi
(( dry )) && exit 0
mkdir -p "$dst"
printf 'stub\n' >"${dst}/.rsync-stub"
exit 0
EOF

cat >"$bin/sudo" <<EOF
#!/bin/bash
printf '%s\n' "\$*" >>"$sudo_log"
cmd="\$1"
shift
case "\$cmd" in
  mkdir|ln|cp)
    if [ -n "\${UNWRITABLE_MOUNT:-}" ]; then
      chmod u+w "\$UNWRITABLE_MOUNT"
    fi
    "\$cmd" "\$@"
    rc=\$?
    if [ -n "\${UNWRITABLE_MOUNT:-}" ]; then
      chmod a-w,u+rx "\$UNWRITABLE_MOUNT" 2>/dev/null || true
    fi
    exit \$rc
    ;;
esac
export PATH="$bin:\$PATH"
exec "\$cmd" "\$@"
EOF
chmod +x "$bin"/*

run_backup() {
  local vol="$1" src="$2" logs="$3"
  shift 3
  : >"$sudo_log"
  PATH="$bin:$PATH" \
    ASAHI_BACKUP_MOUNT="$vol" \
    ASAHI_BACKUP_SOURCE="$src/" \
    ASAHI_BACKUP_LOG_DIR="$logs" \
    ASAHI_BACKUP_LABEL=LinuxDrive \
    "$BK" "$@"
}

stamp="$(date +%Y-%m-%d)"
src="$tmp/src"
mkdir -p "$src/u"
printf 'hi\n' >"$src/u/f"

# Writable volume: dest ops as the user, rsync still via sudo.
vol="$tmp/vol-rw"
logs="$tmp/logs-rw"
mkdir -p "$vol" "$logs"
if run_backup "$vol" "$src" "$logs"; then
  pass "writable backup exits 0"
else
  fail_at "writable backup failed"
fi
dest="$vol/fedora-home-backup-${stamp}"
if [ -d "$dest" ] && [ -L "$vol/fedora-home-backup-latest" ]; then
  pass "writable backup created dest + latest"
else
  fail_at "writable dest/latest missing: $(ls -la "$vol")"
fi
if grep -q '^mkdir ' "$sudo_log"; then
  fail_at "writable volume used sudo mkdir: $(cat "$sudo_log")"
else
  pass "writable volume did not sudo mkdir"
fi
if grep -q '^rsync ' "$sudo_log"; then
  pass "rsync still via sudo"
else
  fail_at "rsync did not go through sudo: $(cat "$sudo_log")"
fi
if grep -q -- '--exclude=Nextcloud' "$sudo_log"; then
  pass "rsync excludes Nextcloud"
else
  fail_at "rsync missing Nextcloud exclude: $(cat "$sudo_log")"
fi

# Dry-run on a root-style unwritable volume must not mkdir (the original crash).
vol="$tmp/vol-ro"
logs="$tmp/logs-ro"
mkdir -p "$vol" "$logs"
chmod a-w "$vol"
export UNWRITABLE_MOUNT="$vol"
if run_backup "$vol" "$src" "$logs" --dry-run; then
  pass "unwritable dry-run exits 0"
else
  fail_at "unwritable dry-run failed"
fi
if [ -e "$vol/fedora-home-backup-${stamp}" ]; then
  fail_at "dry-run created dest on unwritable volume"
else
  pass "dry-run did not mkdir dest"
fi
if grep -q '^mkdir ' "$sudo_log"; then
  fail_at "dry-run sudo mkdir: $(cat "$sudo_log")"
else
  pass "dry-run did not sudo mkdir"
fi

# Real backup on unwritable volume: dest ops via sudo.
logs="$tmp/logs-ro2"
mkdir -p "$logs"
if run_backup "$vol" "$src" "$logs"; then
  pass "unwritable backup exits 0"
else
  fail_at "unwritable backup failed"
fi
chmod u+w "$vol"
if [ -d "$vol/fedora-home-backup-${stamp}" ] && [ -L "$vol/fedora-home-backup-latest" ]; then
  pass "unwritable backup created dest + latest via sudo"
else
  fail_at "unwritable dest/latest missing: $(ls -la "$vol")"
fi
if grep -q '^mkdir -p ' "$sudo_log"; then
  pass "unwritable volume used sudo mkdir"
else
  fail_at "unwritable volume skipped sudo mkdir: $(cat "$sudo_log")"
fi
unset UNWRITABLE_MOUNT

if [ "$fail" -ne 0 ]; then
  echo "$fail failed"
  exit 1
fi
echo "all passed"
