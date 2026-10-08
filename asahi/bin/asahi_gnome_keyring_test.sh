#!/usr/bin/env bash
# The startup script must not plant a keyring, and the login PAM stack gets
# exactly the two pam_gnome_keyring lines, once, auth after postlogin.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
fail=0
pass() { printf 'ok  %s\n' "$1"; }
fail_at() { printf 'FAIL %s\n' "$1" >&2; fail=1; }

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

# Stubs: do not start the real daemon or kill ksecretd.
mkdir -p "$tmp/bin"
printf '#!/bin/sh\nexit 0\n' >"$tmp/bin/systemctl"
printf '#!/bin/sh\nexit 1\n' >"$tmp/bin/pgrep"
chmod +x "$tmp/bin/systemctl" "$tmp/bin/pgrep"
PATH="$tmp/bin:$PATH" XDG_DATA_HOME="$tmp" "$ROOT/asahi-gnome-keyring" || true
if compgen -G "$tmp/keyrings/*" >/dev/null; then
  fail_at "startup script planted a keyring"
else
  pass "startup script does not seed a keyring"
fi

pam="$tmp/login"
cat >"$pam" <<'EOF'
#%PAM-1.0
auth       substack     system-auth
auth       include      postlogin
account    required     pam_nologin.so
session    include      system-auth
session    include      postlogin
EOF
"$ROOT/asahi-keyring-pam" "$pam"
"$ROOT/asahi-keyring-pam" "$pam"
expected='#%PAM-1.0
auth       substack     system-auth
auth       include      postlogin
auth       optional     pam_gnome_keyring.so
account    required     pam_nologin.so
session    include      system-auth
session    include      postlogin
session    optional     pam_gnome_keyring.so auto_start'
[ "$(cat "$pam")" = "$expected" ] && pass "PAM lines inserted once, auth after postlogin" || fail_at "PAM file: $(cat "$pam")"

printf '%s\n' 'auth       substack     system-auth' >"$pam"
"$ROOT/asahi-keyring-pam" "$pam" 2>/dev/null && fail_at "no postlogin should fail" || pass "no postlogin fails loudly"

[ "$fail" = 0 ]
