#!/usr/bin/env python3
"""asahi-wallpaper-span: geometry (outputs, bezel gaps, cover crops), then the commands against a fake hyprctl/magick.
No Hyprland, no real images."""

import json
import os
import shutil
import sys
import tempfile
from importlib.machinery import SourceFileLoader
from importlib.util import module_from_spec, spec_from_loader
from pathlib import Path

sys.dont_write_bytecode = True  # no __pycache__ beside the scripts
loader = SourceFileLoader("asahi_wallpaper_span", str(Path(__file__).resolve().parent / "asahi-wallpaper-span"))
span = module_from_spec(spec_from_loader(loader.name, loader))
loader.exec_module(span)

FAILED = 0


def eq(got, expected, msg):
  global FAILED
  if got == expected:
    print(f"ok   {msg}")
  else:
    FAILED += 1
    print(f"FAIL  {msg} got={got!r} expected={expected!r}", file=sys.stderr)


def mon(name, x, y, w, h, scale=1, **kw):
  return {"name": name, "x": x, "y": y, "width": w, "height": h, "scale": scale, "transform": 0, "disabled": False, "mirrorOf": "none", **kw}


# Live setup: LG 4K @ 1.875 left of eDP-1 3024x1964 @ 2.
live = span.outputs([mon("eDP-1", 0, 0, 3024, 1964, 2), mon("DP-1", -2048, -329, 3840, 2160, 1.875)])
lg, edp = live[1], live[0]
eq((lg["w"], lg["h"], lg["pw"], lg["ph"]), (2048, 1152, 3840, 2160), "LG logical + native size")
eq((edp["w"], edp["h"]), (1512, 982), "eDP logical size")

eq(len(span.outputs([mon("A", 0, 0, 100, 100), mon("B", 0, 0, 100, 100, disabled=True)])), 1, "disabled dropped")
eq(len(span.outputs([mon("A", 0, 0, 100, 100), mon("B", 0, 0, 100, 100, mirrorOf="A")])), 1, "mirror dropped")
eq([r["name"] for r in span.outputs([mon("FALLBACK", 0, 0, 1920, 1080), mon("A", 0, 0, 100, 100)])], ["A"], "Hyprland FALLBACK dropped")
rot = span.outputs([dict(mon("R", 0, 0, 1920, 1080), transform=1)])[0]
eq((rot["w"], rot["h"], rot["pw"], rot["ph"]), (1080, 1920, 1080, 1920), "90° swaps sides")

# Gaps: each seam of touching outputs inserts a strip; corner contact is not a seam.
f = {r["name"]: r for r in span.frames(live, gap=32)}
eq((f["DP-1"]["x"], f["eDP-1"]["x"], f["eDP-1"]["y"]), (-2048, 32, 0), "seam gap shifts the right output")
row = span.outputs([mon("A", 0, 0, 100, 100), mon("B", 100, 0, 100, 100), mon("C", 200, 0, 100, 100)])
eq([r["x"] for r in span.frames(row, gap=10)], [0, 110, 220], "gap accumulates along a chain")
corner = span.outputs([mon("A", 0, 0, 100, 100), mon("B", 100, 100, 100, 100)])
eq([(r["x"], r["y"]) for r in span.frames(corner, gap=10)], [(0, 0), (100, 100)], "corner contact: no gap")
# L: B right of A, C under B: C sits past the A|B seam (x) and the B/C seam (y).
ell = span.outputs([mon("A", 0, 0, 100, 100), mon("B", 100, 0, 100, 100), mon("C", 100, 100, 100, 100)])
eq({r["name"]: (r["x"], r["y"]) for r in span.frames(ell, gap=10)}, {"A": (0, 0), "B": (110, 0), "C": (110, 110)}, "L layout: both seams")

# Cover: 2:1 layout on a 4:1 image keeps full height, crops the sides evenly.
two = span.outputs([mon("A", 0, 0, 100, 100), mon("B", 100, 0, 100, 100)])
eq(span.crops(span.frames(two), 800, 200), {"A": (200, 200, 200, 0), "B": (200, 200, 400, 0)}, "cover crops sides")
# Bezel gap pixels are dropped: B starts after the gap.
eq(span.crops(span.frames(two, gap=20), 880, 400)["B"], (400, 400, 480, 0), "gap pixels discarded")
c = span.crops(span.frames(live, gap=0), 5120, 2880)
eq(all(w > 0 and h > 0 and x >= 0 and y >= 0 and x + w <= 5120 and y + h <= 2880 for w, h, x, y in c.values()), True, "live crops inside image")
eq(c["DP-1"][1] == round(1152 * 5120 / 3560), True, "LG keeps its logical aspect in source px")

