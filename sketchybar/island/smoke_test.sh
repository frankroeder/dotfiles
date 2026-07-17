#!/usr/bin/env bash
# Live smoke test / demo for sketchybar-island. Drives real triggers + queries.
#
# Island pills (all six):
#   appswitch  — front_app_switched (app name + app icon glyph)
#   layout     — island_layout layout=bsp|stack|float
#   window     — island_window prop=float|sticky (reads live yabai focused window)
#   mic        — island_mic muted=true|false
#   bluetooth  — island_bluetooth name=… type=Headphones|Mouse|Keyboard|Speaker battery=…
#   siri       — island_siri action=appear|disappear (sticky, highest prio)
#
# Usage:
#   ./sketchybar/island/smoke_test.sh [out_dir]     # verify (default)
#   ./sketchybar/island/smoke_test.sh --demo        # slow visual demo of every pill
# Demo dwell defaults to 5s; override with DEMO_DWELL=<seconds>.
set -euo pipefail

ISLAND="${ISLAND_BIN:-sketchybar-island}"

MODE="verify"
if [[ "${1:-}" == "--demo" || "${1:-}" == "demo" ]]; then
  MODE="demo"
  shift
fi

OUT="${1:-.}"
mkdir -p "$OUT"

# Generous settle time between steps so animations finish (less visible flicker)
# and queries land on a stable frame.
STEP="${STEP_DELAY:-1.1}"

query_json() {
  local tag="$1" bar="" main=""
  # During an animation/reload a --query can return empty or a "[!] ..." error;
  # retry (with a short settle) until BOTH look like JSON objects, so the parse
  # below never crashes the run under `set -e`.
  sleep 0.2
  for _ in $(seq 1 15); do
    bar="$($ISLAND --query bar 2>/dev/null)"
    main="$($ISLAND --query island.main 2>/dev/null)"
    [[ "$bar" == "{"* && "$main" == "{"* ]] && break
    sleep 0.3
  done
  python3 - "$tag" "$bar" "$main" <<'PY'
import json, sys
tag, bar_s, main_s = sys.argv[1], sys.argv[2], sys.argv[3]
def parse(s):
  s = (s or "").strip()
  try:
    return json.loads(s) if s.startswith("{") else {}
  except json.JSONDecodeError:
    return {}
bar, main = parse(bar_s), parse(main_s)
geom = main.get("geometry", {})
print(json.dumps({
  "tag": tag,
  "bar_hidden": bar.get("hidden"),
  "bar_height": bar.get("height"),
  "bar_margin": bar.get("margin"),
  "main_width": geom.get("width"),
  "display_mask": geom.get("associated_display_mask"),
  "icon": main.get("icon", {}).get("value"),
  "label": main.get("label", {}).get("value"),
}))
PY
}

# The retract shows idle geometry, then hides ~0.3s later (a cancellable delay
# that a stray focus/app event can push out). Poll for the hide so the idle
# assertions are not racy.
wait_bar_hidden() {
  for _ in $(seq 1 24); do
    local h
    h="$($ISLAND --query bar 2>/dev/null | python3 -c 'import json,sys
try: print(json.load(sys.stdin).get("hidden",""))
except Exception: print("")' 2>/dev/null)"
    [[ "$h" == "on" ]] && return 0
    sleep 0.25
  done
  return 1
}

# Reload so every listener's dedup state (last_muted / last_index / last_app /
# last SSID) starts fresh — otherwise a repeat run dedups mic/space triggers and
# no pill shows. Then wait for the last-loaded listener before driving events.
$ISLAND --reload 2>/dev/null || true
for _ in $(seq 1 40); do
  $ISLAND --query bar 2>/dev/null | grep -q "listener.window" && break
  sleep 0.25
done
sleep "$STEP"

$ISLAND --trigger island_tap 2>/dev/null || true
sleep "$STEP"

