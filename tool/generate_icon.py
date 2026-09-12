#!/usr/bin/env python3
"""Draws the QingSpace app icon and writes the masters under assets/icon/.

The mark is two overlapping rings — the two people — whose intersection is
filled solid, with a heart punched out of it as negative space. The shared
area is literally the space the app is about.

Everything is rendered at SSAA x4 and downsampled, so the curves stay clean at
launcher sizes. `assets/icon/icon.svg` is emitted from the same geometry, so the
vector master and the bitmaps can never drift apart.

Usage:  python tool/generate_icon.py          (needs Pillow)
Outputs are committed; re-run only when the mark itself changes.
"""

from __future__ import annotations

import math
import os

from PIL import Image, ImageChops, ImageDraw

# ── Canvas ───────────────────────────────────────────────────────────────────

SIZE = 1024
SSAA = 4  # supersampling factor

# ── Mark geometry, in 1024-canvas units ──────────────────────────────────────

RING_RADIUS = 244.0  # outer radius of each ring
RING_STROKE = 56.0  # ring line weight
RING_OFFSET = 112.0  # half the distance between the two ring centres
HEART_WIDTH = 218.0  # width of the heart cut out of the intersection

# Android adaptive icons only guarantee the middle 66/108 of the canvas is
# visible. flutter_launcher_icons already insets the foreground drawable by 16%
# a side, which lands the mark at ~47% of the adaptive canvas — comfortably
# inside the safe circle. Pre-scaling here as well would shrink it twice.
FOREGROUND_SCALE = 1.0

# ── Palette ──────────────────────────────────────────────────────────────────
# Dawn to sky — the "晴空" the app is named for. The three stops keep the
# midtones vivid; a straight orange-to-blue ramp would pass through mud.

GRADIENT = [
    (0.00, (0xFF, 0xA9, 0x6B)),  # dawn orange
    (0.42, (0xF2, 0x77, 0x8F)),  # rose
    (1.00, (0x6B, 0x9F, 0xD8)),  # sky blue
]
MARK_COLOR = (0xFF, 0xFF, 0xFF)

OUT_DIR = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), 'assets', 'icon')


# ── Geometry helpers ─────────────────────────────────────────────────────────


def heart_points(cx: float, cy: float, width: float, steps: int = 240) -> list[tuple[float, float]]:
    """Classic parametric heart, centred on (cx, cy) and scaled to `width`.

    x = 16sin³t,  y = 13cos t − 5cos 2t − 2cos 3t − cos 4t
    """
    raw = []
    for i in range(steps):
        t = 2.0 * math.pi * i / steps
        x = 16.0 * math.sin(t) ** 3
        y = (
            13.0 * math.cos(t)
            - 5.0 * math.cos(2.0 * t)
            - 2.0 * math.cos(3.0 * t)
            - math.cos(4.0 * t)
        )
        raw.append((x, y))

    xs = [p[0] for p in raw]
    ys = [p[1] for p in raw]
    scale = width / (max(xs) - min(xs))
    mid_x = (max(xs) + min(xs)) / 2.0
    mid_y = (max(ys) + min(ys)) / 2.0

    # y is negated: the parametric curve points up, screen coordinates point down.
    return [(cx + (x - mid_x) * scale, cy - (y - mid_y) * scale) for x, y in raw]


def _ellipse(draw: ImageDraw.ImageDraw, cx: float, cy: float, r: float, fill: int) -> None:
    draw.ellipse([cx - r, cy - r, cx + r, cy + r], fill=fill)


def build_mark_mask(size: int, scale: float) -> Image.Image:
    """An 8-bit mask of the mark: both rings, the filled lens, minus the heart."""
    unit = size / SIZE
    cx = cy = size / 2.0
    r = RING_RADIUS * unit * scale
    stroke = RING_STROKE * unit * scale
    offset = RING_OFFSET * unit * scale

    left, right = cx - offset, cx + offset

    # Outer discs, then the inner discs knocked back out to leave two rings.
    rings = Image.new('L', (size, size), 0)
    d = ImageDraw.Draw(rings)
    _ellipse(d, left, cy, r, 255)
    _ellipse(d, right, cy, r, 255)
    _ellipse(d, left, cy, r - stroke, 0)
    _ellipse(d, right, cy, r - stroke, 0)

    # The lens is the intersection of the two solid discs.
    disc_l = Image.new('L', (size, size), 0)
    _ellipse(ImageDraw.Draw(disc_l), left, cy, r, 255)
    disc_r = Image.new('L', (size, size), 0)
    _ellipse(ImageDraw.Draw(disc_r), right, cy, r, 255)
    lens = ImageChops.multiply(disc_l, disc_r)

    mark = ImageChops.lighter(rings, lens)

    # Punch the heart out of the lens.
    heart = Image.new('L', (size, size), 0)
    ImageDraw.Draw(heart).polygon(
        heart_points(cx, cy, HEART_WIDTH * unit * scale), fill=255
    )
    return ImageChops.subtract(mark, heart)


