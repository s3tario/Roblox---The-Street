#!/usr/bin/env python3
"""Paint a Roblox Shirt or Pants template (585 x 559 PNG) for every top, jacket and bottom in the wardrobe catalog.

The game looks complete without these: every outfit is built from fitted 3D layers. Uploaded templates add a little
printed detail underneath (seams, buttons, pockets, patterns) once their ids are in Config/ClothingIds.luau (see
upload.py). Each PNG is drawn from the item's catalog entry (builder, style, pattern, details and colours), so the
2D template matches the 3D garment. Output is deterministic: the same catalog always gives the same files.

    python3 tools/clothing/generate.py                      # every template into assets/clothing/
    python3 tools/clothing/generate.py --only oxford_white suit_navy_2b
    python3 tools/clothing/generate.py --sheet /tmp/sheet.png   # also a contact sheet to eyeball them
    python3 tools/clothing/generate.py --clean              # also delete PNGs of items no longer in the catalog

Files are named <itemId>_shirt.png (top and outer items) and <itemId>_pants.png (bottom items). Needs Pillow
(pip install pillow) and Lune (to read the catalog through tools/clothing/export.luau); run it from anywhere.
"""

import argparse
import json
import math
import os
import subprocess
import sys

try:
    from PIL import Image, ImageDraw
except ImportError:  # pragma: no cover - tells the owner what to install
    sys.exit("generate.py needs Pillow: pip install pillow")

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import paint as P  # noqa: E402  (tools/clothing/paint.py)

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
OUT_DIR = os.path.join(ROOT, "assets", "clothing")

SHIRT_LIGHT = (242, 241, 236)  # the shirt that shows inside a jacket's V
STRIPE = (196, 198, 204)  # chalk / pin stripe (same as the 3D builders)
GOLD = (212, 175, 55)
BRASS = (184, 147, 63)


# ---------------------------------------------------------------------------------------------------------
# Catalog
# ---------------------------------------------------------------------------------------------------------
def load_catalog(path=None):
    """Catalog entries from tools/clothing/export.luau (runs Lune unless a JSON path is given)."""
    if path:
        with open(path, "r", encoding="utf-8") as f:
            return json.load(f)["items"]
    try:
        out = subprocess.run(
            ["lune", "run", "tools/clothing/export"], cwd=ROOT, check=True, capture_output=True, text=True
        ).stdout
    except (OSError, subprocess.CalledProcessError) as e:
        sys.exit("Couldn't run 'lune run tools/clothing/export' (is Lune installed?): %s" % e)
    return json.loads(out[out.find("{") :])["items"]


def template_items(items):
    """(item, kind) for every visible item that gets a template: "shirt" (top/outer) or "pants" (bottom)."""
    return [(it, it["template"]) for it in items if it.get("template") and not it.get("hidden")]


def file_name(item, kind):
    return "%s_%s.png" % (item["id"], kind)


# ---------------------------------------------------------------------------------------------------------
# Shared garment pieces
# ---------------------------------------------------------------------------------------------------------
F, B = P.TORSO["front"], P.TORSO["back"]
SIDES = (P.TORSO["left"], P.TORSO["right"])


def limb_regions(sides=P.LIMB_SIDES):
    for limb in P.LIMBS:
        for side in sides:
            yield limb[side]


def ribbing(c, region, v0, v1, color, step=3):
    """Vertical rib lines in a band (hems and cuffs of knits)."""
    x, y, w, h = region
    c.rect(region, 0, v0, w - 1, v1, color, 255)
    for u in range(1, w, step):
        c.line(region, [(u, v0), (u, v1)], P.shade(color, -0.18), 1, 150)


def hem_line(c, region, v, color, alpha=170):
    c.line(region, [(0, v), (region[2] - 1, v)], color, 1, alpha)


def cuffs(c, color, height=12, sleeve=1.0, rib=False):
    """A band at the end of each sleeve (sleeve = covered fraction of the arm)."""
    end = int(128 * sleeve)
    for region in limb_regions():
        if rib:
            ribbing(c, region, end - height, end - 1, color)
        else:
            c.rect(region, 0, end - height, region[2] - 1, end - 1, color)
            hem_line(c, region, end - height, P.shade(color, -0.25))


