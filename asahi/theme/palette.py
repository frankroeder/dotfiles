"""Build a semantic desktop palette from wallpaper representatives.

Pipeline mirrors omagen's Source direction (closest-to-source) with contrast
targets suited to Hyprland / Quickshell / Ghostty / LibreWolf.
"""

from __future__ import annotations

from dataclasses import asdict, dataclass

from .extract import Representative
from .oklab import OKLCH, clamp, hex_from_oklch, hue_distance


LIGHT_MODE_THRESHOLD = 0.62


@dataclass
class Palette:
    mode: str
    wallpaper: str
    variant: str

    # Omagen-like semantic roles
    accent: str
    selection: str
    muted: str
    background: str
    dark_background: str
    darker_background: str
    lighter_background: str
    foreground: str
    dark_foreground: str
    light_foreground: str
    bright_foreground: str

    red: str
    orange: str
    yellow: str
    green: str
    cyan: str
    blue: str
    magenta: str
    brown: str
    bright_red: str
    bright_yellow: str
    bright_green: str
    bright_cyan: str
    bright_blue: str
    bright_magenta: str

    # Catppuccin-shaped roles used by Quickshell DefaultTheme / Style
    crust: str
    mantle: str
    base: str
    surface0: str
    surface1: str
    surface2: str
    overlay0: str
    overlay1: str
    overlay2: str
    text: str
    subtext0: str
    subtext1: str
    rosewater: str
    flamingo: str
    pink: str
    mauve: str
    maroon: str
    peach: str
    teal: str
    sky: str
    sapphire: str
    lavender: str

    def to_dict(self) -> dict:
        return asdict(self)


def _pick(reps: list[Representative], prefer: str) -> Representative:
    """prefer: accent|selection|muted"""
    if prefer == "accent":
        chromatic = [r for r in reps if r.chroma >= 0.04]
        pool = chromatic or reps
        return max(pool, key=lambda r: (r.chroma * 1.4 + (0.5 - abs(r.L - 0.55)), r.weight))
    if prefer == "selection":
        chromatic = [r for r in reps if r.chroma >= 0.02]
        pool = chromatic or reps
        return max(pool, key=lambda r: (r.weight, r.chroma))
    return sorted(reps, key=lambda r: (abs(r.L - 0.45), r.chroma))[0]


def _ansi(h: float, mode: str, role: str) -> str:
    # Target hues roughly match terminal ANSI expectations, tinted by wallpaper hue families.
    targets = {
        "red": (25, 0.66, 0.52, 1.00),
        "orange": (55, 0.68, 0.53, 0.88),
        "yellow": (95, 0.70, 0.55, 0.78),
        "green": (145, 0.63, 0.47, 0.64),
        "cyan": (195, 0.71, 0.56, 0.70),
        "blue": (255, 0.67, 0.50, 0.62),
        "magenta": (320, 0.68, 0.51, 0.84),
        "brown": (55, 0.52, 0.42, 0.44),
    }
    th, dark_l, light_l, chroma_scale = targets[role]
    l = dark_l if mode == "dark" else light_l
    # Bias hue toward nearest wallpaper family when close enough.
    c = 0.12 * chroma_scale
    return hex_from_oklch(l, c, th if h is None else (0.35 * th + 0.65 * h if hue_distance(th, h) < 55 else th))


def _nearest_hue(reps: list[Representative], target: float) -> float:
    chromatic = [r for r in reps if r.chroma >= 0.03]
    pool = chromatic or reps
    best = min(pool, key=lambda r: hue_distance(r.hue, target))
    return best.hue


