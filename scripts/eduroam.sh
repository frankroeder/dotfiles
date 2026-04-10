#!/usr/bin/env sh

# setup script for eduroam

UN="$1"

if [ -z "$UN" ]; then
  echo "Usage: $0 <username>"
  exit 1
fi

sudo wget -O /etc/ssl/certs/dfn-verein_community_root_ca_2022.pem \
  https://doku.tid.dfn.de/_media/de:dfnpki:ca:dfn-verein_community_root_ca_2022.pem

nmcli connection add type wifi \
  con-name "eduroam" \
  ifname "*" \
  ssid "eduroam" \
  wifi-sec.key-mgmt wpa-eap \
  802-1x.eap ttls \
  802-1x.phase2-auth pap \
  802-1x.identity "$UN" \
  802-1x.anonymous-identity "eduroam@tuhh.de" \
  802-1x.ca-cert "/etc/ssl/certs/dfn-verein_community_root_ca_2022.pem" \
  802-1x.domain-suffix-match "rz.tuhh.de"