def crew_neck(c, color, depth=12, width=44):
    u0 = 64 - width // 2
    c.arc(F, (u0, -depth, u0 + width, depth), 0, 180, color, 4)
    c.arc(B, (u0 + 6, -depth // 2, u0 + width - 6, depth // 2), 0, 180, color, 3)


def v_neck(c, color, depth=30, half=18, inner=None):
    if inner is not None:
        c.poly(F, [(64 - half, 0), (64 + half, 0), (64, depth)], inner)
    c.line(F, [(64 - half, 0), (64, depth), (64 + half, 0)], color, 3)


def shirt_collar(c, col, spread=20, drop=16):
    fill = P.shade(col.primary, 0.06)
    edge = P.shade(col.primary, -0.28)
    c.poly(F, [(64 - spread - 4, 0), (64, 3), (64 - spread + 8, drop)], fill, outline=edge)
    c.poly(F, [(64 + spread + 4, 0), (64, 3), (64 + spread - 8, drop)], fill, outline=edge)
    c.rect(B, 30, 0, 97, 7, fill)
    hem_line(c, B, 7, edge)


def placket(c, v0, v1, button, n, edge, u=64):
    c.line(F, [(u, v0), (u, v1)], edge, 1, 200)
    c.line(F, [(u + 4, v0), (u + 4, v1)], edge, 1, 90)
    if n > 0:
        step = (v1 - v0) / max(n - 1, 1) if n > 1 else 0
        for i in range(n):
            c.dot(F, u + 2, v0 + step * i, 2, button, outline=P.shade(button, -0.3))


def button_color(col):
    return P.contrast_on(col.primary, [col.accent, P.shade(col.primary, -0.4)])


def brand_label(item):
    """Short uppercase text for wordmarks (the brand id read as words)."""
    words = (item.get("brand") or "").replace("_", " ").split()
    text = "".join(w[:1] for w in words) if len(" ".join(words)) > 10 else " ".join(words)
    return text.upper()[:10] or "THE STREET"


# ---------------------------------------------------------------------------------------------------------
# Brand details printed on the chest (the 3D Details/Emblems builders draw the same marks)
# ---------------------------------------------------------------------------------------------------------
def chest_mark(c, item, col, covered=False):
    details = item.get("details") or []
    if covered:
        return
    ink = P.contrast_on(col.primary, [col.trim, col.accent])
    u, v = 86, 24  # wearer's left chest
    for d in details:
        if d == "emblem_windmill":
            windmill(c, F, u + 6, v + 2, ink)
        elif d == "emblem_flag":
            for i, colr in enumerate(((31, 42, 68), (244, 244, 240), (178, 34, 52))):
                c.rect(F, u + i * 5, v, u + i * 5 + 4, v + 6, colr)
        elif d == "emblem_pony":
            c.poly(F, [(u, v + 8), (u + 4, v), (u + 9, v + 2), (u + 12, v + 8)], ink)
            c.line(F, [(u + 9, v + 2), (u + 14, v - 3)], ink, 1)
        elif d == "emblem_peak":
            c.rect(F, u - 2, v - 1, u + 15, v + 9, P.shade(col.primary, -0.25))
            c.poly(F, [(u, v + 8), (u + 6, v + 1), (u + 9, v + 4), (u + 13, v + 8)], ink)
        elif d == "emblem_whale":
            c.dot(F, u + 6, v + 4, 4, ink)
            c.poly(F, [(u + 9, v + 4), (u + 14, v), (u + 14, v + 7)], ink)
        elif d == "wordmark":
            c.text(F, u - 8, v, brand_label(item)[:6], ink)
        elif d == "logo_arch":
            c.arc(F, (34, 26, 94, 70), 200, 340, ink, 3)
            c.text(F, 40, 40, brand_label(item)[:8], ink)
        elif d == "rugby_stripes":
            pass  # a whole-garment pattern (see paint_shirt)
        elif d == "monogram_cuff":
            for limb in P.LIMBS:
                c.text(limb["outer"], 24, 104, "PM" if item.get("brand") == "pan_miller" else "M", ink)


def windmill(c, region, u, v, color):
    """The Pan Miller windmill in a few strokes: lattice tower, multi-blade wheel, tail vane."""
    c.line(region, [(u - 4, v + 14), (u, v + 3), (u + 4, v + 14)], color, 1)
    c.line(region, [(u - 3, v + 10), (u + 3, v + 10)], color, 1)
    for k in range(8):
        a = math.radians(k * 45 + 22.5)
        c.line(region, [(u, v + 2), (u + math.sin(a) * 6, v + 2 - math.cos(a) * 6)], color, 1)
    c.line(region, [(u, v + 2), (u + 9, v + 2)], color, 1)
    c.rect(region, u + 8, v - 1, u + 10, v + 4, color)


# ---------------------------------------------------------------------------------------------------------
# Tops
# ---------------------------------------------------------------------------------------------------------
def sleeve_length(item):
    b, style = item["builder"], item.get("style")
    if b in ("tee", "polo"):
        return 0.42
    if b in ("shell", "vest"):
        return 0.0
    return 1.0


def paint_tee(c, item, col):
    crew_neck(c, P.shade(col.primary, -0.12))
    for region in (F, B):
        hem_line(c, region, 122, P.shade(col.primary, -0.25))
    cuffs(c, P.shade(col.primary, -0.05), 5, 0.42)
    if item.get("style") == "pocket":
        c.rect(F, 80, 26, 99, 46, P.shade(col.primary, -0.04), outline=P.shade(col.primary, -0.25))
        hem_line(c, (F[0] + 80, F[1], 20, 128), 29, P.shade(col.primary, -0.25))


def paint_polo(c, item, col):
    edge = P.shade(col.primary, -0.3)
    collar = P.shade(col.primary, -0.06)
    c.poly(F, [(36, 0), (64, 4), (50, 14)], collar, outline=edge)
    c.poly(F, [(92, 0), (64, 4), (78, 14)], collar, outline=edge)
    c.rect(F, 60, 4, 68, 34, P.shade(col.primary, 0.04), outline=edge)
    for v in (10, 20, 30):
        c.dot(F, 64, v, 2, button_color(col))
    c.rect(B, 28, 0, 99, 8, collar)
    cuffs(c, collar, 7, 0.42, rib=True)
    if "tipping" in (item.get("details") or []):
        tip = P.contrast_on(col.primary, [col.accent, col.trim])
        c.line(F, [(37, 1), (50, 13)], tip, 1)
        c.line(F, [(91, 1), (78, 13)], tip, 1)
        for region in limb_regions():
            hem_line(c, region, 50, tip, 255)
            hem_line(c, region, 52, tip, 255)


def paint_shirt_top(c, item, col, sleeve_cuffs=True):
    edge = P.shade(col.primary, -0.28)
    shirt_collar(c, col)
    placket(c, 6, 124, button_color(col), 6, edge)
    c.line(B, [(0, 24), (127, 24)], edge, 1, 120)  # back yoke
    c.line(B, [(60, 24), (60, 127)], edge, 1, 70)  # box pleat
    c.line(B, [(68, 24), (68, 127)], edge, 1, 70)
    if sleeve_cuffs:
        cuffs(c, P.shade(col.primary, 0.04), 12)
        for limb in P.LIMBS:
            c.dot(limb["outer"], 32, 122, 2, button_color(col))
    if "buttondown" in (item.get("details") or []):
        c.dot(F, 48, 13, 1.5, button_color(col))
        c.dot(F, 80, 13, 1.5, button_color(col))


def paint_blouse(c, item, col):
    edge = P.shade(col.primary, -0.22)
    c.poly(F, [(50, 0), (78, 0), (64, 20)], P.shade(col.primary, -0.1))
    c.line(F, [(50, 0), (64, 20), (78, 0)], edge, 2)
    for u in (40, 48, 80, 88):
        c.line(F, [(u, 14), (u + (2 if u < 64 else -2), 60)], edge, 1, 80)  # soft pleats
    for region in (F, B):
        hem_line(c, region, 124, edge)
    cuffs(c, P.shade(col.primary, 0.03), 10)


def paint_shell(c, item, col):
    crew_neck(c, P.shade(col.primary, -0.14), 10, 40)
    for region in (F, B):
        hem_line(c, region, 124, P.shade(col.primary, -0.25))


def paint_hoodie(c, item, col):
    dark = P.shade(col.primary, -0.14)
    edge = P.shade(col.primary, -0.3)
    # hood folded on the back and over the shoulders
    c.poly(B, [(22, 0), (106, 0), (98, 30), (64, 46), (30, 30)], dark, outline=edge)
    c.rect(P.TORSO["up"], 20, 0, 107, 63, dark)
    crew_neck(c, edge, 14, 48)
    # drawstrings with aglets
    cord = P.contrast_on(col.primary, [col.accent, (233, 226, 207)])
    c.line(F, [(56, 10), (54, 42)], cord, 2)
    c.line(F, [(72, 10), (74, 42)], cord, 2)
    c.rect(F, 52, 42, 56, 47, P.shade(cord, -0.2))
    c.rect(F, 72, 42, 76, 47, P.shade(cord, -0.2))
    # kangaroo pocket
    c.poly(F, [(30, 78), (98, 78), (108, 114), (20, 114)], P.shade(col.primary, -0.05), outline=edge)
    c.line(F, [(30, 78), (22, 112)], edge, 2)
    c.line(F, [(98, 78), (106, 112)], edge, 2)
    for region in (F, B, *SIDES):
        ribbing(c, region, 116, 127, P.shade(col.primary, -0.06))
    cuffs(c, P.shade(col.primary, -0.06), 12, rib=True)
    if item.get("style") == "college":
        ink = P.contrast_on(col.primary, [col.accent, (233, 226, 207)])
        c.text(F, 34, 52, "EASTBRIDGE", ink)


def paint_sweater(c, item, col):
    rib = P.shade(col.primary, -0.08)
    if item.get("style") == "vneck":
        v_neck(c, rib, 34, 18, inner=SHIRT_LIGHT)
    else:
        crew_neck(c, rib, 12, 44)
    for region in (F, B, *SIDES):
        ribbing(c, region, 114, 127, rib)
    cuffs(c, rib, 12, rib=True)
    if "cable" in (item.get("details") or []):
        edge = P.shade(col.primary, -0.22)
        for u0 in (34, 64, 94):
            for v in range(20, 112, 12):
                c.line(F, [(u0 - 5, v), (u0 + 5, v + 6), (u0 - 5, v + 12)], edge, 2)
                c.line(F, [(u0 + 5, v), (u0 - 5, v + 6), (u0 + 5, v + 12)], P.shade(col.primary, 0.1), 1)


def paint_quarterzip(c, item, col):
    rib = P.shade(col.primary, -0.08)
    zip_metal = P.contrast_on(col.primary, [col.accent, (192, 196, 200)])
    c.rect(F, 38, 0, 89, 10, rib, outline=P.shade(col.primary, -0.3))  # stand collar
    c.rect(B, 34, 0, 93, 9, rib)
    c.rect(F, 62, 0, 65, 46, zip_metal)
    c.dashed(F, (61, 0), (61, 46), P.shade(zip_metal, -0.3), 1, 2)
    c.dashed(F, (66, 0), (66, 46), P.shade(zip_metal, -0.3), 1, 2)
    c.rect(F, 61, 12, 66, 22, P.shade(zip_metal, -0.15))  # the pull
    for region in (F, B, *SIDES):
        ribbing(c, region, 116, 127, rib)
    cuffs(c, rib, 10, rib=True)


def paint_overshirt(c, item, col):
    edge = P.shade(col.primary, -0.3)
    shirt_collar(c, col, spread=24, drop=18)
    button = P.contrast_on(col.primary, [col.accent, P.shade(col.primary, -0.45)])
    placket(c, 8, 124, button, 6, edge)
    for u0 in (22, 78):
        c.rect(F, u0, 24, u0 + 27, 50, P.shade(col.primary, 0.03), outline=edge)
        c.rect(F, u0 - 1, 22, u0 + 28, 30, P.shade(col.primary, -0.06), outline=edge)
        c.dot(F, u0 + 13, 27, 1.5, button)
    cuffs(c, P.shade(col.primary, -0.04), 12)
    if item.get("style") == "denim":
        stitch = P.contrast_on(col.primary, [col.accent, (201, 138, 59)])
        c.dashed(F, (60, 8), (60, 124), stitch, 2, 2)
        c.dashed(F, (68, 8), (68, 124), stitch, 2, 2)
        c.dashed(B, (0, 30), (127, 30), stitch, 2, 2)
        for u0 in (22, 78):
            c.dashed(F, (u0 + 2, 48), (u0 + 25, 48), stitch, 2, 2)


def paint_vest(c, item, col):
    edge = P.shade(col.primary, -0.32)
    if item.get("style") == "waistcoat":
        c.poly(F, [(40, 0), (88, 0), (64, 58)], SHIRT_LIGHT)
        c.line(F, [(40, 0), (64, 58), (88, 0)], edge, 2)
        for i in range(5):
            c.dot(F, 64, 64 + i * 12, 2.5, P.shade(col.primary, -0.45))
        for u0 in (16, 86):
            c.line(F, [(u0, 84), (u0 + 26, 82)], edge, 2)
        c.clear_poly(F, [(54, 128), (74, 128), (64, 117)])  # the pointed front hem
        c.fill(B, col.secondary)  # satin back
        c.line(B, [(30, 92), (98, 92)], P.shade(col.secondary, -0.25), 2)  # adjuster strap
        c.rect(B, 60, 88, 68, 96, BRASS)
    else:  # fleece / gilet
        zip_metal = P.contrast_on(col.primary, [col.accent, (192, 196, 200)])
        c.rect(F, 34, 0, 93, 11, P.shade(col.primary, -0.06), outline=edge)
        c.rect(B, 30, 0, 97, 10, P.shade(col.primary, -0.06))
        c.rect(F, 62, 0, 65, 127, zip_metal)
        c.rect(F, 60, 14, 67, 24, P.shade(zip_metal, -0.2))
        for u0, u1 in ((18, 40), (88, 110)):
            c.line(F, [(u0, 76), (u1, 98)] if u0 < 64 else [(u1, 76), (u0, 98)], P.shade(zip_metal, -0.1), 2)
        for region in (F, B, *SIDES):
            hem_line(c, region, 123, edge)
        # armhole binding on the sides
        for region in SIDES:
            c.rect(region, 0, 0, 63, 5, P.shade(col.primary, -0.12))


# ---------------------------------------------------------------------------------------------------------
# Tailored jackets, blazers and overcoats (mirrors Assets/Wardrobe/Outer: the same specs per style)
# ---------------------------------------------------------------------------------------------------------
def tailored_spec(item, col):
    b, style = item["builder"], item.get("style")
    s = {
        "apex": 0.62,
        "half": 29,
        "lapel": 14,
        "buttons": "two",
        "button": P.shade(col.primary, -0.45),
        "pockets": "flap",
        "square": None,
        "peak": False,
        "shawl": False,
        "lapel_color": P.shade(col.primary, 0.08),
        # the lapel edge must read on dark cloth too (navy, charcoal, black)
        "lapel_edge": P.shade(col.primary, 0.3) if P.luminance(col.primary) < 0.25 else P.shade(col.primary, -0.3),
        "waistcoat": None,
        "crest": None,
        "elbows": None,
        "cuff_buttons": True,
        "vents": "single",
    }
    if b == "jacket":
        s["square"] = col.accent
        if style == "double_breasted":
            s.update(apex=0.5, lapel=17, peak=True, buttons="double", vents="double")
        elif style == "three_piece":
            s.update(apex=0.6, waistcoat=P.shade(col.primary, -0.08))
        elif style == "dinner":
            s.update(apex=0.72, lapel=15, peak=True, buttons="one", pockets="jetted", vents="none")
            s.update(lapel_color=col.secondary, lapel_edge=P.shade(col.secondary, 0.12), button=col.secondary)
        elif style == "shawl":
            s.update(apex=0.7, shawl=True, buttons="one", pockets="jetted", vents="none")
            s.update(lapel_color=col.secondary, lapel_edge=P.shade(col.secondary, 0.12), button=col.secondary)
        elif style == "pan_miller":
            s.update(apex=0.5, lapel=17, peak=True, buttons="double", pockets="jetted", vents="double")
            s.update(button=col.accent, square=col.trim, lapel_edge=P.shade(col.primary, 0.18))
    elif b == "blazer":
        s.update(lapel=13, pockets="patch", cuff_buttons=False, button=P.shade(col.accent, -0.15))
        if style == "elbow":
            s.update(elbows=col.accent, button=P.shade(col.primary, -0.4))
        elif style in ("club", "heirloom"):
            s.update(button=col.accent, crest=col.accent, cuff_buttons=True, pockets="flap")
            if style == "heirloom":
                s.update(lapel_edge=col.accent, peak=True)
    elif b == "overcoat":
        s.update(apex=0.5, half=32, lapel=18, buttons="three", vents="single")
        if style == "chesterfield":
            s.update(lapel_color=P.shade(col.primary, -0.05), button=col.accent)
    return s


def lapel_points(half, apex, lw, side):
    """A lapel band along one edge of the V (side -1 = viewer's left = wearer's right)."""
    ax, ay = 64 + side * half, 0.0
    bx, by = 64.0, float(apex)
    dx, dy = bx - ax, by - ay
    length = math.hypot(dx, dy)
    nx, ny = side * abs(dy) / length, abs(dx) / length * 0.35  # outward and slightly down
    outer_top = (ax + nx * lw, ay + ny * lw)
    outer_low = (bx + nx * lw * 0.25, by - lw * 0.2)
    return [(ax, ay), (bx, by), outer_low, outer_top]


def paint_tailored(c, item, col):
    s = tailored_spec(item, col)
    apex = int(128 * (s["apex"] - 0.02))
    half, lw = s["half"], s["lapel"]
    edge = P.shade(col.primary, -0.32)
    # what shows inside the V: the shirt (and a waistcoat on a three-piece)
    c.poly(F, [(64 - half, 0), (64 + half, 0), (64, apex)], s["waistcoat"] or SHIRT_LIGHT)
    if s["waistcoat"]:
        h2 = int(half * 0.62)
        c.poly(F, [(64 - h2, 0), (64 + h2, 0), (64, int(apex * 0.55))], SHIRT_LIGHT)
        for i in range(3):
            c.dot(F, 64, int(apex * 0.6) + 6 + i * 7, 1.5, P.shade(col.primary, -0.45))
    # lapels
    for side in (-1, 1):
        pts = lapel_points(half, apex, lw, side)
        c.poly(F, pts, s["lapel_color"], outline=s["lapel_edge"])
        ox, oy = pts[3]
        if s["shawl"]:
            continue
        if s["peak"]:
            c.poly(F, [(ox, oy + 6), (ox + side * 7, oy - 2), (ox - side * 2, oy + 12)], s["lapel_color"])
        else:
            mx, my = ox - side * 3, oy + 12
            c.poly(F, [(mx, my), (mx + side * 6, my - 2), (mx + side * 2, my + 5)], col.primary)  # the notch
    if "pick_stitch" in (item.get("details") or []):
        for side in (-1, 1):
            a, b = lapel_points(half - 3, apex - 4, 0, side)[0:2]
            c.dashed(F, (a[0] + side * 4, a[1] + 4), (b[0] + side * 3, b[1] - 6), col.trim, 2, 2)
    if "crest_c" in (item.get("details") or []):
        c.arc(F, (64 + half - 4, 26, 64 + half + 4, 34), 40, 320, col.trim, 2)
    if "lapel_pin" in (item.get("details") or []):
        c.dot(F, 64 + half + 4, 20, 2.5, GOLD, outline=P.shade(GOLD, -0.3))
    # front closure and buttons
    if s["buttons"] == "double":
        c.line(F, [(64, apex), (82, apex + 4), (82, 127)], edge, 1)
        for v in (apex + 6, apex + 22, apex + 38):
            for u in (50, 78):
                if v < 124:
                    c.dot(F, u, v, 3, s["button"], outline=P.shade(s["button"], -0.3))
    else:
        c.line(F, [(64, apex), (64, 120), (58, 127)], edge, 1)
        c.line(F, [(64, 120), (70, 127)], edge, 1)
        offsets = {"one": (8,), "two": (6, 26), "three": (4, 20, 36)}[s["buttons"]]
        for off in offsets:
            if apex + off < 120:
                c.dot(F, 66, apex + off, 3, s["button"], outline=P.shade(s["button"], -0.3))
    # pockets: hips and the wearer's-left breast pocket (or a crest)
    for u0 in (12, 82):
        if s["pockets"] == "flap":
            c.rect(F, u0, 98, u0 + 33, 105, P.shade(col.primary, -0.1), outline=edge)
        elif s["pockets"] == "jetted":
            c.line(F, [(u0 + 2, 100), (u0 + 31, 100)], edge, 2)
        else:
            c.rect(F, u0, 92, u0 + 33, 120, None, outline=edge)
    if s["crest"] is not None:
        c.poly(F, [(84, 26), (100, 26), (100, 36), (92, 44), (84, 36)], s["crest"], outline=P.shade(s["crest"], -0.3))
    else:
        c.line(F, [(82, 44), (102, 42)], edge, 2)
        if s["square"] is not None:
            c.poly(F, [(84, 43), (88, 36), (93, 41), (98, 35), (100, 42)], s["square"])
    if "emblem_windmill" in (item.get("details") or []):
        # the wearer's right chest (the left breast holds the pocket square), as on the 3D jacket
        windmill(c, F, 30, 28, P.contrast_on(col.primary, [col.trim, col.accent]))
    # sleeves: cuff buttons, elbow patches
    for limb in P.LIMBS:
        if s["cuff_buttons"]:
            for v in (106, 112, 118):
                c.dot(limb["outer"], 44, v, 1.5, s["button"])
        if s["elbows"] is not None:
            c.dot(limb["back"], 32, 64, 12, s["elbows"])
    # back: centre seam, vents, collar
    c.rect(B, 30, 0, 97, 8, P.shade(col.primary, -0.08))
    c.line(B, [(64, 8), (64, 127)], edge, 1, 140)
    if s["vents"] == "double":
        for u in (22, 106):
            c.line(B, [(u, 98), (u, 127)], edge, 1)
    elif s["vents"] == "single":
        c.line(B, [(66, 98), (66, 127)], edge, 1)


# ---------------------------------------------------------------------------------------------------------
# Shirts (top and outer items)
# ---------------------------------------------------------------------------------------------------------
TOP_PAINTERS = {
    "tee": paint_tee,
    "polo": paint_polo,
    "shirt": paint_shirt_top,
    "blouse": paint_blouse,
    "shell": paint_shell,
    "hoodie": paint_hoodie,
    "sweater": paint_sweater,
    "quarterzip": paint_quarterzip,
    "overshirt": paint_overshirt,
    "vest": paint_vest,
    "jacket": paint_tailored,
    "blazer": paint_tailored,
    "overcoat": paint_tailored,
}

TEXTURE = {
    "tee": "cotton",
    "polo": "knit",
    "shirt": "cotton",
    "blouse": "cotton",
    "shell": "cotton",
    "hoodie": "fleece",
    "sweater": "knit",
    "quarterzip": "knit",
    "overshirt": "twill",
    "vest": "fleece",
    "jacket": "wool",
    "blazer": "wool",
    "overcoat": "wool",
    "trousers": "wool",
    "chinos": "twill",
    "jeans": "twill",
    "cargo": "twill",
    "aline_skirt": "wool",
    "pencil_skirt": "wool",
}


def paint_shirt(item):
    col = P.Colors(item)
    c = P.Canvas()
    builder = item["builder"]
    sleeve = sleeve_length(item)
    for region in P.TORSO.values():
        c.fill(region, col.primary)
    for limb in P.LIMBS:
        if sleeve > 0:
            c.fill(limb["up"], col.primary)
        if sleeve >= 1:
            c.fill(limb["down"], col.primary)
        for side in P.LIMB_SIDES:
            c.fill(limb[side], col.primary, 0.0, sleeve)
    P.texture_weave(c, col.primary, "fleece" if item.get("style") == "fleece" else TEXTURE.get(builder, "wool"))
    pattern = item.get("pattern")
    details = item.get("details") or []
    if pattern == "pinstripe":
        P.pattern_pinstripe(c, STRIPE, 9, 110)
    elif pattern == "plaid":
        P.pattern_plaid(c, col.secondary, col.accent)
    elif pattern == "stripe":
        P.pattern_stripe(c, P.contrast_on(col.primary, [col.accent, col.secondary]), 10, 3, 170)
    if "gingham" in details:
        P.pattern_check(c, P.contrast_on(col.primary, [col.accent, P.shade(col.primary, -0.35)]), 6, 90)
    if "rugby_stripes" in details:
        P.pattern_stripe(c, P.contrast_on(col.primary, [col.accent, col.secondary]), 18, 7, 230)
    P.side_shading(c, [F, B], col.primary)
    painter = TOP_PAINTERS.get(builder, paint_shirt_top)
    painter(c, item, col)
    if builder not in ("jacket", "blazer", "overcoat"):
        chest_mark(c, item, col)
    return c


# ---------------------------------------------------------------------------------------------------------
# Pants (bottom items)
# ---------------------------------------------------------------------------------------------------------
def waistband(c, col, belt=True, buckle=None, elastic=False, satin=False):
    regions = (F, B, *SIDES)
    if elastic:
        for region in regions:
            ribbing(c, region, 0, 11, P.shade(col.primary, -0.08))
        cord = P.contrast_on(col.primary, [col.accent, (233, 233, 228)])
        c.line(F, [(60, 6), (56, 30)], cord, 2)
        c.line(F, [(68, 6), (72, 30)], cord, 2)
        return
    band = col.secondary if (belt or satin) else P.shade(col.primary, -0.06)
    for region in regions:
        c.rect(region, 0, 0, region[2] - 1, 10, band)
        hem_line(c, region, 10, P.shade(band, -0.3))
    if belt:
        metal = buckle or col.accent
        c.rect(F, 56, 1, 71, 9, metal, outline=P.shade(metal, -0.35))
        c.rect(F, 60, 3, 67, 7, band)
        for u in (20, 100):  # belt loops
            c.rect(F, u, 0, u + 3, 13, P.shade(col.primary, -0.05))
        for u in (24, 100):
            c.rect(B, u, 0, u + 3, 13, P.shade(col.primary, -0.05))


def fly(c, col, curve=True):
    edge = P.shade(col.primary, -0.3)
    c.line(F, [(64, 11), (64, 50)], edge, 1)
    if curve:
        c.line(F, [(70, 11), (70, 44), (64, 52)], edge, 1)


def leg_crease(c, col, stripe_side=None):
    light = P.shade(col.primary, 0.12)
    for limb in P.LIMBS:
        c.line(limb["front"], [(32, 0), (32, 127)], light, 1, 200)
        c.line(limb["back"], [(32, 0), (32, 127)], light, 1, 120)


def turn_ups(c, col, height=8):
    for region in limb_regions():
        c.rect(region, 0, 127 - height, region[2] - 1, 127, P.shade(col.primary, -0.06))
        hem_line(c, region, 127 - height, P.shade(col.primary, -0.3))


def paint_trousers(c, item, col):
    style = item.get("style")
    if style == "jogger":
        waistband(c, col, elastic=True)
        for region in limb_regions():
            ribbing(c, region, 116, 127, P.shade(col.primary, -0.08))
        for limb in P.LIMBS:
            c.line(limb["outer"], [(32, 0), (32, 116)], P.shade(col.primary, -0.2), 1, 120)
        return
    waistband(c, col, belt=style != "evening", satin=style == "evening")
    fly(c, col)
    edge = P.shade(col.primary, -0.3)
    c.line(F, [(14, 12), (24, 40)], edge, 1)
    c.line(F, [(114, 12), (104, 40)], edge, 1)
    for u0 in (24, 76):
        c.line(B, [(u0, 30), (u0 + 26, 30)], edge, 2)  # welt pockets
    if style != "plain":
        leg_crease(c, col)
    if style == "evening":
        for limb in P.LIMBS:
            c.rect(limb["outer"], 28, 0, 35, 127, col.secondary)
    elif style == "wide":
        for region in limb_regions():
            hem_line(c, region, 124, edge)
    else:
        turn_ups(c, col)


def paint_chinos(c, item, col):
    waistband(c, col, belt=True)
    fly(c, col)
    edge = P.shade(col.primary, -0.28)
    c.line(F, [(10, 12), (26, 42)], edge, 2)  # slanted pockets
    c.line(F, [(118, 12), (102, 42)], edge, 2)
    for u0 in (24, 76):
        c.line(B, [(u0, 30), (u0 + 26, 30)], edge, 2)
        c.dot(B, u0 + 13, 34, 1.5, P.shade(col.primary, -0.4))
    leg_crease(c, col)
    turn_ups(c, col, 7)


def paint_jeans(c, item, col):
    stitch = P.contrast_on(col.primary, [col.accent, (201, 138, 59)])
    waistband(c, col, belt=True, buckle=BRASS)
    fly(c, col)
    c.dashed(F, (70, 12), (70, 46), stitch, 2, 2)
    # front pockets, coin pocket, rivets
    c.arc(F, (-8, -14, 34, 40), 0, 90, stitch, 1)
    c.arc(F, (94, -14, 136, 40), 90, 180, stitch, 1)
    c.rect(F, 90, 14, 104, 26, None, outline=stitch)
    for u, v in ((24, 14), (104, 14)):
        c.dot(F, u, v, 1.5, BRASS)
    # back yoke and patch pockets
    c.line(B, [(0, 22), (64, 30), (127, 22)], stitch, 1)
    for u0 in (18, 76):
        c.poly(B, [(u0, 34), (u0 + 34, 34), (u0 + 32, 66), (u0 + 17, 72), (u0 + 2, 66)], P.shade(col.primary, 0.03))
        c.line(B, [(u0, 34), (u0 + 2, 66), (u0 + 17, 72), (u0 + 32, 66), (u0 + 34, 34)], stitch, 1)
        c.line(B, [(u0 + 8, 46), (u0 + 17, 52), (u0 + 26, 46)], stitch, 1)
    # worn fade down the thighs, side seams, hems
    for limb in P.LIMBS:
        c.rect(limb["front"], 16, 6, 47, 60, P.shade(col.primary, 0.14), 70)
        c.dashed(limb["outer"], (32, 0), (32, 127), stitch, 2, 2)
    for region in limb_regions():
        c.dashed(region, (0, 122), (region[2] - 1, 122), stitch, 2, 2)


def paint_cargo(c, item, col):
    waistband(c, col, belt=True)
    fly(c, col)
    edge = P.shade(col.primary, -0.3)
    c.line(F, [(10, 12), (26, 42)], edge, 2)
    c.line(F, [(118, 12), (102, 42)], edge, 2)
    for limb in P.LIMBS:
        c.rect(limb["outer"], 10, 40, 53, 82, P.shade(col.primary, 0.04), outline=edge)  # cargo pocket
        c.rect(limb["outer"], 8, 36, 55, 46, P.shade(col.primary, 0.08), outline=edge)  # flap
        c.dot(limb["outer"], 32, 42, 2, P.shade(col.primary, -0.4))
    turn_ups(c, col, 8)


def paint_skirt(c, item, col, length):
    # waistband in the secondary colour (as the 3D skirt), a hem line and a back vent on the pencil skirt
    for region in (F, B, *SIDES):
        c.rect(region, 0, 0, region[2] - 1, 10, col.secondary)
        hem_line(c, region, 10, P.shade(col.secondary, -0.3))
    hem = int(128 * length) - 1
    for region in limb_regions():
        hem_line(c, region, hem - 2, P.shade(col.primary, -0.3))
    if item["builder"] == "pencil_skirt":
        for limb in P.LIMBS:
            c.line(limb["back"], [(32, hem - 26), (32, hem)], col.accent, 2)
    else:
        for u in (24, 48, 80, 104):  # A-line pleats
            c.line(F, [(u, 12), (u + (-4 if u < 64 else 4), 127)], P.shade(col.primary, -0.18), 1, 140)


BOTTOM_PAINTERS = {
    "trousers": paint_trousers,
    "chinos": paint_chinos,
    "jeans": paint_jeans,
    "cargo": paint_cargo,
}

SKIRT_LENGTH = {"pencil_skirt": 0.62, "aline_skirt": 0.55}


def paint_pants(item):
    col = P.Colors(item)
    c = P.Canvas()
    builder = item["builder"]
    skirt = SKIRT_LENGTH.get(builder)
    for region in P.TORSO.values():
        c.fill(region, col.primary)
    for limb in P.LIMBS:
        c.fill(limb["up"], col.primary)
        if not skirt:
            c.fill(limb["down"], col.primary)
        for side in P.LIMB_SIDES:
            c.fill(limb[side], col.primary, 0.0, skirt or 1.0)
    texture = "knit" if item.get("style") == "jogger" else TEXTURE.get(builder, "wool")
    P.texture_weave(c, col.primary, texture)
    if item.get("pattern") == "pinstripe":
        P.pattern_pinstripe(c, STRIPE, 9, 130)
    P.side_shading(c, [F, B, P.RIGHT_LIMB["front"], P.LEFT_LIMB["front"]], col.primary, 4, 45)
    if skirt:
        paint_skirt(c, item, col, skirt)
    else:
        BOTTOM_PAINTERS.get(builder, paint_trousers)(c, item, col)
    return c


# ---------------------------------------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------------------------------------
def render(item, kind):
    return paint_shirt(item) if kind == "shirt" else paint_pants(item)


def contact_sheet(rendered, path, columns=8):
    """All templates side by side (scaled down) with their ids, for a quick visual check."""
    tw, th = P.W // 3, P.H // 3
    rows = (len(rendered) + columns - 1) // columns
    sheet = Image.new("RGB", (columns * (tw + 8) + 8, rows * (th + 22) + 8), (40, 42, 48))
    d = ImageDraw.Draw(sheet)
    for i, (name, canvas) in enumerate(rendered):
        x = 8 + (i % columns) * (tw + 8)
        y = 8 + (i // columns) * (th + 22)
        thumb = canvas.img.resize((tw, th), Image.LANCZOS)
        bg = Image.new("RGBA", thumb.size, (90, 92, 98, 255))
        sheet.paste(Image.alpha_composite(bg, thumb).convert("RGB"), (x, y))
        d.text((x, y + th + 4), name[:30], fill=(230, 230, 230))
    sheet.save(path)


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--only", nargs="*", help="item ids to paint (default: all)")
    ap.add_argument("--out", default=OUT_DIR, help="output folder (default assets/clothing)")
    ap.add_argument("--catalog", help="catalog JSON from tools/clothing/export (default: run Lune)")
    ap.add_argument("--sheet", help="also write a contact sheet PNG of everything painted")
    ap.add_argument("--clean", action="store_true", help="delete template PNGs of items no longer in the catalog")
    args = ap.parse_args()

    items = load_catalog(args.catalog)
    todo = template_items(items)
    os.makedirs(args.out, exist_ok=True)
    wanted = {file_name(it, kind) for it, kind in todo}
    rendered = []
    for it, kind in todo:
        if args.only and it["id"] not in args.only:
            continue
        canvas = render(it, kind)
        canvas.save(os.path.join(args.out, file_name(it, kind)))
        rendered.append((it["id"], canvas))
    print("painted %d template(s) into %s" % (len(rendered), os.path.relpath(args.out, ROOT)))
    if args.clean:
        removed = 0
        for name in sorted(os.listdir(args.out)):
            if name.endswith(("_shirt.png", "_pants.png")) and name not in wanted:
                os.remove(os.path.join(args.out, name))
                removed += 1
        print("removed %d stale template(s)" % removed)
    if args.sheet and rendered:
        contact_sheet(rendered, args.sheet)
        print("contact sheet: %s" % args.sheet)


if __name__ == "__main__":
    main()
