#!/usr/bin/env bash
# Latest Grok Bot linux/arm64 RPM from Cursor's update API.
set -euo pipefail

if [ "$(uname -m)" != "aarch64" ]; then
  echo "Skipping Grok Bot RPM (linux/arm64 only; this host is $(uname -m))"
  exit 0
fi

api="https://api2.cursor.sh/updates/api/update/linux-arm64/sand/0.0.0/stable"
mapfile -t meta < <(curl -fsSL -A "Mozilla/5.0" "$api" | python3 -c '
import json, re, sys
data = json.load(sys.stdin)
ver = str(data.get("version") or data.get("productVersion") or "")
match = re.search(r"/(?:grokbot|sand)/stable/([0-9a-f]+)/", str(data.get("url") or ""))
if not ver or not match:
    sys.exit("could not parse grok-bot update metadata")
print(ver)
print("https://downloads.cursor.com/grokbot/stable/%s/linux/arm64/Grok_Bot_%s.rpm" % (match.group(1), ver))
')
ver="${meta[0]}"
url="${meta[1]}"

if [ "$(rpm -q --qf '%{VERSION}' grok-bot 2>/dev/null || true)" = "$ver" ]; then
  echo "Grok Bot ${ver} already installed"
  exit 0
fi

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
echo "Installing Grok Bot ${ver}"
curl -fL -A "Mozilla/5.0" -o "${tmp}/Grok_Bot_${ver}.rpm" "$url"
sudo dnf install -y "${tmp}/Grok_Bot_${ver}.rpm"
rpm -q grok-bot >/dev/null
