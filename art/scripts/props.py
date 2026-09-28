"""Every Inkbound prop, built in Blender from code (see modelkit.py).

Each builder returns (parts, glow_parts, info): parts are merged into one textured mesh named
after the prop, glow parts into "<Prop>_Glow" (the game turns those to Neon), and info tells
the game how to place it (pivot "bottom" = stands on the floor, "centre" = placed by its
middle) and which Roblox material to use.
"""

import math

import modelkit as mk
from common import srgb

# Palette (sRGB 0-255, converted to linear for Blender)
INK = srgb(14, 14, 16)
LEATHER_A = srgb(20, 18, 20)
LEATHER_B = srgb(44, 36, 36)
PAPER_A = srgb(232, 224, 204)
PAPER_B = srgb(198, 186, 160)
RED = srgb(200, 22, 38)
DEEP_RED = srgb(110, 12, 20)
BRASS_A = srgb(176, 142, 74)
BRASS_B = srgb(120, 92, 44)
STEEL_A = srgb(170, 172, 180)
STEEL_B = srgb(110, 112, 120)
IRON_A = srgb(34, 34, 38)
IRON_B = srgb(56, 56, 62)
WOOD_LIGHT = srgb(120, 84, 54)
WOOD_DARK = srgb(62, 40, 26)
BONE_A = srgb(236, 228, 208)
BONE_B = srgb(180, 168, 146)

BUILDERS = {}


def prop(key, pivot="bottom", material="SmoothPlastic", collide=True, texture=1024, set="", lights=None,
         anchor=None, screen=None):
    """Registers a prop builder. set: which FBX it goes in ("" = InkboundModels.fbx, "Tokyo" =
    InkboundModels_Tokyo.fbx). lights: the lights the prop carries, so a lamp never exists
    without its fixture: [dict(at=(x, y, z), kind="point"|"spot", color=(r, g, b), range=,
    brightness=, angle=, face=)] in the builder's own coordinates (Blender, before grounding).
    anchor: the point (x, y) that stands where a map places the prop (a pole's foot), when that
    is not the middle of the prop's footprint.
    screen: for a case-file station's look, where the game's own screen part goes, as
    (x, y, z, width, height[, tilt]) in the builder's coordinates: the middle of the screen's
    face, which faces the worker (-Y); tilt leans its top back, in degrees. Stations are
    placed by their design origin (give them anchor=(0, 0))."""

    def register(fn):
        BUILDERS[key] = {
            "build": fn,
            "pivot": pivot,
            "material": material,
            "collide": collide,
            "texture": texture,
            "set": set,
            "lights": lights or [],
            "anchor": anchor,
            "screen": screen,
        }
        return fn

    return register


# Hero props ---------------------------------------------------------------------------------------------


