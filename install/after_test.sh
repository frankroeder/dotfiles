#!/usr/bin/env bash
# Smoke: make after syncs agent configs on Linux; Darwin extras stay gated.
set -euo pipefail

DOTFILES="${DOTFILES:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"

body="$(awk '
  /^comp_after\(\)/ { grab=1 }
  grab { print }
  grab && /^}/ { exit }
' "$DOTFILES/install/components.sh")"
[ -n "$body" ]

# Drop the Darwin-only trailing block; agents must remain for Linux after.
ungated="$(printf '%s\n' "$body" | awk '
  /if \[ "\$OSTYPE_UNAME" = "Darwin" \]; then/ { skip=1; next }
  skip && /^  fi$/ { skip=0; next }
  skip { next }
  { print }
')"
printf '%s\n' "$ungated" | grep -q 'comp_agents' || {
  echo "comp_agents is missing from Linux make after" >&2
  exit 1
}
if printf '%s\n' "$ungated" | grep -q 'comp_services'; then
  echo "comp_services leaked out of the Darwin gate" >&2
  exit 1
fi

# shellcheck source=install/common.sh
. "$DOTFILES/install/common.sh"
# shellcheck source=install/components.sh
. "$DOTFILES/install/components.sh"

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
export HOME="$tmp"
export NEXTCLOUD_DIR="$tmp/portal"
mkdir -p "$NEXTCLOUD_DIR" "$tmp/bin"
printf 'agents\n' > "$NEXTCLOUD_DIR/AGENTS.md"
printf '{}\n' > "$NEXTCLOUD_DIR/claude_settings.json"
printf '%s\n' '#!/bin/sh' 'exit 0' > "$tmp/bin/claude"
chmod +x "$tmp/bin/claude"
# Isolate from host agent CLIs so only the fake claude is "installed".
export PATH="$tmp/bin:/usr/bin:/bin"

[ "$OSTYPE_UNAME" = "Linux" ]
comp_agents
[ -L "$HOME/.claude/CLAUDE.md" ]
[ -L "$HOME/.claude/settings.json" ]
[ "$(readlink "$HOME/.claude/CLAUDE.md")" = "$NEXTCLOUD_DIR/AGENTS.md" ]
[ "$(readlink "$HOME/.claude/settings.json")" = "$NEXTCLOUD_DIR/claude_settings.json" ]

echo ok
