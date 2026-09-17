#!/usr/bin/env python3
"""Minimal unit checks for asahi theme extraction (no ImageMagick required for oklab)."""

from __future__ import annotations

import itertools
import sys
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT.parent))

from theme.oklab import from_srgb8, hex_from_oklch, hue_distance, max_chroma  # noqa: E402
from theme.extract import Representative, merge_close  # noqa: E402
from theme.palette import FLAVORS, build_palette  # noqa: E402


def lch(hx: str):
    r, g, b = (int(hx[i : i + 2], 16) for i in (1, 3, 5))
    return from_srgb8(r, g, b).to_oklch()


REPS = [
    Representative(lab=from_srgb8(18, 22, 44), weight=100, hex="#12162c"),
    Representative(lab=from_srgb8(210, 90, 60), weight=45, hex="#d25a3c"),
    Representative(lab=from_srgb8(90, 160, 200), weight=30, hex="#5aa0c8"),
    Representative(lab=from_srgb8(230, 226, 214), weight=15, hex="#e6e2d6"),
]


class TestOKLab(unittest.TestCase):
    def test_roundtrip_blackish(self):
        lab = from_srgb8(0x1e, 0x1e, 0x2e)
        self.assertGreater(lab.L, 0.1)
        self.assertLess(lab.L, 0.3)

    def test_hex_from_oklch(self):
        hx = hex_from_oklch(0.2, 0.04, 260)
        self.assertTrue(hx.startswith("#") and len(hx) == 7)

    def test_hue_distance(self):
        self.assertEqual(hue_distance(10, 350), 20)


class TestPalette(unittest.TestCase):
    def test_build_dark(self):
        reps = [
            Representative(lab=from_srgb8(10, 20, 40), weight=100, hex="#0a1428"),
            Representative(lab=from_srgb8(200, 80, 120), weight=40, hex="#c85078"),
            Representative(lab=from_srgb8(220, 220, 240), weight=20, hex="#dcdcf0"),
        ]
        p = build_palette(reps, "/tmp/x.jpg", variant="source")
        self.assertEqual(p.mode, "dark")
        self.assertTrue(p.accent.startswith("#"))
        self.assertTrue(p.background.startswith("#"))
        self.assertIn("base", p.to_dict())

    def test_build_light(self):
        reps = [
            Representative(lab=from_srgb8(250, 248, 240), weight=100, hex="#faf8f0"),
            Representative(lab=from_srgb8(230, 200, 160), weight=40, hex="#e6c8a0"),
            Representative(lab=from_srgb8(40, 36, 32), weight=10, hex="#282420"),
        ]
        p = build_palette(reps, "/tmp/light.jpg", variant="source")
        self.assertEqual(p.mode, "light")
        self.assertTrue(p.background.startswith("#"))

    def test_mode_override(self):
        auto = build_palette(REPS, "/tmp/x.jpg")
        self.assertEqual(auto.mode, "dark")
        self.assertEqual(build_palette(REPS, "/tmp/x.jpg", mode="light").mode, "light")
        self.assertEqual(build_palette(REPS, "/tmp/x.jpg", mode="dark").mode, "dark")
        # A junk value falls back to deriving the mode rather than raising.
        self.assertEqual(build_palette(REPS, "/tmp/x.jpg", mode="nope").mode, "dark")

    def test_merge_close(self):
        a = Representative(lab=from_srgb8(10, 10, 10), weight=5, hex="#0a0a0a")
        b = Representative(lab=from_srgb8(12, 12, 12), weight=3, hex="#0c0c0c")
        merged = merge_close([a, b], threshold=0.05)
        self.assertEqual(len(merged), 1)


class TestFlavors(unittest.TestCase):
    """Flavours are matugen scheme-* analogues: same image, different strength."""

    def test_every_flavor_builds(self):
        for name in FLAVORS:
            p = build_palette(REPS, "/tmp/x.jpg", variant=name)
            self.assertEqual(p.variant, name)
            for key, value in p.to_dict().items():
                if key in ("mode", "wallpaper", "variant"):
                    continue
                self.assertRegex(value, r"^#[0-9a-f]{6}$", f"{name}.{key}")

    def test_unknown_flavor_falls_back_to_source(self):
        src = build_palette(REPS, "/tmp/x.jpg", variant="source")
        self.assertEqual(build_palette(REPS, "/tmp/x.jpg", variant="nope").accent, src.accent)

    def test_no_two_flavours_look_alike(self):
        """The bug that made them feel samey: chroma multipliers overshot the sRGB
        gamut, so every strong flavour clipped to one identical accent."""
        accents = {n: build_palette(REPS, "/tmp/x.jpg", variant=n).accent for n in FLAVORS}
        self.assertEqual(len(set(accents.values())), len(FLAVORS), accents)
        # Not just distinct hex — separated enough to read on a bar. Kept loose
        # because `content` separates from `source` mostly via the surfaces
        # (see test_surface_tint_pulls_content_and_vibrant_apart), not the accent.
        chroma = sorted(lch(hx).C for hx in accents.values())
        for lo, hi in itertools.pairwise(chroma):
            self.assertGreater(hi - lo, 0.008, f"{chroma} has two flavours sitting on top of each other")

    def test_chroma_ordering(self):
        chroma = {n: lch(build_palette(REPS, "/tmp/x.jpg", variant=n).accent).C for n in FLAVORS}
        self.assertLess(chroma["mono"], 0.01)
        self.assertLess(chroma["calm"], chroma["source"])
        self.assertLess(chroma["source"], chroma["content"])
        self.assertLess(chroma["content"], chroma["vibrant"])

    def test_vibrant_reaches_the_gamut_edge(self):
        p = build_palette(REPS, "/tmp/x.jpg", variant="vibrant")
        acc = lch(p.accent)
        self.assertGreater(acc.C, 0.9 * max_chroma(acc.L, acc.H))

    def test_mono_is_greyscale_everywhere(self):
        p = build_palette(REPS, "/tmp/x.jpg", variant="mono")
        for key in ("accent", "red", "green", "blue", "mauve", "teal", "bright_red", "surface1"):
            self.assertLess(lch(getattr(p, key)).C, 0.02, key)

    def test_surface_tint_pulls_content_and_vibrant_apart(self):
        """Their accents are both strong; what separates them is the panels."""
        bg = {n: lch(build_palette(REPS, "/tmp/x.jpg", variant=n).background).C
              for n in ("source", "content", "vibrant")}
        self.assertGreater(bg["content"], bg["source"])
        self.assertLess(bg["vibrant"], bg["source"])

    def test_vibrant_does_not_invent_color_from_a_grey_wallpaper(self):
        grey = [
            Representative(lab=from_srgb8(32, 32, 32), weight=100, hex="#202020"),
            Representative(lab=from_srgb8(128, 128, 128), weight=40, hex="#808080"),
            Representative(lab=from_srgb8(224, 224, 224), weight=20, hex="#e0e0e0"),
        ]
        # A greyscale image still reports some hue angle; amplifying it used to
        # turn a black-and-white photo olive-gold.
        for name in FLAVORS:
            self.assertLess(lch(build_palette(grey, "/tmp/g.jpg", variant=name).accent).C, 0.02, name)

    def test_content_keeps_wallpaper_hues(self):
        src = build_palette(REPS, "/tmp/x.jpg", variant="source")
        content = build_palette(REPS, "/tmp/x.jpg", variant="content")
        # `source` snaps green toward the ANSI slot; `content` does not.
        self.assertGreater(
            hue_distance(lch(content.green).H, 145), hue_distance(lch(src.green).H, 145)
        )

if __name__ == "__main__":
    unittest.main()