def build_palette(reps: list[Representative], wallpaper: str, variant: str = "source") -> Palette:
    total_w = sum(r.weight for r in reps) or 1.0
    avg_l = sum(r.L * r.weight for r in reps) / total_w
    mode = "light" if avg_l >= LIGHT_MODE_THRESHOLD else "dark"

    surface = min(reps, key=lambda r: r.L) if mode == "dark" else max(reps, key=lambda r: r.L)
    foreground = max(reps, key=lambda r: r.L) if mode == "dark" else min(reps, key=lambda r: r.L)
    accent = _pick(reps, "accent")
    selection = _pick(reps, "selection")
    muted = _pick(reps, "muted")

    s = surface.lab.to_oklch()
    f = foreground.lab.to_oklch()
    a = accent.lab.to_oklch()
    sel = selection.lab.to_oklch()
    m = muted.lab.to_oklch()

    if mode == "dark":
        bg_l = clamp(s.L, 0.11, 0.24)
        bg_c = clamp(s.C, 0.0, 0.055)
        accent_l = clamp(a.L, 0.58, 0.75)
        accent_c = clamp(a.C, 0.0, 0.22)
        fg_c = clamp(f.C * 0.45, 0.0, 0.075)
        sel_c = clamp(sel.C * 0.55, 0.025, 0.11)
        muted_c = clamp(m.C * 0.35, 0.0, 0.050)
        background = hex_from_oklch(bg_l, bg_c, s.H)
        dark_background = hex_from_oklch(bg_l - 0.035, bg_c * 0.85, s.H)
        darker_background = hex_from_oklch(bg_l - 0.065, bg_c * 0.70, s.H)
        lighter_background = hex_from_oklch(bg_l + 0.070, bg_c * 1.10, s.H)
        foreground_hex = hex_from_oklch(0.88, fg_c, f.H)
        dark_foreground = hex_from_oklch(0.58, fg_c * 0.85, f.H)
        light_foreground = hex_from_oklch(0.94, fg_c * 0.70, f.H)
        bright_foreground = hex_from_oklch(0.98, fg_c * 0.45, f.H)
        accent_hex = hex_from_oklch(accent_l, accent_c, a.H)
        selection_hex = hex_from_oklch(bg_l + 0.16, sel_c, sel.H)
        muted_hex = hex_from_oklch(bg_l + 0.22, muted_c, m.H)
        # Catppuccin surfaces
        crust = darker_background
        mantle = dark_background
        base = background
        surface0 = lighter_background
        surface1 = hex_from_oklch(bg_l + 0.12, bg_c * 1.05, s.H)
        surface2 = hex_from_oklch(bg_l + 0.18, bg_c * 1.00, s.H)
        overlay0 = muted_hex
        overlay1 = dark_foreground
        overlay2 = hex_from_oklch(0.70, fg_c * 0.6, f.H)
        text = foreground_hex
        subtext0 = dark_foreground
        subtext1 = light_foreground
    else:
        bg_l = clamp(s.L, 0.90, 0.97)
        bg_c = clamp(s.C * 0.45, 0.0, 0.030)
        accent_l = clamp(a.L, 0.43, 0.60)
        accent_c = clamp(a.C, 0.0, 0.20)
        fg_c = clamp(f.C * 0.40, 0.0, 0.065)
        sel_c = clamp(sel.C * 0.50, 0.020, 0.095)
        muted_c = clamp(m.C * 0.30, 0.0, 0.045)
        background = hex_from_oklch(bg_l, bg_c, s.H)
        dark_background = hex_from_oklch(bg_l - 0.08, bg_c * 1.10, s.H)
        darker_background = hex_from_oklch(bg_l - 0.13, bg_c * 1.15, s.H)
        lighter_background = hex_from_oklch(min(0.99, bg_l + 0.03), bg_c * 0.85, s.H)
        foreground_hex = hex_from_oklch(0.28, fg_c, f.H)
        dark_foreground = hex_from_oklch(0.42, fg_c * 0.85, f.H)
        light_foreground = hex_from_oklch(0.20, fg_c * 0.70, f.H)
        bright_foreground = hex_from_oklch(0.14, fg_c * 0.45, f.H)
        accent_hex = hex_from_oklch(accent_l, accent_c, a.H)
        selection_hex = hex_from_oklch(bg_l - 0.10, sel_c, sel.H)
        muted_hex = hex_from_oklch(bg_l - 0.18, muted_c, m.H)
        crust = lighter_background
        mantle = background
        base = dark_background
        surface0 = darker_background
        surface1 = hex_from_oklch(bg_l - 0.16, bg_c * 1.1, s.H)
        surface2 = hex_from_oklch(bg_l - 0.22, bg_c * 1.15, s.H)
        overlay0 = muted_hex
        overlay1 = dark_foreground
        overlay2 = hex_from_oklch(0.50, fg_c * 0.6, f.H)
        text = foreground_hex
        subtext0 = dark_foreground
        subtext1 = hex_from_oklch(0.35, fg_c * 0.7, f.H)

    # Variant nudges (Calm / Vibrant / Balanced lite — omagen gallery subset)
    if variant == "calm":
        accent_hex = hex_from_oklch(clamp(accent_l - 0.04, 0.4, 0.8), accent_c * 0.65, a.H)
    elif variant == "vibrant":
        accent_hex = hex_from_oklch(clamp(accent_l + 0.04, 0.4, 0.85), min(0.24, accent_c * 1.35), a.H)
    elif variant == "deep":
        background = hex_from_oklch(max(0.08, bg_l - 0.04), bg_c, s.H)
        base = background

    red_h = _nearest_hue(reps, 25)
    yellow_h = _nearest_hue(reps, 95)
    green_h = _nearest_hue(reps, 145)
    cyan_h = _nearest_hue(reps, 195)
    blue_h = _nearest_hue(reps, 255)
    magenta_h = _nearest_hue(reps, 320)
    orange_h = _nearest_hue(reps, 55)

    red = _ansi(red_h, mode, "red")
    orange = _ansi(orange_h, mode, "orange")
    yellow = _ansi(yellow_h, mode, "yellow")
    green = _ansi(green_h, mode, "green")
    cyan = _ansi(cyan_h, mode, "cyan")
    blue = _ansi(blue_h, mode, "blue")
    magenta = _ansi(magenta_h, mode, "magenta")
    brown = _ansi(orange_h, mode, "brown")

    def brighten(role: str, h: float) -> str:
        # Keep ANSI family hue (target-biased), lift L/C for bright slots.
        targets = {
            "red": 25, "yellow": 95, "green": 145, "cyan": 195, "blue": 255, "magenta": 320,
        }
        th = targets[role]
        use_h = (0.35 * th + 0.65 * h) if hue_distance(th, h) < 55 else th
        if mode == "dark":
            return hex_from_oklch(0.78, 0.14, use_h)
        return hex_from_oklch(0.48, 0.14, use_h)

    return Palette(
        mode=mode,
        wallpaper=wallpaper,
        variant=variant,
        accent=accent_hex,
        selection=selection_hex,
        muted=muted_hex,
        background=background,
        dark_background=dark_background,
        darker_background=darker_background,
        lighter_background=lighter_background,
        foreground=foreground_hex,
        dark_foreground=dark_foreground,
        light_foreground=light_foreground,
        bright_foreground=bright_foreground,
        red=red,
        orange=orange,
        yellow=yellow,
        green=green,
        cyan=cyan,
        blue=blue,
        magenta=magenta,
        brown=brown,
        bright_red=brighten("red", red_h),
        bright_yellow=brighten("yellow", yellow_h),
        bright_green=brighten("green", green_h),
        bright_cyan=brighten("cyan", cyan_h),
        bright_blue=brighten("blue", blue_h),
        bright_magenta=brighten("magenta", magenta_h),
        crust=crust,
        mantle=mantle,
        base=base,
        surface0=surface0,
        surface1=surface1,
        surface2=surface2,
        overlay0=overlay0,
        overlay1=overlay1,
        overlay2=overlay2,
        text=text,
        subtext0=subtext0,
        subtext1=subtext1,
        rosewater=hex_from_oklch(0.90 if mode == "dark" else 0.55, 0.04, a.H),
        flamingo=hex_from_oklch(0.84 if mode == "dark" else 0.52, 0.06, red_h),
        pink=magenta,
        mauve=hex_from_oklch(0.72 if mode == "dark" else 0.50, 0.12, magenta_h),
        maroon=hex_from_oklch(0.68 if mode == "dark" else 0.48, 0.10, red_h),
        peach=orange,
        teal=cyan,
        sky=hex_from_oklch(0.78 if mode == "dark" else 0.55, 0.10, cyan_h),
        sapphire=hex_from_oklch(0.70 if mode == "dark" else 0.48, 0.11, blue_h),
        lavender=hex_from_oklch(0.78 if mode == "dark" else 0.52, 0.09, blue_h),
    )
