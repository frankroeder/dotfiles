#!/usr/bin/env bash
# Smoke tests for asahi-pkg JSON. Read-only dnf queries.

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

upd="$("$PKG" updates)"
if echo "$upd" | jq -e 'has("packages") and has("available")' >/dev/null; then
  pass "updates JSON shape"
else
  fail_at "updates JSON: $upd"
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
