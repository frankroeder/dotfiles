"""Wallpaper sampling + representative color extraction (omagen-inspired)."""

from __future__ import annotations

import shutil
import subprocess
from dataclasses import dataclass

from .oklab import OKLab, from_srgb8


@dataclass(frozen=True)
class Representative:
    lab: OKLab
    weight: float
    hex: str

    @property
    def L(self) -> float:
        return self.lab.L

    @property
    def chroma(self) -> float:
        return self.lab.to_oklch().C

    @property
    def hue(self) -> float:
        return self.lab.to_oklch().H


def _quantize_key(r: int, g: int, b: int) -> int:
    # 5-bit channels keep the map small while preserving hue families.
    return ((r >> 3) << 10) | ((g >> 3) << 5) | (b >> 3)


def sample_image(path: str, size: int = 96) -> list[tuple[int, int, int]]:
    """Resize with ImageMagick and return RGB triplets."""
    magick = shutil.which("magick") or shutil.which("convert")
    if not magick:
        raise RuntimeError("ImageMagick (magick/convert) is required for palette extraction")
    cmd = [magick, path, "-resize", f"{size}x{size}!", "-depth", "8", "rgb:-"]
    proc = subprocess.run(cmd, check=True, capture_output=True)
    data = proc.stdout
    if len(data) % 3 != 0 or not data:
        raise RuntimeError(f"unexpected rgb dump size from {path}: {len(data)}")
    return [(data[i], data[i + 1], data[i + 2]) for i in range(0, len(data), 3)]


def aggregate(pixels: list[tuple[int, int, int]]) -> list[tuple[OKLab, float, str]]:
    buckets: dict[int, list] = {}
    for r, g, b in pixels:
        key = _quantize_key(r, g, b)
        entry = buckets.get(key)
        if entry is None:
            buckets[key] = [from_srgb8(r, g, b), 1.0, r, g, b]
        else:
            entry[1] += 1.0
            # Keep first RGB for display; lab is already from that sample.
    out = []
    for lab, weight, r, g, b in buckets.values():
        out.append((lab, weight, f"#{r:02x}{g:02x}{b:02x}"))
    out.sort(key=lambda item: (-item[1], item[0].L, item[0].a, item[0].b))
    return out


def _dist2(a: OKLab, b: OKLab) -> float:
    return (a.L - b.L) ** 2 + (a.a - b.a) ** 2 + (a.b - b.b) ** 2


def seed_centroids(points: list[tuple[OKLab, float, str]], k: int) -> list[OKLab]:
    if not points:
        return []
    centroids = [points[0][0]]
    while len(centroids) < k and len(centroids) < len(points):
        best = None
        best_score = -1.0
        for lab, weight, _ in points:
            if any(_dist2(lab, c) < 1e-10 for c in centroids):
                continue
            # Prefer distant + weighted seeds (farthest-point sampling).
            d = min(_dist2(lab, c) for c in centroids)
            score = d * (1.0 + weight)
            if score > best_score:
                best_score = score
                best = lab
        if best is None:
            break
        centroids.append(best)
    return centroids


def refine_centroids(
    points: list[tuple[OKLab, float, str]], centroids: list[OKLab], iterations: int = 18
) -> list[OKLab]:
    if not centroids:
        return []
    for _ in range(iterations):
        groups: list[list[tuple[OKLab, float]]] = [[] for _ in centroids]
        for lab, weight, _ in points:
            idx = min(range(len(centroids)), key=lambda i: _dist2(lab, centroids[i]))
            groups[idx].append((lab, weight))
        next_centroids = []
        for i, group in enumerate(groups):
            if not group:
                next_centroids.append(centroids[i])
                continue
            tw = sum(w for _, w in group)
            next_centroids.append(
                OKLab(
                    sum(lab.L * w for lab, w in group) / tw,
                    sum(lab.a * w for lab, w in group) / tw,
                    sum(lab.b * w for lab, w in group) / tw,
                )
            )
        if all(_dist2(a, b) < 1e-10 for a, b in zip(centroids, next_centroids)):
            break
        centroids = next_centroids
    return centroids


def build_representatives(
    points: list[tuple[OKLab, float, str]], centroids: list[OKLab]
) -> list[Representative]:
    groups: list[list[tuple[OKLab, float, str]]] = [[] for _ in centroids]
    for lab, weight, hx in points:
        idx = min(range(len(centroids)), key=lambda i: _dist2(lab, centroids[i]))
        groups[idx].append((lab, weight, hx))
    reps = []
    for i, group in enumerate(groups):
        if not group:
            continue
        tw = sum(w for _, w, _ in group)
        lab = centroids[i]
        # Prefer the heaviest member hex for readability.
        hx = max(group, key=lambda item: item[1])[2]
        reps.append(Representative(lab=lab, weight=tw, hex=hx))
    reps.sort(key=lambda r: (-r.weight, r.L))
    return merge_close(reps)


def merge_close(reps: list[Representative], threshold: float = 0.02) -> list[Representative]:
    if not reps:
        return []
    merged: list[Representative] = []
    thr2 = threshold * threshold
    for rep in reps:
        hit = None
        for i, other in enumerate(merged):
            if _dist2(rep.lab, other.lab) <= thr2:
                hit = i
                break
        if hit is None:
            merged.append(rep)
            continue
        other = merged[hit]
        tw = other.weight + rep.weight
        lab = OKLab(
            (other.lab.L * other.weight + rep.lab.L * rep.weight) / tw,
            (other.lab.a * other.weight + rep.lab.a * rep.weight) / tw,
            (other.lab.b * other.weight + rep.lab.b * rep.weight) / tw,
        )
        hx = other.hex if other.weight >= rep.weight else rep.hex
        merged[hit] = Representative(lab=lab, weight=tw, hex=hx)
    merged.sort(key=lambda r: (-r.weight, r.L))
    return merged


def extract_representatives(path: str, k: int = 12) -> list[Representative]:
    pixels = sample_image(path)
    points = aggregate(pixels)
    if not points:
        raise RuntimeError(f"no colors sampled from {path}")
    k = min(k, len(points))
    centroids = seed_centroids(points, k)
    centroids = refine_centroids(points, centroids)
    reps = build_representatives(points, centroids)
    if not reps:
        raise RuntimeError(f"palette extraction failed for {path}")
    return reps
