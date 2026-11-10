#!/usr/bin/env bash
# asahi-boot-check with fake rpm / uname / pgrep / notify-send and a scratch /boot (ASAHI_BOOT_DIR).
set -u
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
fail=0
pass() { printf 'ok  %s\n' "$1"; }
fail_at() { printf 'FAIL %s\n' "$1"; fail=1; }
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
mkdir -p "$tmp/bin" "$tmp/boot"
old=7.3.0-26.fc45.aurora.aarch64 new=7.3.0-27.fc45.aurora.aarch64
cat >"$tmp/bin/rpm" <<SH
#!/bin/sh
[ -e "$tmp/installed" ] || exit 1
case "\$*" in *--quiet*) exit 0 ;; esac
printf '%s\n%s\n' "$new" "$old"
SH
printf '#!/bin/sh\ncat "%s/uname"\n' "$tmp" >"$tmp/bin/uname"
printf '#!/bin/sh\nexit 1\n' >"$tmp/bin/pgrep"
printf '#!/bin/sh\necho "$*" >>"%s/notes"\n' "$tmp" >"$tmp/bin/notify-send"
chmod +x "$tmp/bin/"*
check() { PATH="$tmp/bin:$PATH" ASAHI_BOOT_DIR="$tmp/boot" "$ROOT/asahi-boot-check" 2>&1; }

out=$(check); rc=$?
[ "$rc" -eq 0 ] && [ -z "$out" ] && pass "no kernel-aurora-core (Fedora Asahi): silent" || fail_at "no aurora kernel: rc=$rc [$out]"

: >"$tmp/installed"
echo "$new" >"$tmp/uname"
: >"$tmp/boot/vmlinuz-$new"
: >"$tmp/boot/initramfs-$new.img"
ln -s "dtb-$new" "$tmp/boot/dtb"
out=$(check); rc=$?
[ "$rc" -eq 0 ] && [[ $out == *"boot chain current ($new)"* ]] && pass "current chain" || fail_at "current: rc=$rc [$out]"

echo "$old" >"$tmp/uname"
out=$(check); rc=$?
[ "$rc" -eq 0 ] && [[ $out == "Restart needed: kernel $new" ]] && pass "new kernel installed: restart needed" || fail_at "restart: rc=$rc [$out]"

rm "$tmp/boot/vmlinuz-$new"
out=$(check); rc=$?
[ "$rc" -eq 1 ] && [[ $out == *"kernel $new has no $tmp/boot image"* ]] && grep -q critical "$tmp/notes" &&
  pass "aborted kernel-install (no image): critical" || fail_at "no image: rc=$rc [$out]"

: >"$tmp/boot/vmlinuz-$new"
rm "$tmp/boot/initramfs-$new.img"
out=$(check); rc=$?
[ "$rc" -eq 1 ] && [[ $out == *"kernel $new has no $tmp/boot image or initramfs"* ]] &&
  pass "failed dracut (image, no initramfs): critical" || fail_at "no initramfs: rc=$rc [$out]"

: >"$tmp/boot/initramfs-$new.img"
ln -sfn "dtb-$old" "$tmp/boot/dtb"
out=$(check); rc=$?
[ "$rc" -eq 1 ] && [[ $out == *"Stage 2 not built from $new"* && $out == *"grubby --set-default=/boot/vmlinuz-$new"* ]] &&
  pass "stale /boot/dtb: critical, remedy sets the default first" || fail_at "stale dtb: rc=$rc [$out]"

[ "$fail" -eq 0 ] && echo "all passed" || exit 1
