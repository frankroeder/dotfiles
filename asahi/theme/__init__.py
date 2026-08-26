"""asahi wallpaper adaptive theming package."""

from .extract import extract_representatives
from .palette import Palette, build_palette
from .apply import apply_live, state_dir, write_all

__all__ = [
    "Palette",
    "apply_live",
    "build_palette",
    "extract_representatives",
    "state_dir",
    "write_all",
]
