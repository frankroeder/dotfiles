#!/usr/bin/env sh

set -eu

# setup script for eduroam

CON_NAME="eduroam"

if [ "$#" -ne 1 ]; then
  echo "Usage: $0 <username>" >&2
  exit 1
fi

UN="$1"

sudo wget -O /etc/ssl/certs/dfn-verein_community_root_ca_2022.pem \
  https://doku.tid.dfn.de/_media/de:dfnpki:ca:dfn-verein_community_root_ca_2022.pem

if nmcli connection show "$CON_NAME" >/dev/null 2>&1; then
  nmcli connection delete "$CON_NAME"
fi

nmcli connection add type wifi \
  con-name "$CON_NAME" \
  ifname "*" \
  ssid "eduroam" \
  wifi-sec.key-mgmt wpa-eap \
  802-1x.eap ttls \
  802-1x.phase2-auth pap \
  802-1x.identity "$UN" \
  802-1x.anonymous-identity "eduroam@tuhh.de" \
  802-1x.ca-cert "/etc/ssl/certs/dfn-verein_community_root_ca_2022.pem" \
  802-1x.domain-suffix-match "rz.tuhh.de"
