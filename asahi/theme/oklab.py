"""OKLab / OKLCH helpers (omagen-inspired, stdlib only)."""

from __future__ import annotations

import math
from dataclasses import dataclass


@dataclass(frozen=True)
class OKLab:
    L: float
    a: float
    b: float

    def to_oklch(self) -> "OKLCH":
        chroma = math.hypot(self.a, self.b)
        hue = math.atan2(self.b, self.a) * 180.0 / math.pi
        if hue < 0:
            hue += 360.0
        return OKLCH(self.L, chroma, hue)


@dataclass(frozen=True)
class OKLCH:
    L: float
    C: float
    H: float

    def to_oklab(self) -> OKLab:
        h = normalize_hue(self.H) * math.pi / 180.0
        return OKLab(self.L, self.C * math.cos(h), self.C * math.sin(h))


def srgb_to_linear(value: float) -> float:
    if value <= 0.04045:
        return value / 12.92
    return ((value + 0.055) / 1.055) ** 2.4


def linear_to_srgb(value: float) -> float:
    value = clamp(value, 0.0, 1.0)
    if value <= 0.0031308:
        return value * 12.92
    return 1.055 * (value ** (1.0 / 2.4)) - 0.055


def from_srgb8(r: int, g: int, b: int) -> OKLab:
    lr = srgb_to_linear(r / 255.0)
    lg = srgb_to_linear(g / 255.0)
    lb = srgb_to_linear(b / 255.0)
    l = 0.4122214708 * lr + 0.5363325363 * lg + 0.0514459929 * lb
    m = 0.2119034982 * lr + 0.6806995451 * lg + 0.1073969566 * lb
    s = 0.0883024619 * lr + 0.2817188376 * lg + 0.6299787005 * lb
    l_root = l ** (1.0 / 3.0)
    m_root = m ** (1.0 / 3.0)
    s_root = s ** (1.0 / 3.0)
    return OKLab(
        0.2104542553 * l_root + 0.7936177850 * m_root - 0.0040720468 * s_root,
        1.9779984951 * l_root - 2.4285922050 * m_root + 0.4505937099 * s_root,
        0.0259040371 * l_root + 0.7827717662 * m_root - 0.8086757660 * s_root,
    )


def oklab_to_linear_srgb(lab: OKLab) -> tuple[float, float, float]:
    l_root = lab.L + 0.3963377774 * lab.a + 0.2158037573 * lab.b
    m_root = lab.L - 0.1055613458 * lab.a - 0.0638541728 * lab.b
    s_root = lab.L - 0.0894841775 * lab.a - 1.2914855480 * lab.b
    l = l_root * l_root * l_root
    m = m_root * m_root * m_root
    s = s_root * s_root * s_root
    r = 4.0767416621 * l - 3.3077115913 * m + 0.2309699292 * s
    g = -1.2684380046 * l + 2.6097574011 * m - 0.3413193965 * s
    b = -0.0041960863 * l - 0.7034186147 * m + 1.7076147010 * s
    return r, g, b


def in_srgb_gamut(lch: OKLCH) -> bool:
    r, g, b = oklab_to_linear_srgb(lch.to_oklab())
    eps = 1e-7
    return all(-eps <= c <= 1.0 + eps for c in (r, g, b))


def gamut_map(lch: OKLCH) -> OKLCH:
    if in_srgb_gamut(lch):
        return lch
    low, high = 0.0, max(0.0, lch.C)
    for _ in range(24):
        mid = (low + high) / 2.0
        candidate = OKLCH(lch.L, mid, lch.H)
        if in_srgb_gamut(candidate):
            low = mid
        else:
            high = mid
    return OKLCH(lch.L, low, lch.H)


def max_chroma(l: float, h: float) -> float:
    """Largest in-sRGB chroma at this lightness and hue (the gamut edge).

    Flavours scale against this instead of against a raw multiplier: past the
    edge every request clips to the same color, which made strong flavours
    indistinguishable from each other.
    """
    return gamut_map(OKLCH(clamp(l, 0.0, 1.0), 0.5, normalize_hue(h))).C


def hex_from_oklch(l: float, c: float, h: float) -> str:
    lch = gamut_map(OKLCH(clamp(l, 0.0, 1.0), max(0.0, c), normalize_hue(h)))
    r, g, b = oklab_to_linear_srgb(lch.to_oklab())
    return "#{0:02x}{1:02x}{2:02x}".format(
        int(round(clamp(linear_to_srgb(r), 0.0, 1.0) * 255)),
        int(round(clamp(linear_to_srgb(g), 0.0, 1.0) * 255)),
        int(round(clamp(linear_to_srgb(b), 0.0, 1.0) * 255)),
    )


def normalize_hue(value: float) -> float:
    value = math.fmod(value, 360.0)
    if value < 0:
        value += 360.0
    return value


def clamp(value: float, lo: float, hi: float) -> float:
    return lo if value < lo else hi if value > hi else value


def hue_distance(a: float, b: float) -> float:
    d = abs(normalize_hue(a) - normalize_hue(b))
    return min(d, 360.0 - d)
