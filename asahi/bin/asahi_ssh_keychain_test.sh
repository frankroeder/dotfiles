#!/usr/bin/env bash
# Smoke tests for asahi-ssh-keychain stale-pidfile recovery. No live ssh-add.

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
KC="$ROOT/asahi-ssh-keychain"
fail=0
pass() { printf 'ok  %s\n' "$1"; }
fail_at() { printf 'FAIL %s\n' "$1"; fail=1; }

chmod +x "$KC"

if "$KC" --nope 2>/dev/null; then
  fail_at "bad flag should fail"
else
  pass "usage"
fi

if grep -q -- '--unlock' "$ROOT/../../zsh/zprofile" "$KC"; then
  fail_at "must not prompt for the SSH key on tty1 (--unlock)"
else
  pass "no tty1 key unlock"
fi

if grep -E -q '^[[:space:]]*export KEYCHAIN_DONE=1' "$ROOT/../../zsh/zshenv"; then
  pass "zshenv exports KEYCHAIN_DONE (skip Fedora profile.d/keychain.sh)"
else
  fail_at "zshenv must export KEYCHAIN_DONE=1 so Fedora does not unlock all ~/.ssh keys on tty1"
fi

if grep -v '^[[:space:]]*#' "$KC" | grep -q 'KEYCHAIN_DONE=1'; then
  pass "asahi-ssh-keychain exports KEYCHAIN_DONE"
else
  fail_at "asahi-ssh-keychain must export KEYCHAIN_DONE=1"
fi

if grep -v '^[[:space:]]*#' "$KC" | grep -q -- '--quick'; then
  fail_at "asahi-ssh-keychain must not pass --quick"
else
  pass "no --quick"
fi

if grep -v '^[[:space:]]*#' "$KC" | grep -q 'agent stop'; then
  fail_at "must not keychain agent stop (reused PID)"
else
  pass "does not agent stop"
fi

tmp=$(mktemp -d)
cleanup() { rm -rf "$tmp" || true; }
trap cleanup EXIT

bin="$tmp/bin"
dir="$tmp/keychain"
mkdir -p "$bin" "$dir"
log="$tmp/keychain.args"
host="testhost"
stale_sock="$dir/dead.s"
# Leftover unix socket with nothing listening (same shape as a post-reboot pidfile).
S="$stale_sock" python3 -c "import socket, os; p=os.environ['S'];
s=socket.socket(socket.AF_UNIX); s.bind(p); s.close()"
printf 'SSH_AUTH_SOCK=%s; export SSH_AUTH_SOCK\nSSH_AGENT_PID=%s; export SSH_AGENT_PID;\n' \
  "$stale_sock" "$$" >"$dir/${host}-sh"

cat >"$bin/keychain" <<EOF
#!/bin/sh
printf '%s\n' "\$@" >"$log"
echo "SSH_AUTH_SOCK=$tmp/live.s; export SSH_AUTH_SOCK"
echo "SSH_AGENT_PID=99999; export SSH_AGENT_PID;"
EOF
cat >"$bin/ssh-add" <<'EOF'
#!/bin/sh
exit 2
EOF
cat >"$bin/systemctl" <<'EOF'
#!/bin/sh
exit 0
EOF
cat >"$bin/dbus-update-activation-environment" <<'EOF'
#!/bin/sh
exit 0
EOF
chmod +x "$bin"/*

# This test process is not ssh-agent; the leftover socket is dead.
unset SSH_AUTH_SOCK SSH_AGENT_PID
PATH="$bin:$PATH" KEYCHAIN_DIR="$dir" KEYCHAIN_HOST="$host" "$KC"

if [ -f "$dir/${host}-sh" ]; then
  fail_at "stale pidfile should have been removed before keychain ran"
else
  pass "stale pidfile discarded"
fi
if [ -S "$stale_sock" ]; then
  fail_at "dead socket should have been removed"
else
  pass "dead socket discarded"
fi
if [ -d "/proc/$$" ]; then
  pass "did not kill the reused PID (this test process)"
else
  fail_at "reused PID was killed"
fi
if grep -q -- '--quick' "$log"; then
  fail_at "keychain invoked with --quick: $(cat "$log")"
else
  pass "keychain invocation has no --quick"
fi
if grep -q -- '--noask' "$log" && grep -q -- '--no-inherit' "$log"; then
  pass "default path is --noask --no-inherit"
else
  fail_at "default flags: $(cat "$log")"
fi

# Fedora's hook must not invoke keychain when KEYCHAIN_DONE is set.
if [ -r /etc/profile.d/keychain.sh ]; then
  fed_bin="$tmp/fed-bin"
  mkdir -p "$fed_bin"
  printf '%s\n' '#!/bin/sh' 'echo FEDORA_KEYCHAIN_RAN "$*" >&2' 'exit 1' >"$fed_bin/keychain"
  chmod +x "$fed_bin/keychain"
  fed_out=$(
    KEYCHAIN_DONE=1 PATH="$fed_bin:$PATH" HOME="$tmp" \
      bash -c '. /etc/profile.d/keychain.sh' 2>&1
  ) && fed_rc=0 || fed_rc=$?
  if [ "$fed_rc" -eq 0 ] && ! printf '%s' "$fed_out" | grep -q FEDORA_KEYCHAIN_RAN; then
    pass "Fedora profile.d/keychain.sh is a no-op when KEYCHAIN_DONE=1"
  else
    fail_at "Fedora keychain.sh still ran: rc=$fed_rc out=$fed_out"
  fi
fi

if [ "$fail" -ne 0 ]; then
  echo "asahi_ssh_keychain_test.sh: FAILED"
  exit 1
fi
echo "asahi_ssh_keychain_test.sh: all ok"
