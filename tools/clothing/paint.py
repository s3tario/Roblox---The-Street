"""Drawing helpers for Roblox classic clothing templates (used by generate.py).

A Shirt or Pants template is a 585 x 559 PNG. Roblox wraps fixed rectangles of it around the body parts; everything
outside those rectangles is ignored, and transparent pixels inside them show the body part's own colour.

    torso  (UpperTorso for shirts, LowerTorso for pants)
        front 128x128, back 128x128, left/right sides 64x128, up/down 128x64
    right limb (arm on shirts, leg on pants): the lower-left block
    left limb: the lower-right block
        front/back/inner/outer 64x128, up/down 64x64

"front" regions are seen from in front of the character, so the wearer's LEFT is the RIGHT half of a front region.
Only Pillow is needed.
"""

import hashlib
import random

from PIL import Image, ImageChops, ImageDraw

W, H = 585, 559

TORSO = {
    "front": (231, 74, 128, 128),
    "back": (427, 74, 128, 128),
    "right": (165, 74, 64, 128),
    "left": (361, 74, 64, 128),
    "up": (231, 8, 128, 64),
    "down": (231, 204, 128, 64),
}
RIGHT_LIMB = {
    "up": (217, 289, 64, 64),
    "down": (217, 485, 64, 64),
    "front": (217, 355, 64, 128),
    "back": (85, 355, 64, 128),
    "inner": (151, 355, 64, 128),
    "outer": (19, 355, 64, 128),
}
LEFT_LIMB = {
    "up": (308, 289, 64, 64),
    "down": (308, 485, 64, 64),
    "front": (308, 355, 64, 128),
    "back": (440, 355, 64, 128),
    "inner": (374, 355, 64, 128),
    "outer": (506, 355, 64, 128),
}
LIMBS = (RIGHT_LIMB, LEFT_LIMB)
LIMB_SIDES = ("front", "back", "inner", "outer")


# ---------------------------------------------------------------------------------------------------------
# Colours
# ---------------------------------------------------------------------------------------------------------
def hex_rgb(s, default=(128, 128, 128)):
    if not isinstance(s, str) or len(s) != 7 or not s.startswith("#"):
        return default
    try:
        return (int(s[1:3], 16), int(s[3:5], 16), int(s[5:7], 16))
    except ValueError:
        return default


def shade(c, f):
    """f > 0 mixes toward white, f < 0 toward black (like Fit.shade in the game)."""
    if f >= 0:
        return tuple(int(round(v + (255 - v) * f)) for v in c[:3])
    return tuple(int(round(v * (1 + f))) for v in c[:3])


def luminance(c):
    r, g, b = (v / 255 for v in c[:3])
    return 0.2126 * r + 0.7152 * g + 0.0722 * b


def contrast_on(bg, candidates):
    """The first candidate colour that reads on bg, else near-white or ink."""
    lb = luminance(bg)
    for c in candidates:
        if c is not None and abs(luminance(c) - lb) > 0.28:
            return c
    return (244, 242, 236) if lb < 0.5 else (28, 32, 44)


def rgba(c, a=255):
    return (c[0], c[1], c[2], a)


class Colors:
    """An item's colours with the same defaults as Fit.colorsOf."""

    def __init__(self, item):
        cols = item.get("colors") or {}
        self.primary = hex_rgb(cols.get("primary"))
        self.secondary = hex_rgb(cols.get("secondary"), shade(self.primary, -0.2))
        self.accent = hex_rgb(cols.get("accent"), shade(self.primary, 0.35))
        self.trim = hex_rgb(cols.get("trim"), self.accent)


def seeded(item_id):
    """A deterministic random generator per item (the same PNG on every run)."""
    digest = hashlib.sha256(item_id.encode("utf-8")).digest()
    return random.Random(int.from_bytes(digest[:8], "big"))


