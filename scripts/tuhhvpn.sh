#!/usr/bin/env sh

# setup script for TUHH-VPN

UN="$1"

if [ -z "$UN" ]; then
  echo "Usage: $0 <username>"
  exit 1
fi

sudo wget -O /etc/ssl/certs/GlobalRoot_Class_2.crt https://corporate-pki.telekom.de/crt/GlobalRoot_Class_2.crt

nmcli connection add type vpn \
  con-name "TUHH-VPN" \
  vpn.service-type org.freedesktop.NetworkManager.openconnect \
  vpn.data "gateway=any1.rz.tuhh.de,protocol=anyconnect,cacert=/etc/ssl/certs/GlobalRoot_Class_2.crt,cookie-flags=2,password-flags=0" \
  vpn.user-name "$UN"
