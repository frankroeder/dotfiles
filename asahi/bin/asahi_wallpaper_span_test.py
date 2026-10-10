#!/usr/bin/env python3
"""Geometry of asahi-wallpaper-span: outputs, bezel gaps, cover crops. No Hyprland, no magick."""

import sys
from importlib.machinery import SourceFileLoader
from pathlib import Path

span = SourceFileLoader("asahi_wallpaper_span", str(Path(__file__).resolve().parent / "asahi-wallpaper-span")).load_module()

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

if FAILED:
  print(f"{FAILED} failed", file=sys.stderr)
  sys.exit(1)
print("all ok")
