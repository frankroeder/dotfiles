#!/usr/bin/env python3
"""Writer checks for asahi-autotheme artifacts (no wallpaper / ImageMagick)."""

from __future__ import annotations

import json
import sys
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT.parent))

from theme.apply import (  # noqa: E402
    write_btop_theme,
    write_chromium_policy,
    write_gtk_css,
    write_hyprland_lua,
    write_hyprlock_conf,
    write_librewolf_css,
)
from theme.oklab import from_srgb8  # noqa: E402
from theme.extract import Representative  # noqa: E402
from theme.palette import build_palette  # noqa: E402


def _dark_palette():
    reps = [
        Representative(lab=from_srgb8(10, 20, 40), weight=100, hex="#0a1428"),
        Representative(lab=from_srgb8(200, 80, 120), weight=40, hex="#c85078"),
        Representative(lab=from_srgb8(220, 220, 240), weight=20, hex="#dcdcf0"),
    ]
    return build_palette(reps, "/tmp/x.jpg", variant="source")


class TestApplyWriters(unittest.TestCase):
    def setUp(self):
        self.palette = _dark_palette()
        self.tmp = tempfile.TemporaryDirectory()
        self.root = Path(self.tmp.name)

    def tearDown(self):
        self.tmp.cleanup()

    def test_hyprlock_vars(self):
        path = self.root / "hyprlock.conf"
        write_hyprlock_conf(self.palette, path)
        text = path.read_text(encoding="utf-8")
        self.assertIn("$lock_bg = rgb(", text)
        self.assertIn("$lock_accent = rgb(", text)
        self.assertIn("$lock_outer = rgba(", text)

    def test_gtk_css_adwaita(self):
        path = self.root / "gtk.css"
        write_gtk_css(self.palette, path)
        text = path.read_text(encoding="utf-8")
        self.assertIn("@define-color accent_bg_color", text)
        self.assertIn("@define-color window_bg_color", text)
        self.assertIn(self.palette.accent, text)

    def test_chromium_policy(self):
        path = self.root / "chromium-theme.json"
        write_chromium_policy(self.palette, path)
        data = json.loads(path.read_text(encoding="utf-8"))
        self.assertEqual(data["BrowserThemeColor"], self.palette.background)

    def test_librewolf_uses_live_variable_names(self):
        path = self.root / "librewolf.css"
        write_librewolf_css(self.palette, path)
        text = path.read_text(encoding="utf-8")
        self.assertIn("--urlbarview-background-color-selected", text)
        self.assertIn("--toolbar-field-background-color", text)
        # Pre-130 spellings fail silently, which is how highlights went stale.
        for dead in ("--urlbarView-highlight", "--lwt-toolbar-field", "--arrowpanel-",
                     "--tab-selected-bgcolor", "--urlbar-box-bgcolor", "--toolbar-color:"):
            self.assertNotIn(dead, text)

    def test_btop_theme_keys(self):
        path = self.root / "btop.theme"
        write_btop_theme(self.palette, path)
        text = path.read_text(encoding="utf-8")
        self.assertIn(f'theme[main_bg]="{self.palette.base}"', text)
        self.assertIn(f'theme[hi_fg]="{self.palette.accent}"', text)

    def test_hyprland_groupbar(self):
        path = self.root / "hyprland.lua"
        write_hyprland_lua(self.palette, path)
        text = path.read_text(encoding="utf-8")
        self.assertIn("col.active_border", text)
        self.assertIn("groupbar", text)
        self.assertIn("text_color", text)


if __name__ == "__main__":
    unittest.main()
