#!/usr/bin/env bash
# install/components.sh Asahi steps with sudo / systemctl / firewall-cmd faked as shell functions: the commands a real
# `make aurora` would run (no root needed, nothing on the system changes).
set -u
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
fail=0
pass() { printf 'ok  %s\n' "$1"; }
fail_at() { printf 'FAIL %s\n' "$1"; fail=1; }
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
calls=$tmp/calls

# sshd + firewalld: masks the generated AF_UNIX listener, drops ssh, opens LocalSend in the home zone only.
(
  DOTFILES=$ROOT
  . "$ROOT/install/common.sh"
  . "$ROOT/install/components.sh"
  NOSUDO=""
  sudo() { echo "$*" >>"$calls"; [ "$1" = firewall-cmd ] && return 0; return 0; }
  systemctl() { [ "$1" = is-enabled ] && echo masked; return 0; }
  comp_asahi_sshd >/dev/null 2>&1
) || fail_at "comp_asahi_sshd exited non-zero"
want=(
  "systemctl disable --now sshd.service sshd.socket"
  "systemctl mask sshd.service sshd.socket"
  "systemctl mask --now sshd-unix-local.socket"
  "firewall-cmd -q --permanent --remove-service=ssh"
  "firewall-cmd -q --permanent --zone=home --add-port=53317/tcp --add-port=53317/udp"
)
for w in "${want[@]}"; do
  grep -qxF "$w" "$calls" && pass "asahi-sshd runs: $w" || fail_at "asahi-sshd missing: $w ($(tr '\n' '|' <"$calls"))"
done
grep -q -- "--zone=public.*53317\|--add-port=53317/tcp\$" "$calls" && fail_at "LocalSend port outside the home zone" ||
  pass "LocalSend port only in the home zone"
[ "$(grep -c '^firewall-cmd -q --reload$' "$calls")" -ge 1 ] && pass "firewalld reloaded" || fail_at "no firewall reload"

# A failing firewall-cmd --state (no firewalld) skips the port step instead of failing the install.
: >"$calls"
(
  DOTFILES=$ROOT
  . "$ROOT/install/common.sh"
  . "$ROOT/install/components.sh"
  NOSUDO=""
  sudo() { echo "$*" >>"$calls"; [ "$1" = firewall-cmd ] && return 1; return 0; }
  systemctl() { [ "$1" = is-enabled ] && echo masked; return 0; }
  comp_asahi_sshd >/dev/null 2>&1
) && pass "no firewalld: sshd step still succeeds" || fail_at "no firewalld: sshd step failed"
grep -q "add-port" "$calls" && fail_at "no firewalld: still tried to add ports" || pass "no firewalld: no port step"


# Touch ID step (on this Aurora Mac's real os-release / device tree; sudo, fprintd, authselect, aurora-fido faked).
cat >"$tmp/touchid_case.sh" <<CASE
DOTFILES=$ROOT
. "$ROOT/install/common.sh"
. "$ROOT/install/components.sh"
NOSUDO=""
sudo() { echo "sudo \$*" >>"$calls"; return 0; }
authselect() { echo "local with-fingerprint"; }
fprintd-list() { [ "\$CASE" = enrolled ] && echo " - #0: right-index-finger"; return 0; }
fprintd-enroll() { echo "enroll \$*" >>"$calls"; return 1; }
systemctl() { echo enabled; }
aurora-fido() { echo "Touch ID security key: ON (service active, enabled at boot)"; }
comp_asahi_touchid
echo "rc=\$?"
CASE
touchid() { CASE=$1 bash "$tmp/touchid_case.sh" 2>&1 | sed 's/\x1b\[[0-9;]*m//g'; }
: >"$calls"
if [ -e /proc/device-tree/aliases/sep ] && compgen -G '/proc/device-tree/soc/*/fingerprint@*' >/dev/null; then
  a=$(touchid enrolled </dev/null); b=$(touchid none </dev/null)
  c=$(CASE=none uv run --no-project python -c 'import pty, sys; pty.spawn(["bash", sys.argv[1]])' "$tmp/touchid_case.sh" 2>&1 |
    sed 's/\x1b\[[0-9;]*m//g' | tr -d '\r')
  if [[ $a == *"1 finger(s) enrolled"* && $a == *"rc=0"* && $a != *"Touch ID security key: Touch ID"* &&
    $b == *"no finger enrolled"* && $b == *"rc=0"* && $c == *"fprintd-enroll failed: rerun"* && $c == *"rc=0"* ]] &&
    grep -q "^enroll -f right-index-finger" "$calls" && grep -q "^sudo aurora-touchid-setup" "$calls"; then
    pass "asahi-touchid: enrolled / no finger (no tty) / failed enrol on a tty all continue the install"
  else
    fail_at "asahi-touchid: [$a] [$b] [$c]"
  fi
else
  pass "asahi-touchid: skipped (no Aurora Touch ID sensor here)"
fi
[ "$fail" -eq 0 ] && echo "all passed" || exit 1