def build_gradient(size: int) -> Image.Image:
    """Diagonal three-stop gradient, top-left to bottom-right.

    Drawn small and scaled up: a linear ramp interpolates exactly, so this is
    indistinguishable from a full-resolution loop and vastly faster.
    """
    small = 256
    grad = Image.new('RGB', (small, small))
    pixels = grad.load()
    max_t = 2.0 * (small - 1)
    for y in range(small):
        for x in range(small):
            pixels[x, y] = sample_gradient((x + y) / max_t)
    return grad.resize((size, size), Image.BICUBIC)


def sample_gradient(t: float) -> tuple[int, int, int]:
    t = min(1.0, max(0.0, t))
    for i in range(len(GRADIENT) - 1):
        t0, c0 = GRADIENT[i]
        t1, c1 = GRADIENT[i + 1]
        if t0 <= t <= t1:
            f = 0.0 if t1 == t0 else (t - t0) / (t1 - t0)
            return tuple(round(c0[j] + (c1[j] - c0[j]) * f) for j in range(3))
    return GRADIENT[-1][1]


# ── Outputs ──────────────────────────────────────────────────────────────────


def write_png(img: Image.Image, name: str) -> None:
    path = os.path.join(OUT_DIR, name)
    img.save(path)
    print(f'  {name:24} {img.size[0]}x{img.size[1]}  {img.mode}')


def main() -> None:
    os.makedirs(OUT_DIR, exist_ok=True)
    big = SIZE * SSAA
    print(f'Rendering at {big}x{big}, downsampling to {SIZE}…')

    gradient = build_gradient(SIZE)

    # Full-bleed icon: iOS, macOS, Windows, web, Android legacy.
    mask = build_mark_mask(big, 1.0).resize((SIZE, SIZE), Image.LANCZOS)
    icon = gradient.copy()
    icon.paste(Image.new('RGB', (SIZE, SIZE), MARK_COLOR), (0, 0), mask)
    write_png(icon, 'icon.png')

    # Android adaptive layers.
    write_png(gradient, 'icon_background.png')
    fg_mask = build_mark_mask(big, FOREGROUND_SCALE).resize((SIZE, SIZE), Image.LANCZOS)
    foreground = Image.new('RGBA', (SIZE, SIZE), (0, 0, 0, 0))
    foreground.paste(Image.new('RGB', (SIZE, SIZE), MARK_COLOR), (0, 0), fg_mask)
    write_png(foreground, 'icon_foreground.png')

    write_svg()
    print('Done.')


def write_svg() -> None:
    """Vector master, generated from the same constants as the bitmaps."""
    cx = cy = SIZE / 2.0
    left, right = cx - RING_OFFSET, cx + RING_OFFSET
    inner = RING_RADIUS - RING_STROKE
    heart = ' '.join(
        f'{x:.2f},{y:.2f}' for x, y in heart_points(cx, cy, HEART_WIDTH, steps=120)
    )
    stops = '\n'.join(
        f'      <stop offset="{t * 100:.0f}%" stop-color="#{c[0]:02X}{c[1]:02X}{c[2]:02X}"/>'
        for t, c in GRADIENT
    )

    svg = f'''<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 {SIZE} {SIZE}" width="{SIZE}" height="{SIZE}">
  <!-- Generated by tool/generate_icon.py — edit the script, not this file. -->
  <defs>
    <linearGradient id="sky" x1="0" y1="0" x2="1" y2="1">
{stops}
    </linearGradient>

    <clipPath id="lens">
      <circle cx="{left:.2f}" cy="{cy:.2f}" r="{RING_RADIUS:.2f}"/>
    </clipPath>

    <!-- White where the mark shows, black where the heart is punched out. -->
    <mask id="mark">
      <rect width="{SIZE}" height="{SIZE}" fill="black"/>
      <g fill="white">
        <circle cx="{left:.2f}" cy="{cy:.2f}" r="{RING_RADIUS:.2f}"/>
        <circle cx="{right:.2f}" cy="{cy:.2f}" r="{RING_RADIUS:.2f}"/>
      </g>
      <g fill="black">
        <circle cx="{left:.2f}" cy="{cy:.2f}" r="{inner:.2f}"/>
        <circle cx="{right:.2f}" cy="{cy:.2f}" r="{inner:.2f}"/>
      </g>
      <!-- Re-fill the lens: the intersection of the two outer discs. -->
      <circle cx="{right:.2f}" cy="{cy:.2f}" r="{RING_RADIUS:.2f}"
              fill="white" clip-path="url(#lens)"/>
      <polygon points="{heart}" fill="black"/>
    </mask>
  </defs>

  <rect width="{SIZE}" height="{SIZE}" fill="url(#sky)"/>
  <rect width="{SIZE}" height="{SIZE}" fill="#FFFFFF" mask="url(#mark)"/>
</svg>
'''
    path = os.path.join(OUT_DIR, 'icon.svg')
    with open(path, 'w', encoding='utf-8') as handle:
        handle.write(svg)
    print(f'  {"icon.svg":24} vector master')


if __name__ == '__main__':
    main()