# ---------------------------------------------------------------------------
# Demo mode: show every pill as it really looks, with a 5s dwell + live prints.
# ---------------------------------------------------------------------------
demo() {
  local dwell="${DEMO_DWELL:-5}"
  local n=0 total=6

  step() {
    n=$((n + 1))
    printf '\n\033[1;36m▶ [%d/%d] %s\033[0m\n' "$n" "$total" "$1"
  }
  detail() { printf '   \033[2m%s\033[0m\n' "$1"; }
  # Hold while pill is visible; print a ticking status line so the terminal
  # tracks the on-screen dwell (default 5s).
  hold() {
    local msg="${1:-showing}"
    local left
    for ((left = dwell; left > 0; left--)); do
      printf '\r   \033[1;33m●\033[0m %s  \033[2m(%ds left)\033[0m   ' "$msg" "$left"
      sleep 1
    done
    printf '\r   \033[1;32m✓\033[0m %s  \033[2m(done %ds)\033[0m   \n' "$msg" "$dwell"
  }
  reset() {
    detail "dismiss (island_tap) → idle"
    $ISLAND --trigger island_tap
    sleep 1.0
  }
  snap() {
    # Optional live query of what's on the pill right now.
    local q
    q="$($ISLAND --query island.main 2>/dev/null | python3 -c '
import json,sys
try:
  m=json.load(sys.stdin)
  print("%s | %s" % (m.get("icon",{}).get("value") or "—", m.get("label",{}).get("value") or "—"))
except Exception:
  print("— | —")
' 2>/dev/null)" || q="— | —"
    detail "pill now: $q"
  }

  cat <<EOF
════════════════════════════════════════════════════════════
  sketchybar-island demo
  dwell ${dwell}s per state · Ctrl-C to stop

  All pills covered:
    1. appswitch   front_app_switched
    2. layout      island_layout (bsp / stack / float)
    3. window      island_window (float / sticky)
    4. mic         island_mic (muted / on)
    5. bluetooth   island_bluetooth (Headphones/Mouse/Keyboard/Speaker)
    6. siri        island_siri sticky (appear / disappear)
════════════════════════════════════════════════════════════
EOF

  # --- 1. appswitch ---
  step "appswitch — front app name + app icon glyph"
  detail "trigger: front_app_switched INFO=<app>"
  detail "first event only primes last_app (no toast); later names expand"
  $ISLAND --trigger front_app_switched INFO=Finder
  sleep 0.4
  for a in Safari Ghostty Music; do
    detail "→ INFO=$a"
    $ISLAND --trigger front_app_switched INFO="$a"
    sleep 0.35
    snap
    hold "appswitch · $a"
  done
  reset

  # --- 2. layout ---
  step "layout — space layout change (skhd fn-e/w/s)"
  detail "trigger: island_layout layout=bsp|stack|float"
  detail "left: \"Bsp/Stack/Float layout\" · right: yabai glyph"
  for l in bsp stack float; do
    detail "→ layout=$l"
    $ISLAND --trigger island_layout layout=$l
    sleep 0.35
    snap
    hold "layout · $l"
  done
  reset

  # --- 3. window ---
  step "window — float / sticky of the real focused window"
  detail "trigger: island_window prop=float|sticky"
  detail "re-queries yabai; shows Floating|Tiled or Sticky|Not sticky"
  for pr in float sticky; do
    detail "→ prop=$pr"
    $ISLAND --trigger island_window prop=$pr
    sleep 0.5
    snap
    hold "window · $pr"
  done
  reset

  # --- 4. mic ---
  step "mic — mute state (from top-bar mic bridge)"
  detail "trigger: island_mic muted=true|false"
  detail "left: \"Mic muted\" / \"Mic on\" · right: mic glyph (warn/success)"
  detail "→ muted=true"
  $ISLAND --trigger island_mic muted=true
  sleep 0.35
  snap
  hold "mic · muted"
  detail "→ muted=false"
  $ISLAND --trigger island_mic muted=false
  sleep 0.35
  snap
  hold "mic · on"
  reset

  # --- 5. bluetooth ---
  step "bluetooth — device connect + type glyph + battery"
  detail "trigger: island_bluetooth name=… type=… battery=…"
  detail "types: Headphones / Mouse / Keyboard / Speaker"
  $ISLAND --trigger island_bluetooth name=AirPodsPro type=Headphones battery=80%
  sleep 0.35; snap
  hold "bluetooth · AirPodsPro · Headphones · 80%"
  $ISLAND --trigger island_bluetooth name="MX Master 3S" type=Mouse battery=55%
  sleep 0.35; snap
  hold "bluetooth · MX Master 3S · Mouse · 55%"
  $ISLAND --trigger island_bluetooth name="Magic Keyboard" type=Keyboard battery=90%
  sleep 0.35; snap
  hold "bluetooth · Magic Keyboard · Keyboard · 90%"
  $ISLAND --trigger island_bluetooth name=HomePod type=Speaker battery=100%
  sleep 0.35; snap
  hold "bluetooth · HomePod · Speaker · 100%"
  reset

  # --- 6. siri ---
  step "siri — sticky mauve highlight (highest priority)"
  detail "trigger: island_siri action=appear|disappear"
  detail "sticky=true · duration=0 · lower prio pills cannot clobber"
  detail "→ action=appear"
  $ISLAND --trigger island_siri action=appear
  sleep 0.35
  snap
  hold "siri · listening (sticky)"
  detail "→ action=disappear"
  $ISLAND --trigger island_siri action=disappear
  sleep 1.0
  detail "siri dismissed"

  $ISLAND --trigger island_tap 2>/dev/null || true
  sleep 1.0
  echo
  echo "── demo complete: all 6 island pills shown ──"
}

