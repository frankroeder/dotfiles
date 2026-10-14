"""Build a semantic desktop palette from wallpaper representatives.

Pipeline mirrors omagen's Source direction (closest-to-source) with contrast
targets suited to Hyprland / Quickshell / Ghostty / Firefox.
"""

from __future__ import annotations

from dataclasses import asdict, dataclass

from .extract import Representative
from .oklab import clamp, hex_from_oklch, hue_distance, max_chroma

LIGHT_MODE_THRESHOLD = 0.62

# ANSI hue families (OKLCH degrees). Every named color belongs to one, so red stays
# red (critical), yellow yellow (warning) and green green (ok) on any wallpaper.
HUES = {"red": 25, "orange": 55, "yellow": 95, "green": 145, "cyan": 195, "blue": 255, "magenta": 320}


@dataclass(frozen=True)
class Flavor:
    """Scheme knobs applied on top of the wallpaper's own colors.

    Same idea as matugen's `matugen_type`: one source image, several characters.
    Saturation is a *fraction of the room available* (grey .. sRGB gamut edge),
    not a multiplier — a multiplier put every strong flavour past the edge, where
    they all clipped to the same color and looked identical.
    """

    accent_sat: float = 0.0   # <0 toward grey, >0 toward the gamut edge, 0 = wallpaper's own
    accent_dl: float = 0.0    # accent lightness offset
    surface_c: float = 1.0    # background / surface / selection tint multiplier
    ansi_sat: float = 0.0     # same axis as accent_sat, for the ANSI + named colors
    fidelity: bool = False    # follow wallpaper hues more closely inside each ANSI hue family


# Five, deliberately far apart. The axes that actually read on a desktop are how
# saturated the accents are and how much the *surfaces* carry the wallpaper's
# cast, so the flavours pull those in opposite directions rather than all just
# turning the chroma up by different amounts.
FLAVORS: dict[str, Flavor] = {
    # closest to the wallpaper: its own chroma, its own surface tint
    "source": Flavor(),
    # the whole desktop washed in the wallpaper's hues, followed closely
    "content": Flavor(accent_sat=0.30, surface_c=1.60, ansi_sat=0.15, fidelity=True),
    # gamut-edge accents on deliberately neutral panels — the opposite of content
    "vibrant": Flavor(accent_sat=0.95, accent_dl=0.05, surface_c=0.45, ansi_sat=0.75),
    # soft and recessive
    "calm": Flavor(accent_sat=-0.60, accent_dl=-0.04, surface_c=0.75, ansi_sat=-0.50),
    # greyscale
    "mono": Flavor(accent_sat=-1.0, surface_c=0.0, ansi_sat=-1.0),
}


# Below this the hue is numerical noise: a greyscale wallpaper still reports
# *some* angle, and amplifying it invents a color that is not in the image.
GREY_CHROMA = 0.012


def _saturate(c: float, l: float, h: float, amount: float) -> float:
    """Move a chroma along grey .. gamut-edge. -1 is grey, +1 is as vivid as sRGB allows."""
    if amount == 0.0:
        return c
    if amount < 0.0:
        return c * (1.0 + clamp(amount, -1.0, 0.0))
    if c < GREY_CHROMA:
        return c   # nothing to amplify — stay honest about a colorless source
    return c + (max_chroma(l, h) - c) * clamp(amount, 0.0, 1.0)


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
    return min(reps, key=lambda r: (abs(r.L - 0.45), r.chroma))


def _nearest_hue(reps: list[Representative], target: float) -> float | None:
    """Hue of the colorful sample closest to `target`; None when the wallpaper has no color."""
    chromatic = [r for r in reps if r.chroma >= 0.03]
    if not chromatic:
        return None
    return min(chromatic, key=lambda r: hue_distance(r.hue, target)).hue


def _toward(th: float, h: float, k: float = 0.65) -> float:
    """Turn hue `th` by `k` toward `h` along the short arc (a plain average breaks at 0/360)."""
    return (th + k * ((h - th + 180) % 360 - 180)) % 360


def _family_hue(th: float, h: float | None, k: float) -> float:
    """Family hue `th` turned the fraction `k` toward the wallpaper's `h` when that is within 55°;
    otherwise, or with no color, `th`."""
    if h is None or hue_distance(th, h) >= 55:
        return th
    return _toward(th, h, k)


