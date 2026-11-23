#!/usr/bin/env bash
# asahi-vpn-info against fake nmcli / ip / resolvectl: no tunnel, Proton with kill switch, TUHH split tunnel,
# hostile resolver text, a kill switch profile that is down, the tunnel carrying the route wins.

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
fail=0
pass() { printf 'ok  %s\n' "$1"; }
fail_at() { printf 'FAIL %s\n' "$1"; fail=1; }

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
mkdir -p "$tmp/bin"
cat >"$tmp/bin/nmcli" <<'EOF'
#!/usr/bin/env bash
case "$*" in
  "-t -f DEVICE,TYPE,STATE dev status") cat "$FAKE_DIR/dev" ;;
  "-t -f NAME,ACTIVE connection show") cat "$FAKE_DIR/conns" ;;
  *) exit 1 ;;
esac
EOF
cat >"$tmp/bin/ip" <<'EOF'
#!/usr/bin/env bash
case "$*" in
  "route get 1.1.1.1") printf '1.1.1.1 dev %s table 51820 src 10.2.0.2 uid 1000 \n    cache \n' "$FAKE_ROUTE" ;;
  "-o link show dev "*) printf '7: %s: <POINTOPOINT,NOARP,UP,LOWER_UP> mtu %s qdisc noqueue state UNKNOWN\n' "${!#}" "$FAKE_MTU" ;;
  *) exit 1 ;;
esac
EOF
cat >"$tmp/bin/resolvectl" <<'EOF'
#!/usr/bin/env bash
[ "$1" = dns ] && [ "$2" = "$FAKE_DNS_IFACE" ] && cat "$FAKE_DIR/dns"
EOF
chmod +x "$tmp/bin/"*
export PATH="$tmp/bin:$PATH" FAKE_DIR="$tmp" FAKE_ROUTE=wld0 FAKE_MTU=1500 FAKE_DNS_IFACE=none

check() {
  local msg="$1" expected="$2" got
  got=$("$ROOT/asahi-vpn-info")
  if [ "$got" = "$expected" ]; then pass "$msg"; else fail_at "$msg got=$got expected=$expected"; fi
}

printf '%s\n' 'wld0:wifi:connected' 'lo:loopback:connected (externally)' >"$tmp/dev"
: >"$tmp/conns"
: >"$tmp/dns"
check "no tunnel" '{"up":false}'

printf '%s\n' 'wld0:wifi:connected' 'proton0:wireguard:connected' 'pvpnksintrf0:dummy:connected' >"$tmp/dev"
printf '%s\n' 'ALBUKK:yes' 'ProtonVPN DE#209:yes' 'pvpn-killswitch:yes' 'pvpn-killswitch-ipv6:yes' >"$tmp/conns"
echo 'Link 7 (proton0): 10.2.0.1' >"$tmp/dns"
FAKE_ROUTE=proton0 FAKE_MTU=1420 FAKE_DNS_IFACE=proton0 \
  check "Proton: kill switch on, routed, DNS, MTU" \
  '{"up":true,"iface":"proton0","killswitch":"on","routed":true,"dns":["10.2.0.1"],"mtu":1420}'

printf '%s\n' 'wld0:wifi:connected' 'vpn0:tun:connected (externally)' >"$tmp/dev"
printf '%s\n' 'ALBUKK:yes' 'TUHH-VPN:yes' 'vpn0:yes' 'pvpn-killswitch-ipv6:no' >"$tmp/conns"
printf '%s\n' 'Link 9 (vpn0): 134.28.0.10 134.28.0.11' '        2001:638:404:1::53' >"$tmp/dns"
FAKE_MTU=1406 FAKE_DNS_IFACE=vpn0 \
  check "TUHH split tunnel: no kill switch, wrapped DNS list" \
  '{"up":true,"iface":"vpn0","killswitch":"","routed":false,"dns":["134.28.0.10","134.28.0.11","2001:638:404:1::53"],"mtu":1406}'

printf '%s\n' 'Link 9 (vpn0): <img src=http://x/> 10.0.0.1#dns.example 1.1.1.1 ; rm' >"$tmp/dns"
printf '%s\n' 'pvpn-routed-killswitch:no' >"$tmp/conns"
FAKE_MTU=junk FAKE_DNS_IFACE=vpn0 \
  check "address-like DNS only, kill switch down = off, bad MTU = 0" \
  '{"up":true,"iface":"vpn0","killswitch":"off","routed":false,"dns":["10.0.0.1#dns.example","1.1.1.1"],"mtu":0}'

printf '%s\n' 'vpn0:tun:connected (externally)' 'proton0:wireguard:connected' 'wg1:wireguard:disconnected' >"$tmp/dev"
: >"$tmp/dns"
FAKE_ROUTE=proton0 FAKE_MTU=1420 \
  check "two tunnels: the one carrying the default route" \
  '{"up":true,"iface":"proton0","killswitch":"off","routed":true,"dns":[],"mtu":1420}'

if [ "$fail" -ne 0 ]; then
  echo "asahi_vpn_info_test.sh: FAILED"
  exit 1
fi
echo "asahi_vpn_info_test.sh: all ok"
