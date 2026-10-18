#!/usr/bin/env bash
# asahi-storage-mounts against fake findmnt / lsblk: one entry per maj:min (btrfs subvolumes merge, same-named FUSE
# mounts do not), pseudo and /run mounts drop, label / compression / disk model, df-style percent, read-only,
# readable mount point (checked on the real filesystem: / is, a missing /srv/a is not), sorted.

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
fail=0
pass() { printf 'ok  %s\n' "$1"; }
fail_at() { printf 'FAIL %s\n' "$1"; fail=1; }

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
mkdir -p "$tmp/bin"
cat >"$tmp/bin/findmnt" <<'EOF'
#!/usr/bin/env bash
cat <<'JSON'
{"filesystems": [
  {"source": "/dev/nvme0n1p6", "fstype": "btrfs", "size": 1000, "used": 580, "avail": 400, "target": "/home",
   "label": "fedora", "options": "rw,compress=zstd:1,ssd,subvol=/home", "maj:min": "0:37"},
  {"source": "/dev/nvme0n1p5", "fstype": "ext4", "size": 100, "used": 75, "avail": 25, "target": "/boot", "label": null,
   "options": "rw,relatime", "maj:min": "259:5"},
  {"source": "/dev/nvme0n1p6", "fstype": "btrfs", "size": 1000, "used": 580, "avail": 400, "target": "/",
   "label": "fedora", "options": "rw,compress=zstd:1,ssd,subvol=/root", "maj:min": "0:37"},
  {"source": "fuse-overlayfs", "fstype": "fuse.fuse-overlayfs", "size": 10, "used": 1, "avail": 9, "target": "/srv/a",
   "label": null, "options": "rw", "maj:min": "0:60"},
  {"source": "fuse-overlayfs", "fstype": "fuse.fuse-overlayfs", "size": 20, "used": 2, "avail": 18, "target": "/srv/b",
   "label": null, "options": "ro,relatime", "maj:min": "0:61"},
  {"source": "tmpfs", "fstype": "tmpfs", "size": 10, "used": 1, "avail": 9, "target": "/tmp", "label": null, "options": "rw",
   "maj:min": "0:30"},
  {"source": "/dev/sdb1", "fstype": "vfat", "size": 10, "used": 1, "avail": 9, "target": "/run/media/u/STICK",
   "label": "STICK", "options": "rw", "maj:min": "8:17"}
]}
JSON
EOF
cat >"$tmp/bin/lsblk" <<'EOF'
#!/usr/bin/env bash
echo '{"blockdevices": [{"path": "/dev/nvme0n1", "pkname": null, "model": "APPLE SSD AP1024Z  "},
  {"path": "/dev/nvme0n1p5", "pkname": "nvme0n1", "model": null}, {"path": "/dev/nvme0n1p6", "pkname": "nvme0n1", "model": null}]}'
EOF
chmod +x "$tmp/bin/findmnt" "$tmp/bin/lsblk"
export PATH="$tmp/bin:$PATH"

out=$("$ROOT/asahi-storage-mounts")
[ "$(jq -c 'map(.mounts[0])' <<<"$out")" = '["/","/boot","/srv/a","/srv/b"]' ] &&
  pass "tmpfs and /run dropped, same-named FUSE kept apart, sorted" || fail_at "entries ($out)"
root=$(jq -c '.[0]' <<<"$out")
[ "$(jq -c .mounts <<<"$root")" = '["/","/home"]' ] && pass "subvolumes merge, / first" || fail_at "merge ($root)"
[ "$(jq -r '[.label, .fstype, .compress, .model] | join("|")' <<<"$root")" = 'fedora|btrfs|zstd:1|APPLE SSD AP1024Z' ] &&
  pass "label, compression, trimmed model" || fail_at "details ($root)"
[ "$(jq .pct <<<"$root")" = 60 ] && pass "pct = ceil(used / (used + avail))" || fail_at "pct ($root)"
[ "$(jq -c 'map([.ro, .readable])' <<<"$out")" = '[[false,true],[false,true],[false,false],[true,false]]' ] &&
  pass "ro flag, readable mount points" || fail_at "ro / readable ($out)"
boot=$(jq -c '.[1]' <<<"$out")
[ "$(jq -r '[.label, .compress, .pct] | join("|")' <<<"$boot")" = '||75' ] && pass "no label / compression = empty" || fail_at "boot ($boot)"

if [ "$fail" -ne 0 ]; then
  echo "asahi_storage_mounts_test.sh: FAILED"
  exit 1
fi
echo "asahi_storage_mounts_test.sh: all ok"
