#!/usr/bin/env bash
# Wi-Fi QR: nopass when key-mgmt is missing, PSK stays off qrencode's argv, mode 600.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
QR="$ROOT/asahi-wifi-qr"
fail=0
pass() { printf 'ok  %s\n' "$1"; }
fail_at() { printf 'FAIL %s\n' "$1"; fail=1; }

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
export ASAHI_WIFI_QR_TEST_DIR="$tmp"

cat >"$tmp/nmcli" <<'EOF'
#!/bin/sh
printf '%s\n' "$*" >> "$ASAHI_WIFI_QR_TEST_DIR/nmcli.log"
case "$*" in
  *"connection show --active"*)
    printf '%s\n' 'Cafe:802-11-wireless'
    ;;
  *"802-11-wireless.ssid"*)
    printf '%s\n' 'Cafe'
    ;;
  *"key-mgmt"*)
    if [ -f "$ASAHI_WIFI_QR_TEST_DIR/keymgmt_fail" ]; then
      exit 10
    fi
    cat "$ASAHI_WIFI_QR_TEST_DIR/keymgmt"
    ;;
  *"wireless-security.psk"*)
    printf '%s\n' 'super secret'
    ;;
  *) exit 1 ;;
esac
EOF

cat >"$tmp/qrencode" <<'EOF'
#!/bin/sh
printf '%s\n' "$*" > "$ASAHI_WIFI_QR_TEST_DIR/argv"
cat > "$ASAHI_WIFI_QR_TEST_DIR/payload"
out=""
prev=""
for a in "$@"; do
  if [ "$prev" = "-o" ]; then
    out=$a
  fi
  prev=$a
done
: >"$out"
chmod 644 "$out"
EOF
chmod +x "$tmp/nmcli" "$tmp/qrencode" "$QR"

run() {
  PATH="$tmp:$PATH" XDG_RUNTIME_DIR="$tmp/run" "$QR"
}

mkdir -p "$tmp/run"
: >"$tmp/keymgmt_fail"
out=$(run)
payload=$(cat "$tmp/payload")
mode=$(stat -c %a "$out")
[ "$payload" = "WIFI:T:nopass;S:Cafe;P:;;" ] && pass "missing key-mgmt is nopass" || fail_at "nopass payload=$payload"
[ "$mode" = "600" ] && pass "png is 600 after qrencode left it 644" || fail_at "mode=$mode"
grep -q 'super secret' "$tmp/argv" && fail_at "secret in argv" || pass "nopass argv has no secret"

rm -f "$tmp/keymgmt_fail"
printf '%s\n' 'wpa-psk' >"$tmp/keymgmt"
out=$(run)
payload=$(cat "$tmp/payload")
argv=$(cat "$tmp/argv")
[ "$payload" = "WIFI:T:WPA;S:Cafe;P:super secret;;" ] && pass "psk is in the payload" || fail_at "wpa payload=$payload"
case "$argv" in
  *secret*) fail_at "psk leaked into argv: $argv" ;;
  *) pass "psk is not in qrencode argv" ;;
esac
[ "$(stat -c %a "$out")" = "600" ] && pass "wpa png is 600" || fail_at "wpa mode"

printf '%s\n' 'wpa-eap' >"$tmp/keymgmt"
if PATH="$tmp:$PATH" XDG_RUNTIME_DIR="$tmp/run" "$QR" >/dev/null 2>"$tmp/err"; then
  fail_at "enterprise should fail"
else
  pass "enterprise has no shareable PSK"
fi

if [ "$fail" -ne 0 ]; then
  exit 1
fi
echo "all ok"