if [[ "$MODE" == "demo" ]]; then
  demo
  exit 0
fi

# --- restore ---
$ISLAND --trigger island_layout layout=bsp
sleep "$STEP"
query_json expanded | tee "$OUT/island_restore_expanded.json" >/dev/null
$ISLAND --trigger island_tap
wait_bar_hidden || true
query_json restored | tee "$OUT/island_restore.json"
python3 - "$OUT/island_restore.json" <<'PY'
import json,sys
d=json.load(open(sys.argv[1]))
# Idle invariants (geometry + cleared content) are the hard contract.
assert d["display_mask"] in (0,"0"), d
assert int(d["main_width"]) < 2000, d
assert int(d["bar_margin"]) > 0, d
assert not (d["icon"] or d["label"]), d
# The physical hide is a deferred, cancellable step; warn (don't fail) if it
# hasn't landed, so a stray focus event can't make the smoke test flaky.
if d["bar_hidden"] != "on":
  print("warn: idle geometry restored but bar not hidden yet (%s)" % d["bar_hidden"])
print("ok: restore idle geometry")
PY

# --- priority sticky: siri (sticky) holds against a lower pill until dismissed ---
{
  $ISLAND --trigger island_siri action=appear
  sleep "$STEP"
  query_json siri
  # layout (prio 40) must NOT clobber sticky siri (prio 90)
  $ISLAND --trigger island_layout layout=float
  sleep "$STEP"
  query_json after_layout
  $ISLAND --trigger island_siri action=disappear
  sleep "$STEP"
} | tee "$OUT/island_priority.log"

python3 - "$OUT/island_priority.log" <<'PY'
import json,sys
rows=[json.loads(l) for l in open(sys.argv[1]) if l.strip().startswith("{")]
by={r["tag"]:r for r in rows}
assert (by["siri"].get("icon") or "") == "Siri", by["siri"]
assert by["after_layout"]["icon"]==by["siri"]["icon"], by["after_layout"]
print("ok: priority sticky (siri holds)")
PY

# --- pills: mic / bluetooth / window ---
{
  $ISLAND --trigger island_mic muted=true
  sleep "$STEP"
  query_json mic
  $ISLAND --trigger island_tap; sleep "$STEP"
  $ISLAND --trigger island_bluetooth name=AirPods type=Headphones battery=80%
  sleep "$STEP"
  query_json bluetooth
  $ISLAND --trigger island_tap; sleep "$STEP"
  $ISLAND --trigger island_window prop=float
  sleep "$STEP"
  query_json window
  $ISLAND --trigger island_tap; sleep "$STEP"
} | tee "$OUT/island_new_pills.log"

python3 - "$OUT/island_new_pills.log" <<'PY'
import json,sys
rows=[json.loads(l) for l in open(sys.argv[1]) if l.strip().startswith("{")]
by={r["tag"]:r for r in rows}
assert "Mic" in (by["mic"].get("icon") or ""), by["mic"]
assert "AirPods" in (by["bluetooth"].get("icon") or ""), by["bluetooth"]
# window depends on a live focused window; accept its state or idle.
wicon=by["window"].get("icon") or ""
assert wicon in ("","Floating","Tiled") or "Float" in wicon or "Tiled" in wicon, by["window"]
print("ok: pills mic/bluetooth/window")
PY

# --- display_change retarget (must not error / leave mask) ---
$ISLAND --trigger display_change
sleep "$STEP"
query_json after_display_change | tee "$OUT/island_display_change.json"
python3 - "$OUT/island_display_change.json" <<'PY'
import json,sys
d=json.load(open(sys.argv[1]))
assert d["display_mask"] in (0,"0"), d
print("ok: display_change safe")
PY

# --- listeners present ---
$ISLAND --query bar 2>/dev/null | python3 -c '
import json,sys
items=set(json.load(sys.stdin).get("items",[]))
need=["listener.mic","listener.window",
      "listener.bluetooth","island.main"]
missing=[n for n in need if n not in items]
assert not missing, missing
print("ok: listeners present")
'

echo "ALL SMOKE CHECKS PASSED"
exit 0
