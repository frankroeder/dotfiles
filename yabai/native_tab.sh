#!/usr/bin/env bash
# Native macOS tabs (Ghostty, Finder) briefly create a real window then merge it.
# yabai tiles that shell and can drop focus. Re-apply layout + restore focus.
# Avoids space next/prev thrash. Invoked async from signals (see window_rules).
set -u

event="${1:-}"
wid="${YABAI_WINDOW_ID:-}"

# Let yabai finish applying rules before we touch the window tree.
sleep 0.05

reapply_layout() {
  local layout
  layout=$(yabai -m query --spaces --space 2>/dev/null | jq -r '.type // empty')
  [[ -n $layout && $layout != null ]] && yabai -m space --layout "$layout" 2>/dev/null || true
}

case "$event" in
  created)
    [[ -z $wid ]] && exit 0
    win=$(yabai -m query --windows --window "$wid" 2>/dev/null) || exit 0
    app=$(printf '%s' "$win" | jq -r '.app // empty')
    # Ghostty space=2 rule yanks tab shells off the sibling's space; pull back first.
    # Prefer a sibling on the still-focused space (rule does not follow focus).
    if [[ $app == Ghostty || $app == ghostty ]]; then
      fs=$(yabai -m query --spaces --space 2>/dev/null | jq -r '.index // empty')
      sib=$(yabai -m query --windows 2>/dev/null | jq -r --argjson id "$wid" --argjson fs "${fs:-0}" '
        def g: (.app == "Ghostty" or .app == "ghostty") and .id != $id;
        ([.[] | select(g and .space == $fs)][0].space)
        // ([.[] | select(g)][0].space)
        // empty
      ')
      cur=$(printf '%s' "$win" | jq -r '.space // empty')
      if [[ -n $sib && -n $cur && $sib != "$cur" ]]; then
        yabai -m window "$wid" --space "$sib" 2>/dev/null || true
      fi
    fi
    reapply_layout
    yabai -m window --focus "$wid" 2>/dev/null || true
    ;;
  destroyed)
    reapply_layout
    yabai -m query --windows --window >/dev/null 2>&1 && exit 0
    yabai -m window --focus mouse 2>/dev/null \
      || yabai -m window --focus recent 2>/dev/null \
      || true
    ;;
esac
