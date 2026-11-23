#!/usr/bin/env bash
# Smoke tests for asahi-pkg JSON. Read-only dnf queries; `updates` (it refreshes metadata) runs on a fake dnf.

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PKG="$ROOT/asahi-pkg"
fail=0
pass() { printf 'ok  %s\n' "$1"; }
fail_at() { printf 'FAIL %s\n' "$1"; fail=1; }

chmod +x "$PKG"

if "$PKG" >/dev/null 2>&1; then
  fail_at "no-args should fail"
else
  pass "no-args exits non-zero"
fi

empty="$("$PKG" search)"
if echo "$empty" | jq -e '.error == "empty-query" and (.packages|length)==0' >/dev/null; then
  pass "empty search is empty-query"
else
  fail_at "empty search: $empty"
fi

hit="$("$PKG" search htop)"
if echo "$hit" | jq -e '.packages | map(.name) | index("htop") != null' >/dev/null; then
  pass "search htop finds htop"
else
  fail_at "search htop: $hit"
fi

inst="$("$PKG" installed htop)"
if echo "$inst" | jq -e 'has("packages")' >/dev/null; then
  pass "installed JSON has packages"
else
  fail_at "installed JSON: $inst"
fi

# dnf5 lists obsoleted packages indented under "Obsoleting packages": neither is an update row.
fake="$(mktemp -d)"
trap 'rm -rf "$fake"' EXIT
cat >"$fake/dnf" <<'EOF'
#!/usr/bin/env bash
printf 'Upgrades\nkernel-16k.aarch64  6.17.1-400.fc44  copr:kernel\n\nObsoleting packages\n'
printf 'newtool.aarch64  2.0-1.fc44  updates\n    oldtool.aarch64  1.0-1.fc44  updates\n'
exit 100
EOF
chmod +x "$fake/dnf"
# Flatpak updates (no network in tests): an app with a version, a runtime with only a branch.
cat >"$fake/flatpak" <<'FP'
#!/usr/bin/env bash
printf 'org.mozilla.firefox\t146.0\tstable\tflathub\norg.freedesktop.Platform\t\t25.08\tflathub\n'
FP
chmod +x "$fake/flatpak"
upd="$(PATH="$fake:$PATH" "$PKG" updates)"
if echo "$upd" | jq -e 'has("packages") and has("available")' >/dev/null; then
  pass "updates JSON shape"
else
  fail_at "updates JSON: $upd"
fi
names="$(jq -c '[.packages[].name]' <<<"$upd")"
if [ "$names" = '["kernel-16k","newtool","org.mozilla.firefox","org.freedesktop.Platform"]' ]; then
  pass "updates skips obsoletes headings and obsoleted rows; Flatpaks follow the dnf rows"
else
  fail_at "updates with obsoletes: $names"
fi
if jq -e '.packages[2] == {name: "org.mozilla.firefox", arch: "", version: "146.0", repo: "flatpak · flathub", summary: "", source: "flatpak"}
  and .packages[3].version == "25.08"' <<<"$upd" >/dev/null; then
  pass "Flatpak rows: version (else branch), origin, source flatpak"
else
  fail_at "flatpak rows: $(jq -c '.packages[2:]' <<<"$upd")"
fi
# Offline: remote-ls fails, the cached listing answers.
cat >"$fake/flatpak" <<'FP'
#!/usr/bin/env bash
case " $* " in *" --cached "*) printf 'org.gimp.GIMP\t3.0.6\tstable\tflathub\n' ;; *) exit 1 ;; esac
FP
if [ "$(PATH="$fake:$PATH" "$PKG" updates | jq -r '.packages[-1].name')" = org.gimp.GIMP ]; then
  pass "offline Flatpak check falls back to the cache"
else
  fail_at "flatpak --cached fallback"
fi

# A query that crashes (here python3) still prints JSON, so the panel's spinner stops.
printf '#!/bin/sh\nexit 1\n' >"$fake/python3"
chmod +x "$fake/python3"
crash="$(PATH="$fake:$PATH" "$PKG" updates || true)"
if echo "$crash" | jq -e '.error != "" and (.packages | length) == 0' >/dev/null 2>&1; then
  pass "a crashed query still prints JSON"
else
  fail_at "crashed query printed: '$crash'"
fi

qml="$ROOT/../quickshell/remix/modules/system/PkgManager.qml"
if grep -q 'target: "pkgman"' "$qml" && grep -q 'asahi-pkg' "$qml"; then
  pass "PkgManager.qml talks to asahi-pkg"
else
  fail_at "PkgManager.qml missing pkgman/asahi-pkg"
fi

# tui-upgrade: blocks sleep (not idle: the screen must still lock) for the whole dnf run, then checks the boot chain.
up=$(sed -n '/^  tui-upgrade)/,/;;/p' "$ROOT/asahi-pkg")
if grep -q 'systemd-inhibit --what=sleep ' <<<"$up" && ! grep -q 'what=idle' <<<"$up" && grep -q 'asahi-boot-check' <<<"$up"; then
  pass "tui-upgrade: sleep inhibited during dnf, boot chain checked after"
else
  fail_at "tui-upgrade chain: $up"
fi

if [ "$fail" -ne 0 ]; then
  echo "$fail failed"
  exit 1
fi
echo "all passed"