# ---------------------------------------------------------------------------------------------------------
# Canvas
# ---------------------------------------------------------------------------------------------------------
class Canvas:
    """A template image plus helpers that draw in region-local coordinates."""

    def __init__(self):
        self.img = Image.new("RGBA", (W, H), (0, 0, 0, 0))
        self.draw = ImageDraw.Draw(self.img)

    # --- region fills -------------------------------------------------------------------------------
    def fill(self, region, color, top=0.0, bottom=1.0):
        """Fills a region (x, y, w, h), optionally only a vertical band (fractions of its height)."""
        x, y, w, h = region
        y0 = y + int(round(h * top))
        y1 = y + int(round(h * bottom))
        if y1 > y0:
            self.draw.rectangle([x, y0, x + w - 1, y1 - 1], fill=rgba(color))

    def clear(self, region, top=0.0, bottom=1.0):
        x, y, w, h = region
        y0 = y + int(round(h * top))
        y1 = y + int(round(h * bottom))
        if y1 > y0:
            self.draw.rectangle([x, y0, x + w - 1, y1 - 1], fill=(0, 0, 0, 0))

    # --- primitives in region space ---------------------------------------------------------------------
    # ImageDraw writes RGBA pixels as they are (no blending), so a translucent stroke is drawn on its own layer and
    # composited over the template instead.
    def _begin(self, alpha):
        if alpha >= 255:
            return self.draw, None
        layer = Image.new("RGBA", (W, H), (0, 0, 0, 0))
        return ImageDraw.Draw(layer), layer

    def _end(self, layer):
        if layer is not None:
            self.img.alpha_composite(layer)

    @staticmethod
    def at(region, u, v):
        """Pixel position of region-local (u, v) in pixels from the region's top-left."""
        x, y, _, _ = region
        return (x + u, y + v)

    def rect(self, region, u0, v0, u1, v1, color, alpha=255, outline=None):
        x, y, _, _ = region
        d, layer = self._begin(alpha)
        d.rectangle(
            [x + u0, y + v0, x + u1, y + v1],
            fill=rgba(color, alpha) if color is not None else None,
            outline=rgba(outline) if outline is not None else None,
        )
        self._end(layer)

    def line(self, region, pts, color, width=1, alpha=255):
        x, y, _, _ = region
        d, layer = self._begin(alpha)
        d.line([(x + u, y + v) for u, v in pts], fill=rgba(color, alpha), width=width)
        self._end(layer)

    def poly(self, region, pts, color, alpha=255, outline=None):
        x, y, _, _ = region
        d, layer = self._begin(alpha)
        d.polygon(
            [(x + u, y + v) for u, v in pts],
            fill=rgba(color, alpha),
            outline=rgba(outline) if outline is not None else None,
        )
        self._end(layer)

    def clear_poly(self, region, pts):
        """Makes a polygon fully transparent again (a notch through which the body shows)."""
        x, y, _, _ = region
        self.draw.polygon([(x + u, y + v) for u, v in pts], fill=(0, 0, 0, 0))

    def dot(self, region, u, v, r, color, alpha=255, outline=None):
        x, y, _, _ = region
        d, layer = self._begin(alpha)
        d.ellipse(
            [x + u - r, y + v - r, x + u + r, y + v + r],
            fill=rgba(color, alpha),
            outline=rgba(outline) if outline is not None else None,
        )
        self._end(layer)

    def arc(self, region, box, start, end, color, width=1):
        x, y, _, _ = region
        u0, v0, u1, v1 = box
        self.draw.arc([x + u0, y + v0, x + u1, y + v1], start, end, fill=rgba(color), width=width)

    def dashed(self, region, p0, p1, color, dash=3, gap=3, width=1, alpha=255):
        (u0, v0), (u1, v1) = p0, p1
        length = max(abs(u1 - u0), abs(v1 - v0), 1)
        t = 0.0
        while t < length:
            a = t / length
            b = min(t + dash, length) / length
            self.line(
                region,
                [(u0 + (u1 - u0) * a, v0 + (v1 - v0) * a), (u0 + (u1 - u0) * b, v0 + (v1 - v0) * b)],
                color,
                width,
                alpha,
            )
            t += dash + gap

    def text(self, region, u, v, s, color):
        """Tiny label text with Pillow's built-in bitmap font (monograms, wordmarks)."""
        x, y, _, _ = region
        self.draw.text((x + u, y + v), s, fill=rgba(color))

    # --- whole-image passes -----------------------------------------------------------------------------
    def overlay_masked(self, layer):
        """Composites `layer` only where the template is already painted (patterns never leak into gaps)."""
        mask = ImageChops.multiply(layer.getchannel("A"), self.img.getchannel("A"))
        layer.putalpha(mask)
        self.img = Image.alpha_composite(self.img, layer)
        self.draw = ImageDraw.Draw(self.img)

    def new_layer(self):
        layer = Image.new("RGBA", (W, H), (0, 0, 0, 0))
        return layer, ImageDraw.Draw(layer)

    def save(self, path):
        self.img.save(path, "PNG", optimize=True)