# ---- commands: state/cache in a temp dir, `run` faked, magick a shell stub (MAGICK_FAIL: truncated write + exit 1) ----
tmp = Path(tempfile.mkdtemp(prefix="wallpaper-span-test-"))
span.STATE, span.CURRENT, span.CACHE = tmp / "state.json", tmp / "wallpaper.conf", tmp / "cache"
wall = tmp / "wall.jpg"
wall.write_text("never decoded")
span.CURRENT.write_text(str(wall))
(tmp / "bin").mkdir()
(tmp / "bin/magick").write_text('#!/bin/sh\nfor a; do out=${a#PNG24:}; done\nprintf png > "$out"\n[ -z "$MAGICK_FAIL" ]\n')
(tmp / "bin/hyprctl").write_text("#!/bin/sh\nexit 1\n")  # guard: the live session is never touched
for exe in ("magick", "hyprctl"):
  (tmp / "bin" / exe).chmod(0o755)
os.environ["PATH"] = f"{tmp / 'bin'}:{os.environ['PATH']}"
monitors, sets = [], []


def fake_run(*cmd):
  if cmd[:2] == ("hyprctl", "monitors"):
    return json.dumps(monitors)
  if cmd[:2] == ("magick", "identify"):
    return "3000 2000 |"
  if cmd[:3] == ("hyprctl", "hyprpaper", "wallpaper"):
    sets.append(cmd[3])
  return ""  # listactive: nothing shown yet


span.run = fake_run


def state():
  return json.loads(span.STATE.read_text())


def pngs():
  return sorted(str(p) for p in span.CACHE.glob("*.png"))


# One output: no cut, the plain image (hyprpaper's cover is the same picture); stale slices leave the state.
monitors[:] = [mon("eDP-1", 0, 0, 3024, 1964, 2)]
span.STATE.write_text(json.dumps({"enabled": True, "gap": 0, "outputs": {"eDP-1": "/gone/slice.png"}}))
span.main("apply", str(wall))
eq(sets, [f"eDP-1,{wall},cover", f",{wall},cover"], "one output: plain wallpaper set")
eq((state()["outputs"], pngs()), ({}, []), "one output: nothing cut, the Monitors pane falls back to the thumbnail")

# Two outputs: one slice each, only whole files under the final names.
monitors[:] = [mon("eDP-1", 0, 0, 3024, 1964, 2), mon("DP-1", -2048, -329, 3840, 2160, 1.875)]
sets.clear()
span.main("sync")
cut = state()["outputs"]
eq(sorted(cut), ["DP-1", "eDP-1"], "two outputs: one slice each")
eq(pngs(), sorted(cut.values()), "two outputs: no .tmp.png left")
eq(sorted(sets), sorted([f"DP-1,{cut['DP-1']},cover", f"eDP-1,{cut['eDP-1']},cover", f",{wall},cover"]), "two outputs: slices set")

# FALLBACK beside the one real output is still a single output.
monitors[:] = [mon("FALLBACK", 0, 0, 1920, 1080), mon("eDP-1", 0, 0, 3024, 1964, 2)]
span.main("sync")
eq(state()["outputs"], {}, "FALLBACK does not count as a second output")

# magick fails: no truncated slice under a final name; the retry cuts again and prunes the rest.
monitors[:] = [mon("eDP-1", 0, 0, 3024, 1964, 2), mon("DP-1", -2048, -329, 3840, 2160, 1.875)]
os.environ["MAGICK_FAIL"] = "1"
try:
  span.main("gap", "8")
  eq("no exit", "SystemExit", "failed cut exits")
except SystemExit as e:
  eq(str(e), "magick failed", "failed cut exits")
del os.environ["MAGICK_FAIL"]
eq(state()["gap"], 0, "failed cut leaves the state alone")
eq([p for p in pngs() if not p.endswith(".tmp.png") and p not in cut.values()], [], "failed cut: no slice under a final name")
span.main("gap", "8")
eq((state()["gap"], pngs()), (8, sorted(state()["outputs"].values())), "retry: new slices only, old and tmp pruned")

shutil.rmtree(tmp)
if FAILED:
  print(f"{FAILED} failed", file=sys.stderr)
  sys.exit(1)
print("all ok")
