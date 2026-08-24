#!/usr/bin/env bash
# Smoke: sync vicinae private configs through a fake HOME/iCloud tree.
set -euo pipefail

DOTFILES="${DOTFILES:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
# shellcheck source=install/common.sh
. "$DOTFILES/install/common.sh"
# shellcheck source=install/components.sh
. "$DOTFILES/install/components.sh"

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
export HOME="$tmp"

docs="$HOME/Library/Mobile Documents/com~apple~CloudDocs"
share="$HOME/.local/share/vicinae"
cfg="$HOME/.config/vicinae"
cloud="$docs/configs/vicinae"

mkdir -p "$docs" \
  "$share/extensions/store.raycast.zotero" \
  "$share/extensions/dict-cc" \
  "$share/snippets" \
  "$share/shortcuts" \
  "$cfg"
printf 'zotero\n' > "$share/extensions/store.raycast.zotero/package.json"
printf 'dict\n' > "$share/extensions/dict-cc/package.json"
printf '{"imports":[]}\n' > "$cfg/settings.json"
printf '[]\n' > "$share/snippets/snippets.json"
printf '[]\n' > "$share/shortcuts/shortcuts.json"

icloud_sync_vicinae
[ -f "$cloud/settings.json" ]
[ -f "$cloud/snippets.json" ]
[ -f "$cloud/shortcuts.json" ]
[ -f "$cloud/extensions/store.raycast.zotero/package.json" ]
[ ! -e "$cloud/extensions/dict-cc" ]

# Fresh machine: wipe local, sync restores from iCloud.
rm -rf "$share" "$cfg"
mkdir -p "$share" "$cfg"
icloud_sync_vicinae
[ -f "$cfg/settings.json" ]
[ -f "$share/snippets/snippets.json" ]
[ -f "$share/shortcuts/shortcuts.json" ]
[ -f "$share/extensions/store.raycast.zotero/package.json" ]
[ ! -e "$share/extensions/dict-cc" ]

# Existing local settings.json is not overwritten.
printf '{"imports":["keep"]}\n' > "$cfg/settings.json"
icloud_sync_vicinae
grep -q keep "$cfg/settings.json"

echo ok