def build_palette(
    reps: list[Representative], wallpaper: str, variant: str = "source", mode: str = "auto"
) -> Palette:
    fl = FLAVORS.get(variant, FLAVORS["source"])
    total_w = sum(r.weight for r in reps) or 1.0
    avg_l = sum(r.L * r.weight for r in reps) / total_w
    if mode not in ("dark", "light"):
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

    # Lightness ladders are Catppuccin-ordered (dark: text > subtext1 > subtext0 > overlays,
    # light the inverse) and sized for WCAG: subtext0 >= 4.5:1 on base/mantle, >= 3:1 on
    # surface0/1; the accent >= 4.5:1 against crust, which carries text on accent.
    if mode == "dark":
        bg_l = clamp(s.L, 0.11, 0.24)
        bg_c = clamp(s.C, 0.0, 0.055) * fl.surface_c
        accent_l = clamp(a.L + fl.accent_dl, 0.64, 0.78)
        accent_c = _saturate(clamp(a.C, 0.0, 0.22), accent_l, a.H, fl.accent_sat)
        fg_c = clamp(f.C * 0.45, 0.0, 0.075) * fl.surface_c
        sel_c = clamp(sel.C * 0.55, 0.025, 0.11) * fl.surface_c
        muted_c = clamp(m.C * 0.35, 0.0, 0.050) * fl.surface_c
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
        muted_hex = hex_from_oklch(bg_l + 0.30, muted_c, m.H)   # overlay0, terminal color 8
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
        subtext0 = hex_from_oklch(0.72, fg_c * 0.85, f.H)
        subtext1 = hex_from_oklch(0.80, fg_c * 0.70, f.H)
    else:
        bg_l = clamp(s.L, 0.90, 0.97)
        bg_c = clamp(s.C * 0.45, 0.0, 0.030) * fl.surface_c
        accent_l = clamp(a.L + fl.accent_dl, 0.40, 0.50)
        accent_c = _saturate(clamp(a.C, 0.0, 0.20), accent_l, a.H, fl.accent_sat)
        fg_c = clamp(f.C * 0.40, 0.0, 0.065) * fl.surface_c
        sel_c = clamp(sel.C * 0.50, 0.020, 0.095) * fl.surface_c
        muted_c = clamp(m.C * 0.30, 0.0, 0.045) * fl.surface_c
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
        overlay2 = hex_from_oklch(0.55, fg_c * 0.6, f.H)   # terminal color 8
        text = foreground_hex
        subtext0 = hex_from_oklch(0.38, fg_c * 0.85, f.H)
        subtext1 = hex_from_oklch(0.35, fg_c * 0.7, f.H)

    # ANSI slots and named accents (rosewater … lavender): the family hue tinted by the
    # wallpaper's nearest one, chroma by flavour. Light-mode L keeps them >= 4.5:1 on background.
    wall_hues = {fam: _nearest_hue(reps, th) for fam, th in HUES.items()}

    def tone(fam: str, dark_l: float, light_l: float, c: float) -> str:
        # Red and orange are 30° apart and mean critical vs warning: they lean a quarter of the way.
        # `content` follows the wallpaper 90% (never 100%: that sat on the family edge).
        k = 0.25 if fam in ("red", "orange") else 0.9 if fl.fidelity else 0.65
        hue = _family_hue(HUES[fam], wall_hues[fam], k)
        l = dark_l if mode == "dark" else light_l
        return hex_from_oklch(l, _saturate(c, l, hue, fl.ansi_sat), hue)

    red = tone("red", 0.66, 0.48, 0.12)
    orange = tone("orange", 0.68, 0.48, 0.12 * 0.88)
    yellow = tone("yellow", 0.70, 0.46, 0.12 * 0.78)
    green = tone("green", 0.63, 0.47, 0.12 * 0.64)
    cyan = tone("cyan", 0.71, 0.47, 0.12 * 0.70)
    blue = tone("blue", 0.67, 0.47, 0.12 * 0.62)
    magenta = tone("magenta", 0.68, 0.48, 0.12 * 0.84)

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
        brown=tone("orange", 0.52, 0.42, 0.12 * 0.44),
        bright_red=tone("red", 0.78, 0.48, 0.14),
        bright_yellow=tone("yellow", 0.78, 0.48, 0.14),
        bright_green=tone("green", 0.78, 0.48, 0.14),
        bright_cyan=tone("cyan", 0.78, 0.48, 0.14),
        bright_blue=tone("blue", 0.78, 0.48, 0.14),
        bright_magenta=tone("magenta", 0.78, 0.48, 0.14),
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
        rosewater=tone("red", 0.90, 0.55, 0.04),
        flamingo=tone("red", 0.84, 0.52, 0.06),
        pink=magenta,
        mauve=tone("magenta", 0.72, 0.50, 0.12),
        maroon=tone("red", 0.68, 0.48, 0.10),
        peach=orange,
        teal=cyan,
        sky=tone("cyan", 0.78, 0.55, 0.10),
        sapphire=tone("blue", 0.70, 0.48, 0.11),
        lavender=tone("blue", 0.78, 0.52, 0.09),
    )