# ---------------------------------------------------------------------------------------------------------
# Fabric patterns (whole-canvas layers, masked to painted pixels)
# ---------------------------------------------------------------------------------------------------------
def pattern_pinstripe(canvas, color, spacing=7, alpha=150):
    layer, d = canvas.new_layer()
    for x in range(0, W, spacing):
        d.line([(x, 0), (x, H)], fill=rgba(color, alpha), width=1)
    canvas.overlay_masked(layer)


def pattern_stripe(canvas, color, spacing=12, width=5, alpha=200):
    layer, d = canvas.new_layer()
    for y in range(0, H, spacing):
        d.rectangle([0, y, W, y + width - 1], fill=rgba(color, alpha))
    canvas.overlay_masked(layer)


def pattern_check(canvas, color, size=8, alpha=110):
    """Gingham: translucent bands both ways, darker where they cross."""
    layer, d = canvas.new_layer()
    for x in range(0, W, size * 2):
        d.rectangle([x, 0, x + size - 1, H], fill=rgba(color, alpha))
    canvas.overlay_masked(layer)
    layer, d = canvas.new_layer()
    for y in range(0, H, size * 2):
        d.rectangle([0, y, W, y + size - 1], fill=rgba(color, alpha))
    canvas.overlay_masked(layer)


def pattern_plaid(canvas, dark, light, size=24, alpha=150):
    """Buffalo/tartan check: wide dark bands, thin light overstripes."""
    layer, d = canvas.new_layer()
    for x in range(0, W, size):
        d.rectangle([x, 0, x + size // 2 - 1, H], fill=rgba(dark, alpha))
    for y in range(0, H, size):
        d.rectangle([0, y, W, y + size // 2 - 1], fill=rgba(dark, alpha))
    canvas.overlay_masked(layer)
    layer, d = canvas.new_layer()
    for x in range(size // 4, W, size):
        d.line([(x, 0), (x, H)], fill=rgba(light, 120), width=1)
    for y in range(size // 4, H, size):
        d.line([(0, y), (W, y)], fill=rgba(light, 120), width=1)
    canvas.overlay_masked(layer)


def texture_weave(canvas, base, kind="wool"):
    """A faint, low-entropy fabric texture so templates read as cloth (and still compress well)."""
    layer, d = canvas.new_layer()
    if kind == "twill":
        light = shade(base, 0.12)
        for k in range(-H, W, 4):
            d.line([(k, 0), (k + H, H)], fill=rgba(light, 34), width=1)
    elif kind == "knit":
        dark = shade(base, -0.12)
        for x in range(0, W, 4):
            d.line([(x, 0), (x, H)], fill=rgba(dark, 40), width=1)
    elif kind == "fleece":
        light = shade(base, 0.08)
        for y in range(0, H, 3):
            d.line([(0, y), (W, y)], fill=rgba(light, 22), width=1)
    else:  # wool, cotton
        dark = shade(base, -0.08)
        for y in range(0, H, 2):
            d.line([(0, y), (W, y)], fill=rgba(dark, 26), width=1)
    canvas.overlay_masked(layer)


def side_shading(canvas, regions, base, width=6, alpha=60):
    """Darkens the left and right edges of front/back regions a little, like cloth turning away."""
    layer, d = canvas.new_layer()
    dark = shade(base, -0.35)
    for x, y, w, h in regions:
        for i in range(width):
            a = int(alpha * (1 - i / width))
            d.line([(x + i, y), (x + i, y + h - 1)], fill=rgba(dark, a))
            d.line([(x + w - 1 - i, y), (x + w - 1 - i, y + h - 1)], fill=rgba(dark, a))
    canvas.overlay_masked(layer)
