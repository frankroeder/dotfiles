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
upd="$(PATH="$fake:$PATH" "$PKG" updates)"
if echo "$upd" | jq -e 'has("packages") and has("available")' >/dev/null; then
  pass "updates JSON shape"
else
  fail_at "updates JSON: $upd"
fi
names="$(jq -c '[.packages[].name]' <<<"$upd")"
if [ "$names" = '["kernel-16k","newtool"]' ]; then
  pass "updates skips obsoletes headings and obsoleted rows"
else
  fail_at "updates with obsoletes: $names"
fi

qml="$ROOT/../quickshell/remix/modules/system/PkgManager.qml"
if grep -q 'target: "pkgman"' "$qml" && grep -q 'asahi-pkg' "$qml"; then
  pass "PkgManager.qml talks to asahi-pkg"
else
  fail_at "PkgManager.qml missing pkgman/asahi-pkg"
fi

if [ "$fail" -ne 0 ]; then
  echo "$fail failed"
  exit 1
fi
echo "all passed"
