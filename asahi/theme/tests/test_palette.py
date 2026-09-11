#!/usr/bin/env python3
"""Minimal unit checks for asahi theme extraction (no ImageMagick required for oklab)."""

from __future__ import annotations

import sys
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT.parent))

from theme.oklab import from_srgb8, hex_from_oklch, hue_distance  # noqa: E402
from theme.extract import Representative, merge_close  # noqa: E402
from theme.palette import build_palette  # noqa: E402


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

    def test_merge_close(self):
        a = Representative(lab=from_srgb8(10, 10, 10), weight=5, hex="#0a0a0a")
        b = Representative(lab=from_srgb8(12, 12, 12), weight=3, hex="#0c0c0c")
        merged = merge_close([a, b], threshold=0.05)
        self.assertEqual(len(merged), 1)


if __name__ == "__main__":
    unittest.main()