@prop("Grimoire", pivot="centre", material="Leather", collide=False)
def grimoire():
    leather = mk.noisy("Grim_Leather", LEATHER_A, LEATHER_B, scale=18, detail=10, roughness=0.7)
    pages = mk.banded("Grim_Pages", PAPER_B, PAPER_A, frequency=160, axis="Z")
    brass = mk.noisy("Grim_Brass", BRASS_B, BRASS_A, scale=12, roughness=0.35, metallic=1.0)
    tooling = mk.flat("Grim_Tooling", DEEP_RED, 0.6)
    ribbon = mk.flat("Grim_Ribbon", RED, 0.8)
    w, d, h = 2.4, 3.2, 0.5
    parts = [
        mk.box("CoverTop", (w + 0.06, d + 0.06, 0.08), (0.02, 0, h / 2 - 0.04), mat=leather, bevel=0.03),
        mk.box("CoverBottom", (w + 0.06, d + 0.06, 0.08), (0.02, 0, -h / 2 + 0.04), mat=leather, bevel=0.03),
        mk.box("Pages", (w - 0.12, d - 0.1, h - 0.14), (0.04, 0, 0), mat=pages, bevel=0.02),
        mk.cylinder("Spine", h / 2 + 0.02, d + 0.06, (-w / 2 + 0.04, 0, 0), rot=(90, 0, 0), mat=leather, verts=20),
    ]
    # Raised tooled border on the cover.
    inset = 0.2
    for sx, sy, lx, ly in (
        (w - 2 * inset, 0.05, 0, d / 2 - inset),
        (w - 2 * inset, 0.05, 0, -d / 2 + inset),
        (0.05, d - 2 * inset, w / 2 - inset, 0),
        (0.05, d - 2 * inset, -w / 2 + inset, 0),
    ):
        parts.append(mk.box("Border", (sx, sy, 0.03), (lx + 0.02, ly, h / 2 + 0.01), mat=tooling, bevel=0.01))
    # Brass corner caps.
    for cx, cy in ((1, 1), (1, -1)):
        pts = [(0, 0), (-0.45, 0), (0, -0.45)]
        cap = mk.extrude_shape("Corner", pts, 0.12, mat=brass, bevel=0.015)
        cap.location = (cx * (w / 2 + 0.05), cy * (d / 2 + 0.05), h / 2 - 0.02)
        cap.rotation_euler = (0, 0, 0 if cy > 0 else math.radians(-90))
        parts.append(cap)
        cap2 = mk.extrude_shape("Corner", pts, 0.12, mat=brass, bevel=0.015)
        cap2.location = (cx * (w / 2 + 0.05), cy * (d / 2 + 0.05), -h / 2 + 0.02)
        cap2.rotation_euler = (0, 0, 0 if cy > 0 else math.radians(-90))
        parts.append(cap2)
    # Clasp: a strap over the front edge with a brass buckle.
    parts.append(mk.box("Strap", (0.5, 0.35, 0.06), (w / 2 - 0.05, 0, h / 2 + 0.02), mat=leather, bevel=0.015))
    parts.append(mk.box("StrapSide", (0.06, 0.35, h + 0.08), (w / 2 + 0.07, 0, 0), mat=leather, bevel=0.015))
    parts.append(mk.box("Buckle", (0.18, 0.5, 0.1), (w / 2 - 0.25, 0, h / 2 + 0.05), mat=brass, bevel=0.02))
    # Ribbon bookmark hanging from the page block.
    for i, (x, drop) in enumerate(((0.35, 0.9), (0.55, 0.7))):
        parts.append(
            mk.box("Ribbon", (0.12, drop, 0.015), (x, -d / 2 - drop / 2 + 0.05, -0.1 - i * 0.02), rot=(-8, 0, 4 * i),
                   mat=ribbon)
        )
    # The sigil: a red ring with a slash through it (Zero's mark, inverted), set into the cover.
    glow = mk.emissive("Grim_Glow", RED, 6)
    sigil = [
        mk.torus("Sigil", 0.62, 0.045, (0.02, 0, h / 2 + 0.02), mat=glow, major_segments=40, minor_segments=8),
        mk.torus("SigilInner", 0.42, 0.03, (0.02, 0, h / 2 + 0.02), mat=glow, major_segments=32, minor_segments=8),
        mk.box("SigilSlash", (0.06, 1.3, 0.04), (0.02, 0, h / 2 + 0.03), rot=(0, 0, -35), mat=glow),
    ]
    return parts, sigil


