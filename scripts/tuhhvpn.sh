#!/usr/bin/env sh

set -eu

# setup script for TUHH-VPN

CON_NAME="TUHH-VPN"

if [ "$#" -ne 1 ]; then
  echo "Usage: $0 <username>" >&2
  exit 1
fi

UN="$1"

sudo wget -O /etc/ssl/certs/GlobalRoot_Class_2.crt https://corporate-pki.telekom.de/crt/GlobalRoot_Class_2.crt

if nmcli connection show "$CON_NAME" >/dev/null 2>&1; then
  nmcli connection delete "$CON_NAME"
fi

nmcli connection add type vpn \
  con-name "$CON_NAME" \
  vpn.service-type org.freedesktop.NetworkManager.openconnect \
  vpn.data "gateway=any1.rz.tuhh.de,protocol=anyconnect,cacert=/etc/ssl/certs/GlobalRoot_Class_2.crt,cookie-flags=2,password-flags=0" \
  vpn.user-name "$UN"
