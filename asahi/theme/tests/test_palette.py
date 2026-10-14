#!/usr/bin/env python3
"""Minimal unit checks for asahi theme extraction (no ImageMagick required for oklab)."""

from __future__ import annotations

import itertools
import sys
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT.parent))

from theme.oklab import OKLCH, from_srgb8, hex_from_oklch, hue_distance, max_chroma  # noqa: E402
from theme.extract import Representative, merge_close  # noqa: E402
from theme.palette import FLAVORS, HUES, _toward, build_palette  # noqa: E402


def lch(hx: str):
    r, g, b = (int(hx[i : i + 2], 16) for i in (1, 3, 5))
    return from_srgb8(r, g, b).to_oklch()


def luminance(hx: str) -> float:
    """WCAG 2 relative luminance."""
    def lin(v: int) -> float:
        v /= 255
        return v / 12.92 if v <= 0.04045 else ((v + 0.055) / 1.055) ** 2.4
    r, g, b = (lin(int(hx[i : i + 2], 16)) for i in (1, 3, 5))
    return 0.2126 * r + 0.7152 * g + 0.0722 * b


def contrast(a: str, b: str) -> float:
    lo, hi = sorted((luminance(a), luminance(b)))
    return (hi + 0.05) / (lo + 0.05)


def rep(l: float, c: float, h: float, weight: float) -> Representative:
    return Representative(lab=OKLCH(l, c, h).to_oklab(), weight=weight, hex="#000000")


REPS = [
    Representative(lab=from_srgb8(18, 22, 44), weight=100, hex="#12162c"),
    Representative(lab=from_srgb8(210, 90, 60), weight=45, hex="#d25a3c"),
    Representative(lab=from_srgb8(90, 160, 200), weight=30, hex="#5aa0c8"),
    Representative(lab=from_srgb8(230, 226, 214), weight=15, hex="#e6e2d6"),
]
GREY = [
    Representative(lab=from_srgb8(32, 32, 32), weight=100, hex="#202020"),
    Representative(lab=from_srgb8(128, 128, 128), weight=40, hex="#808080"),
    Representative(lab=from_srgb8(224, 224, 224), weight=20, hex="#e0e0e0"),
]
LIGHT = [
    Representative(lab=from_srgb8(250, 248, 240), weight=100, hex="#faf8f0"),
    Representative(lab=from_srgb8(230, 200, 160), weight=40, hex="#e6c8a0"),
    Representative(lab=from_srgb8(40, 36, 32), weight=10, hex="#282420"),
]
# Deep red just below 360° (fade-to-red.jpg): averaging 25° and 350° linearly made red blue.
CRIMSON = [rep(0.15, 0.02, 0, 100), rep(0.45, 0.17, 350, 50), rep(0.85, 0.02, 0, 10)]
# Orange-only rocks: sky, sapphire, lavender and mauve all used to come out orange.
ORANGE = [rep(0.18, 0.03, 60, 100), rep(0.55, 0.10, 65, 50), rep(0.85, 0.04, 75, 20)]
WALLS = {"navy": REPS, "grey": GREY, "light": LIGHT, "crimson": CRIMSON, "orange": ORANGE}

# Every ANSI / named color and the hue family it has to stay in.
FAMILY = {
    "red": "red", "orange": "orange", "yellow": "yellow", "green": "green", "cyan": "cyan", "blue": "blue",
    "magenta": "magenta", "brown": "orange", "bright_red": "red", "bright_yellow": "yellow", "bright_green": "green",
    "bright_cyan": "cyan", "bright_blue": "blue", "bright_magenta": "magenta", "rosewater": "red", "flamingo": "red",
    "pink": "magenta", "mauve": "magenta", "maroon": "red", "peach": "orange", "teal": "cyan", "sky": "cyan",
    "sapphire": "blue", "lavender": "blue",
}