@prop("Handcuffs", pivot="centre", material="Metal", collide=False, texture=512)
def handcuffs():
    steel = mk.noisy("Cuff_Steel", STEEL_B, STEEL_A, scale=25, roughness=0.25, metallic=1.0)
    parts = []
    for side in (-1, 1):
        x = side * 0.55
        parts.append(mk.torus("Cuff", 0.34, 0.07, (x, 0, 0), rot=(0, 0, 0), mat=steel, major_segments=32))
        parts.append(mk.box("Lock", (0.26, 0.22, 0.2), (x + side * 0.08, 0.36, 0), mat=steel, bevel=0.03))
        parts.append(mk.cylinder("Hinge", 0.06, 0.2, (x, -0.34, 0), mat=steel, verts=12))
    # Chain: three links between the cuffs.
    for i, x in enumerate((-0.18, 0, 0.18)):
        parts.append(
            mk.torus("Link", 0.09, 0.025, (x, 0.42, 0), rot=(0, 90 if i % 2 else 0, 0), mat=steel,
                     major_segments=16, minor_segments=6)
        )
    return parts, []


@prop("Notebook", pivot="centre", material="SmoothPlastic", collide=False, texture=512)
def notebook():
    cover = mk.noisy("Note_Cover", srgb(28, 26, 30), srgb(48, 44, 48), scale=14, roughness=0.7)
    pages = mk.banded("Note_Pages", PAPER_B, PAPER_A, frequency=160, axis="Z")
    band = mk.flat("Note_Band", DEEP_RED, 0.7)
    parts = [
        mk.box("Back", (1.3, 0.95, 0.05), (0, 0, -0.08), mat=cover, bevel=0.015),
        mk.box("Front", (1.3, 0.95, 0.05), (0, 0, 0.08), mat=cover, bevel=0.015),
        mk.box("Pages", (1.24, 0.9, 0.12), (0.02, 0, 0), mat=pages, bevel=0.01),
        mk.box("Band", (0.06, 0.97, 0.19), (0.45, 0, 0), mat=band),
    ]
    return parts, []


@prop("Pen", pivot="centre", material="Metal", collide=False, texture=256)
def pen():
    body = mk.noisy("Pen_Body", srgb(10, 10, 12), srgb(30, 30, 34), scale=30, roughness=0.3)
    gold = mk.noisy("Pen_Gold", BRASS_B, BRASS_A, scale=20, roughness=0.3, metallic=1.0)
    parts = [
        mk.lathe("Barrel", [(0.0, -0.45), (0.035, -0.42), (0.05, -0.3), (0.055, 0.3), (0.05, 0.42), (0.0, 0.45)],
                 mat=body, segments=16),
        mk.cylinder("Band", 0.058, 0.05, (0, 0, 0.1), mat=gold, verts=16),
        mk.box("Clip", (0.02, 0.03, 0.35), (0.06, 0, 0.26), mat=gold),
        mk.lathe("Nib", [(0.035, -0.45), (0.02, -0.55), (0.0, -0.62)], mat=gold, segments=12),
    ]
    return parts, []


@prop("Memorial", pivot="bottom", material="Metal", collide=False, texture=512)
def memorial():
    iron = mk.noisy("Mem_Iron", IRON_A, IRON_B, scale=20, roughness=0.5, metallic=0.8)
    card = mk.noisy("Mem_Card", PAPER_B, PAPER_A, scale=40, roughness=0.9)
    parts = [
        mk.cylinder("Base", 0.45, 0.1, (0, 0, 0.05), mat=iron, verts=24, bevel=0.02),
        mk.cylinder("Post", 0.05, 2.1, (0, 0, 1.1), mat=iron, verts=12),
        mk.box("Holder", (1.7, 0.12, 0.1), (0, 0, 2.05), mat=iron, bevel=0.02),
        mk.box("Card", (1.6, 0.06, 1.1), (0, -0.02, 2.62), mat=card, bevel=0.01),
    ]
    return parts, [mk.box("Stripe", (1.2, 0.02, 0.07), (0, -0.06, 2.3), mat=mk.emissive("Mem_Glow", RED, 3))]


# The Specter and the map kit register themselves here.
import props_world  # noqa: E402,F401
import props_gameplay  # noqa: E402,F401
import props_stations  # noqa: E402,F401
import props_tokyo  # noqa: E402,F401
import props_agency  # noqa: E402,F401
