#!/usr/bin/env python3
"""Writer checks for asahi-autotheme artifacts (no wallpaper / ImageMagick)."""

from __future__ import annotations

import importlib.util
import json
import os
import sys
import tempfile
import unittest
from importlib.machinery import SourceFileLoader
from pathlib import Path
from unittest import mock

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT.parent))

from theme.apply import (  # noqa: E402
    preview_ghostty,
    write_btop_theme,
    write_colors_env,
    write_firefox_scheme,
    write_ghostty_gtk_css,
    write_ghostty_theme,
    write_gtk_css,
    write_hyprland_lua,
    write_hyprlock_conf,
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


def _light_palette():
    reps = [
        Representative(lab=from_srgb8(250, 248, 240), weight=100, hex="#faf8f0"),
        Representative(lab=from_srgb8(230, 200, 160), weight=40, hex="#e6c8a0"),
        Representative(lab=from_srgb8(40, 36, 32), weight=10, hex="#282420"),
    ]
    return build_palette(reps, "/tmp/light.jpg", variant="source")


def _load_cli():
    path = ROOT.parent / "bin" / "asahi-autotheme"
    loader = SourceFileLoader("asahi_autotheme", str(path))
    module = importlib.util.module_from_spec(importlib.util.spec_from_loader(loader.name, loader))
    loader.exec_module(module)
    return module


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
        self.assertIn("$lock_fg = rgb(", text)
        self.assertIn("$lock_check = rgba(", text)
        self.assertIn("$lock_caps = rgb(" + self.palette.yellow.removeprefix("#"), text)
        self.assertRegex(text, r"\$lock_ring = rgba\([0-9a-fA-F]{8}\)")
        self.assertRegex(text, r"\$lock_band = rgba\([0-9a-fA-F]{8}\)")
        self.assertEqual((self.root / "lock-fade-top.png").read_bytes()[:8], b"\x89PNG\r\n\x1a\n")

    def test_gtk_css_adwaita(self):
        path = self.root / "gtk.css"
        write_gtk_css(self.palette, path)
        text = path.read_text(encoding="utf-8")
        self.assertIn("@define-color accent_bg_color", text)
        self.assertIn("@define-color window_bg_color", text)
        self.assertIn(self.palette.accent, text)

    def test_terminal_greys_follow_the_mode(self):
        # Catppuccin Mocha / Latte: 0/7/8/15 swap roles in light mode, so color 0 (zsh
        # user@host) stays dark on a light background.
        expect = {
            "dark": lambda p: (p.surface1, p.subtext1, p.overlay0, p.bright_foreground),
            "light": lambda p: (p.subtext1, p.surface2, p.overlay2, p.surface1),
        }
        for p in (_dark_palette(), _light_palette()):
            write_ghostty_theme(p, self.root / "ghostty.theme")
            write_colors_env(p, self.root / "colors.env")
            lines = (self.root / "ghostty.theme").read_text(encoding="utf-8").splitlines()
            pal = [line.split("=")[-1] for line in lines if line.startswith("palette = ")]
            env = [line.split('"')[1] for line in (self.root / "colors.env").read_text(encoding="utf-8").splitlines() if "_TERM_" in line]
            self.assertEqual(len(pal), 16)
            self.assertEqual(env[5:], pal, "colors.env (after mode/bg/fg/selection/cursor) mirrors the Ghostty palette")
            self.assertEqual((pal[0], pal[7], pal[8], pal[15]), expect[p.mode](p), p.mode)
            self.assertIn(f"cursor-text = {p.crust}", lines)

    def test_text_on_accent_is_crust(self):
        for p in (_dark_palette(), _light_palette()):
            write_gtk_css(p, self.root / "gtk.css")
            write_ghostty_gtk_css(p, self.root / "adaptive.css")
            write_firefox_scheme(p, self.root / "firefox.json")
            for css in ("gtk.css", "adaptive.css"):
                self.assertIn(f"@define-color accent_fg_color {p.crust};", (self.root / css).read_text(encoding="utf-8"))
            msg = json.loads((self.root / "firefox.json").read_text(encoding="utf-8"))
            self.assertEqual(msg["colours"]["onPrimary"], p.crust.lstrip("#"))

    def test_atomic_write_leaves_only_the_file(self):
        path = self.root / "colors.env"
        write_colors_env(self.palette, path)
        write_colors_env(self.palette, path)
        self.assertEqual([p.name for p in self.root.iterdir()], ["colors.env"])
        self.assertEqual(path.stat().st_mode & 0o777, 0o644)

    def test_firefox_scheme_is_caelestiafox_shaped(self):
        path = self.root / "firefox.json"
        write_firefox_scheme(self.palette, path)
        msg = json.loads(path.read_text(encoding="utf-8"))
        self.assertEqual(msg["mode"], self.palette.mode)
        colours = msg["colours"]
        self.assertEqual(colours["primary"], self.palette.accent.lstrip("#"))
        self.assertEqual(colours["surfaceDim"], self.palette.mantle.lstrip("#"))
        # CaelestiaFox prepends '#' itself.
        self.assertTrue(all(len(c) == 6 and not c.startswith("#") for c in colours.values()))

    def test_btop_theme_keys(self):
        path = self.root / "btop.theme"
        write_btop_theme(self.palette, path)
        text = path.read_text(encoding="utf-8")
        self.assertIn(f'theme[main_bg]="{self.palette.background}"', text)
        self.assertIn(f'theme[hi_fg]="{self.palette.accent}"', text)

    def test_btop_matches_the_light_terminal(self):
        # Light base is a shade darker than the terminal background btop sits on.
        p = _light_palette()
        self.assertNotEqual(p.base, p.background)
        write_btop_theme(p, self.root / "btop.theme")
        self.assertIn(f'theme[main_bg]="{p.background}"', (self.root / "btop.theme").read_text(encoding="utf-8"))

    def test_hyprland_groupbar(self):
        path = self.root / "hyprland.lua"
        write_hyprland_lua(self.palette, path)
        text = path.read_text(encoding="utf-8")
        self.assertIn("col.active_border", text)
        self.assertIn("groupbar", text)
        self.assertIn("text_color", text)

    def test_preview_ghostty_installs_theme_ghostty_reads(self):
        cfg = self.root / "ghostty"
        cfg.mkdir()
        (cfg / "themes").mkdir()
        state = self.root / "ghostty.theme"
        paths = preview_ghostty(
            self.palette, ghostty_cfg=cfg, theme_state=state, reload=False
        )
        installed = Path(paths["ghostty_installed"])
        self.assertEqual(installed, cfg / "themes" / "asahi-adaptive")
        theme = installed.read_text(encoding="utf-8")
        self.assertIn(f"background = {self.palette.background}", theme)
        self.assertIn(f"foreground = {self.palette.foreground}", theme)
        css = Path(paths["ghostty_css"]).read_text(encoding="utf-8")
        self.assertIn(f"@define-color window_bg_color {self.palette.background}", css)
        extra = Path(paths["ghostty_extra"]).read_text(encoding="utf-8")
        self.assertIn("window-theme = ghostty", extra)
        self.assertIn("gtk-custom-css", extra)
        # state file alone is not what Ghostty loads
        self.assertNotEqual(state, installed)
        self.assertTrue(state.is_file())

    def test_autotheme_preview_calls_preview_ghostty(self):
        src = Path(__file__).resolve().parents[2] / "bin" / "asahi-autotheme"
        text = src.read_text(encoding="utf-8")
        self.assertIn("preview_ghostty", text)
        self.assertNotIn("write_ghostty_theme(palette, state_dir()", text)
        self.assertNotIn("reload_ghostty()", text)


class TestAutothemeCli(unittest.TestCase):
    """Bare runs (login autostart) restore what is on screen, in the saved flavour."""

    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.state = Path(self.tmp.name)
        self.env = mock.patch.dict(os.environ, {"XDG_STATE_HOME": str(self.state)})
        self.env.start()
        self.cli = _load_cli()

    def tearDown(self):
        self.env.stop()
        self.tmp.cleanup()

    def test_wallpaper_prefers_the_one_on_screen(self):
        shown, themed = self.state / "shown.jpg", self.state / "themed.jpg"
        shown.touch()
        themed.touch()
        (self.state / "asahi-theme").mkdir()
        (self.state / "asahi-theme" / "wallpaper").write_text(f"{themed}\n", encoding="utf-8")
        (self.state / "quickshell").mkdir()
        (self.state / "quickshell" / "wallpaper.conf").write_text(str(shown), encoding="utf-8")
        self.assertEqual(self.cli.resolve_wallpaper(None), shown)
        shown.unlink()
        self.assertEqual(self.cli.resolve_wallpaper(None), themed)

    def test_bare_run_keeps_the_saved_flavour(self):
        self.assertEqual(self.cli.saved_variant(), "source")
        colors = self.cli.state_dir() / "colors.json"
        colors.write_text(json.dumps({"variant": "calm"}), encoding="utf-8")
        self.assertEqual(self.cli.saved_variant(), "calm")
        colors.write_text(json.dumps({"variant": "retired"}), encoding="utf-8")
        self.assertEqual(self.cli.saved_variant(), "source")


if __name__ == "__main__":
    unittest.main()
