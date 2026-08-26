#!/usr/bin/env sh
# TUHH VPN via OpenConnect CLI — the path that works here.
# Official console command: sudo openconnect any1.rz.tuhh.de
#   https://www.tuhh.de/rzt/netze/vpn/anleitungen/ubuntu-linux
#
# --useragent=AnyConnect is required: the ASA 404s the config-auth XML
# POST unless User-Agent starts with AnyConnect. Fedora's system store
# already trusts the live GEANT/HARICA chain (leaf CN=any.rz.tuhh.de).
# Do not pass --cafile / --no-system-trust. NetworkManager-openconnect
# and vpnc are not used.

set -eu

GW="any1.rz.tuhh.de"
UA="AnyConnect"

if [ "${1:-}" = "-h" ] || [ "${1:-}" = "--help" ]; then
  echo "Usage: $0 [username] [openconnect-args...]" >&2
  exit 1
fi

if ! command -v openconnect >/dev/null 2>&1; then
  echo "openconnect is not installed (dnf install openconnect)" >&2
  exit 1
fi

if [ "$#" -ge 1 ] && [ "${1#-}" = "$1" ]; then
  user=$1
  shift
  exec sudo openconnect --useragent="$UA" -u "$user" "$GW" "$@"
fi

exec sudo openconnect --useragent="$UA" "$GW" "$@"