def all_palettes():
    for wall, reps in WALLS.items():
        for name in FLAVORS:
            for mode in ("dark", "light"):
                yield f"{wall}/{name}/{mode}", build_palette(reps, f"/tmp/{wall}.jpg", variant=name, mode=mode)


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
        p = build_palette(LIGHT, "/tmp/light.jpg", variant="source")
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
        # A greyscale image still reports some hue angle; amplifying it used to
        # turn a black-and-white photo olive-gold.
        for name in FLAVORS:
            self.assertLess(lch(build_palette(GREY, "/tmp/g.jpg", variant=name).accent).C, 0.02, name)

    def test_content_keeps_wallpaper_hues(self):
        src = build_palette(REPS, "/tmp/x.jpg", variant="source")
        content = build_palette(REPS, "/tmp/x.jpg", variant="content")
        # The wallpaper's blue (235°) is in the cyan family: `source` turns cyan 65% of
        # the way there, `content` 90%.
        self.assertGreater(hue_distance(lch(content.cyan).H, 195), hue_distance(lch(src.cyan).H, 195))


class TestHueFamilies(unittest.TestCase):
    def test_toward_takes_the_short_arc(self):
        self.assertAlmostEqual(_toward(25, 350), 2.25)   # linear average: 236.75, blue
        self.assertAlmostEqual(_toward(350, 20), 9.5)
        self.assertAlmostEqual(_toward(255, 265, 1.0), 265)

    def test_every_color_stays_in_its_family(self):
        """red = critical, yellow = warning, green = ok on any wallpaper and flavour."""
        for label, p in all_palettes():
            for key, fam in FAMILY.items():
                c = lch(getattr(p, key))
                if c.C < 0.02:   # mono: grey has no hue to keep
                    continue
                self.assertLess(hue_distance(c.H, HUES[fam]), 55, f"{label}: {key} {getattr(p, key)}")

    def test_crimson_wallpaper_keeps_red_red(self):
        # Red leans toward the wallpaper's crimson but only a quarter of the way (critical must stay
        # apart from orange), and never wraps round 0/360 (it once came out blue).
        h = lch(build_palette(CRIMSON, "/tmp/r.jpg").red).H
        self.assertLess(hue_distance(h, 2.25), hue_distance(HUES["red"], 2.25))
        self.assertLess(hue_distance(h, HUES["red"]), 15)

    def test_red_and_orange_stay_apart(self):
        for label, p in all_palettes():
            if "mono" in label:
                continue  # grey accents: no hue to compare
            self.assertGreaterEqual(hue_distance(lch(p.red).H, lch(p.orange).H), 15, label)

    def test_grey_wallpaper_keeps_canonical_hues(self):
        p = build_palette(GREY, "/tmp/g.jpg")
        for key in ("red", "orange", "yellow", "green", "cyan", "blue", "magenta"):
            self.assertLess(hue_distance(lch(getattr(p, key)).H, HUES[key]), 3, key)


class TestContrast(unittest.TestCase):
    """WCAG 2 ratios over every fixture x flavour x mode."""

    def test_muted_text(self):
        for label, p in all_palettes():
            for bg in ("base", "mantle"):
                self.assertGreaterEqual(contrast(p.subtext0, getattr(p, bg)), 4.5, f"{label}: subtext0 on {bg}")
            for bg in ("surface0", "surface1"):
                self.assertGreaterEqual(contrast(p.subtext0, getattr(p, bg)), 3.0, f"{label}: subtext0 on {bg}")

    def test_text_ladder_is_ordered(self):
        # Catppuccin order: text > subtext1 > subtext0 in dark, the inverse in light.
        for label, p in all_palettes():
            ys = [luminance(getattr(p, k)) for k in ("text", "subtext1", "subtext0")]
            self.assertEqual(ys, sorted(ys, reverse=p.mode == "dark"), label)

    def test_text_on_accent(self):
        for label, p in all_palettes():
            self.assertGreaterEqual(contrast(p.accent, p.crust), 4.5, label)

    def test_light_ansi_on_background(self):
        for label, p in all_palettes():
            if p.mode == "light":
                for key in ("red", "orange", "yellow", "green", "cyan", "blue", "magenta"):
                    self.assertGreaterEqual(contrast(getattr(p, key), p.background), 4.5, f"{label}: {key}")


if __name__ == "__main__":
    unittest.main()
