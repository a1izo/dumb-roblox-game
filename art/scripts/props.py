"""Every Death's Gambit prop, built in Blender from code (see modelkit.py).

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


def prop(key, pivot="bottom", material="SmoothPlastic", collide=True, texture=1024, set="Core", lights=None,
         anchor=None, screen=None):
    """Registers a prop builder. set: which FBX it goes in, DeathsGambitModels_<set>.fbx ("Core": the
    props every map and the game itself use, with the effect and UI textures; "Tokyo", "Agency",
    "Campus", "Lobby", "Meeting": one venue's own). lights: the lights the prop carries, so a lamp never exists
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


def _cup(tag, x, y, porcelain, gold, tea):
    """A teacup on its saucer, standing at (x, y): a gold rim, tea in it, the handle to +x."""
    return [
        mk.lathe(tag + "Saucer", [(0.001, 0.0), (0.22, 0.0), (0.36, 0.035), (0.38, 0.06), (0.34, 0.05), (0.12, 0.025),
                                  (0.001, 0.025)], (x, y, 0), mat=porcelain, segments=28),
        mk.lathe(tag + "Cup", [(0.001, 0.03), (0.1, 0.03), (0.12, 0.05), (0.16, 0.12), (0.2, 0.26), (0.21, 0.28),
                               (0.195, 0.28), (0.185, 0.25), (0.15, 0.12), (0.001, 0.08)], (x, y, 0), mat=porcelain,
                 segments=28),
        mk.torus(tag + "Rim", 0.205, 0.006, (x, y, 0.28), mat=gold, major_segments=28, minor_segments=4),
        mk.cylinder(tag + "Tea", 0.183, 0.01, (x, y, 0.22), mat=tea, verts=24),
        mk.torus(tag + "Handle", 0.07, 0.018, (x + 0.23, y, 0.17), rot=(90, 0, 0), mat=porcelain, major_segments=16,
                 minor_segments=6),
    ]


def _tea_mats():
    porcelain = mk.flat("Tea_Porcelain", srgb(240, 238, 232), 0.22)
    gold = mk.noisy("Tea_Gold", BRASS_B, BRASS_A, scale=20, roughness=0.3, metallic=1.0)
    tea = mk.flat("Tea_Tea", srgb(96, 46, 18), 0.1)
    return porcelain, gold, tea


@prop("Teacup", pivot="bottom", material="SmoothPlastic", collide=False, texture=256)
def teacup():
    """A white bone-china cup of tea on its saucer, gold at the rim (Ace's tea, the Butler's tray)."""
    return _cup("", 0.0, 0.0, *_tea_mats()), []


@prop("TeaTray", pivot="bottom", material="Metal", collide=False, texture=512)
def tea_tray():
    """The Butler's silver tray: a teapot, two cups on saucers, the milk jug, the sugar bowl and a plate
    of small cakes (Ace's sweets)."""
    porcelain, gold, tea = _tea_mats()
    silver = mk.noisy("Tray_Silver", STEEL_B, STEEL_A, scale=18, roughness=0.18, metallic=1.0)
    parts = [mk.box("Tray", (2.0, 1.3, 0.04), (0, 0, 0.02), mat=silver, bevel=0.01)]
    for x, y, w, d in ((0, 0.64, 2.0, 0.03), (0, -0.64, 2.0, 0.03), (0.99, 0, 0.03, 1.3), (-0.99, 0, 0.03, 1.3)):
        parts.append(mk.box("Lip", (w, d, 0.08), (x, y, 0.06), mat=silver))
    for side in (-1, 1):
        parts.append(mk.torus("Grip", 0.16, 0.025, (side * 1.04, 0, 0.1), rot=(0, 90, 90), mat=silver,
                              major_segments=16, minor_segments=6))
    # The teapot: round porcelain body, lid and knob, spout and handle.
    px, py = -0.5, 0.15
    parts += [
        mk.lathe("Pot", [(0.001, 0.04), (0.2, 0.04), (0.32, 0.14), (0.36, 0.3), (0.31, 0.46), (0.19, 0.53),
                         (0.001, 0.53)], (px, py, 0), mat=porcelain, segments=28),
        mk.lathe("Lid", [(0.2, 0.53), (0.17, 0.58), (0.06, 0.6), (0.001, 0.6)], (px, py, 0), mat=porcelain, segments=24),
        mk.sphere("Knob", 0.05, (px, py, 0.64), mat=gold, segments=12, rings=8),
        mk.tube("Spout", (px + 0.3, py, 0.2), (px + 0.58, py, 0.5), 0.06, 0.03, mat=porcelain),
        mk.torus("PotHandle", 0.14, 0.025, (px - 0.38, py, 0.32), rot=(90, 0, 0), mat=porcelain, major_segments=16,
                 minor_segments=6),
        mk.torus("PotBand", 0.355, 0.008, (px, py, 0.3), mat=gold, major_segments=28, minor_segments=4),
    ]
    parts += _cup("A", 0.25, 0.3, porcelain, gold, tea)
    parts += _cup("B", 0.62, -0.2, porcelain, gold, tea)
    # Milk jug, sugar bowl with its cubes, a plate of cakes.
    parts.append(mk.lathe("Jug", [(0.001, 0.04), (0.09, 0.04), (0.1, 0.14), (0.08, 0.22), (0.1, 0.26), (0.001, 0.2)],
                          (-0.15, -0.35, 0), mat=porcelain, segments=20))
    parts.append(mk.lathe("Bowl", [(0.001, 0.04), (0.08, 0.04), (0.14, 0.14), (0.13, 0.15), (0.001, 0.08)],
                          (-0.62, -0.38, 0), mat=porcelain, segments=20))
    white = mk.flat("Tray_Sugar", srgb(250, 250, 248), 0.6)
    for k, (dx, dy) in enumerate(((-0.03, 0.02), (0.04, -0.03), (0.0, 0.05))):
        parts.append(mk.box("Sugar", (0.05, 0.05, 0.05), (-0.62 + dx, -0.38 + dy, 0.13 + 0.02 * k), rot=(0, 0, 20 * k),
                            mat=white))
    parts.append(mk.cylinder("Plate", 0.26, 0.02, (0.3, -0.38, 0.05), mat=porcelain, verts=28))
    for k, (dx, dy, color) in enumerate(((-0.1, 0.0, (250, 214, 220)), (0.08, 0.06, (246, 236, 214)),
                                          (0.06, -0.1, (232, 200, 150)))):
        cake = mk.flat(f"Tray_Cake{k}", srgb(*color), 0.7)
        parts.append(mk.box("Cake", (0.12, 0.12, 0.08), (0.3 + dx, -0.38 + dy, 0.1), rot=(0, 0, 30 * k), mat=cake,
                            bevel=0.01))
        parts.append(mk.sphere("Berry", 0.025, (0.3 + dx, -0.38 + dy, 0.155), mat=mk.flat("Tray_Berry", RED, 0.3),
                               segments=8, rings=6))
    return parts, []


@prop("BureauBadge", pivot="centre", material="Leather", collide=False, texture=256)
def bureau_badge():
    """An Operative's badge wallet held open: the gold shield on the right, the ID card on the left
    (upright, its face to -Y)."""
    leather = mk.noisy("Badge_Leather", LEATHER_A, LEATHER_B, scale=16, roughness=0.6)
    gold = mk.noisy("Badge_Gold", BRASS_B, BRASS_A, scale=20, roughness=0.3, metallic=1.0)
    card = mk.flat("Badge_Card", srgb(236, 238, 240), 0.5)
    band = mk.flat("Badge_Band", srgb(24, 52, 110), 0.5)
    photo = mk.flat("Badge_Photo", srgb(90, 92, 98), 0.6)
    shield = [(0.0, 0.2), (0.12, 0.16), (0.16, 0.04), (0.11, -0.1), (0.0, -0.2), (-0.11, -0.1), (-0.16, 0.04),
              (-0.12, 0.16)]
    parts = [
        mk.box("Left", (0.42, 0.03, 0.6), (-0.22, 0, 0), mat=leather, bevel=0.01),
        mk.box("Right", (0.42, 0.03, 0.6), (0.22, 0, 0), mat=leather, bevel=0.01),
        mk.extrude_shape("Shield", shield, 0.03, (0.22, -0.03, 0.02), rot=(90, 0, 0), mat=gold, bevel=0.008),
        mk.cylinder("Seal", 0.07, 0.02, (0.22, -0.05, 0.03), rot=(90, 0, 0), mat=band, verts=20),
        mk.box("Card", (0.34, 0.008, 0.5), (-0.22, -0.02, 0), mat=card),
        mk.box("Band", (0.34, 0.01, 0.08), (-0.22, -0.022, 0.19), mat=band),
        mk.box("Photo", (0.12, 0.01, 0.15), (-0.31, -0.022, 0.0), mat=photo),
    ]
    for k in range(3):
        parts.append(mk.box("Line", (0.14, 0.01, 0.015), (-0.15, -0.022, 0.04 - 0.05 * k), mat=band))
    return parts, []


@prop("NotebookOpen", pivot="bottom", material="SmoothPlastic", collide=False, texture=512)
def notebook_open():
    """The plain black notebook lying open (Diavolo writing): both covers flat, the pages lined, the left
    page full of cramped handwriting, the right half written, the red ribbon across."""
    cover = mk.noisy("NoteO_Cover", srgb(28, 26, 30), srgb(48, 44, 48), scale=14, roughness=0.7)
    pages = mk.flat("NoteO_Pages", PAPER_A, 0.85)
    ink = mk.flat("NoteO_Ink", srgb(26, 22, 30), 0.6)
    band = mk.flat("NoteO_Band", DEEP_RED, 0.7)
    parts = [mk.box("CoverL", (1.32, 0.97, 0.04), (-0.66, 0, 0.02), mat=cover, bevel=0.01),
             mk.box("CoverR", (1.32, 0.97, 0.04), (0.66, 0, 0.02), mat=cover, bevel=0.01),
             mk.box("PagesL", (1.24, 0.9, 0.06), (-0.63, 0, 0.07), mat=pages, bevel=0.005),
             mk.box("PagesR", (1.24, 0.9, 0.06), (0.63, 0, 0.07), mat=pages, bevel=0.005),
             mk.box("Spine", (0.06, 0.95, 0.08), (0, 0, 0.05), mat=cover),
             mk.box("Ribbon", (0.05, 1.05, 0.005), (0.25, -0.02, 0.105), rot=(0, 0, 8), mat=band)]
    rng = __import__("random").Random(7)
    for side, rows in ((-1, 8), (1, 4)):
        for r in range(rows):
            y = 0.34 - r * 0.09
            x = side * 0.14
            while abs(x) < 1.05:
                w = rng.uniform(0.06, 0.16)
                parts.append(mk.box("Word", (w, 0.012, 0.004), (x + side * w / 2, y, 0.102), mat=ink))
                x += side * (w + rng.uniform(0.06, 0.1))
    return parts, []


@prop("Smartphone", pivot="centre", material="SmoothPlastic", collide=False, texture=256)
def smartphone():
    """A black phone held up, its screen lit a hard red (the summons)."""
    body = mk.flat("Phone_Body", srgb(14, 14, 16), 0.3, 0.2)
    rim = mk.noisy("Phone_Rim", STEEL_B, STEEL_A, scale=20, roughness=0.3, metallic=1.0)
    parts = [mk.box("Body", (0.52, 1.02, 0.07), (0, 0, 0), mat=body, bevel=0.04),
             mk.box("Rim", (0.54, 1.04, 0.04), (0, 0, 0), mat=rim, bevel=0.04),
             mk.box("Lens", (0.08, 0.08, 0.02), (-0.16, 0.42, -0.04), mat=body)]
    glows = [mk.box("Screen", (0.46, 0.92, 0.01), (0, 0, 0.04), mat=mk.emissive("Phone_Glow", srgb(255, 40, 46), 4))]
    return parts, glows


@prop("CRTTelevision", pivot="bottom", material="SmoothPlastic", collide=True, texture=512,
      lights=[dict(at=(0, -1.6, 1.4), kind="point", color=(170, 196, 255), range=12, brightness=0.9)])
def crt_television():
    """An old television on its own short legs: a wood-grain cabinet, the glass bulging out of a dark
    bezel and lit a cold blue, two dials and a speaker grille, rabbit-ear antennas."""
    wood = mk.wood("TV_Wood", srgb(96, 62, 38), srgb(54, 32, 20), scale=4)
    dark = mk.flat("TV_Dark", srgb(20, 20, 22), 0.5)
    chrome = mk.noisy("TV_Chrome", STEEL_B, STEEL_A, scale=20, roughness=0.25, metallic=1.0)
    parts = [mk.box("Cabinet", (3.0, 2.2, 2.2), (0, 0, 1.75), mat=wood, bevel=0.1),
             mk.box("Bezel", (2.2, 0.08, 1.8), (-0.3, -1.1, 1.75), mat=dark, bevel=0.06)]
    for k, z in enumerate((2.15, 1.65)):
        parts.append(mk.cylinder("Dial", 0.14, 0.12, (1.1, -1.14, z), rot=(90, 0, 0), mat=chrome, verts=16))
    for k in range(5):
        parts.append(mk.box("Grille", (0.45, 0.04, 0.04), (1.1, -1.12, 1.2 - k * 0.12), mat=dark))
    for sx in (-1, 1):
        parts.append(mk.tube("Leg", (sx * 1.2, 0.0, 0.66), (sx * 1.35, 0.0, 0.0), 0.06, mat=dark))
        parts.append(mk.tube("Ear", (0, 0.3, 2.84), (sx * 0.9, 0.5, 4.2), 0.025, mat=chrome))
    parts.append(mk.sphere("EarBase", 0.18, (0, 0.3, 2.86), mat=dark, segments=12, rings=8))
    glows = [mk.box("Screen", (1.9, 0.06, 1.5), (-0.3, -1.12, 1.75), mat=mk.emissive("TV_Glow", srgb(170, 196, 255), 3),
                    bevel=0.12)]
    return parts, glows


@prop("ShrineDoor", pivot="bottom", material="WoodPlanks", collide=True, texture=512)
def shrine_door():
    """One leaf of the shrine's heavy double door: dark planks, three iron bands with studs, a ring pull.
    Its hinge is on its left edge (seen from the outside), x = -1.6; the door is 3.2 wide, 8 high."""
    wood = mk.wood("Door_Wood", srgb(62, 40, 28), srgb(30, 18, 12), scale=3)
    iron = mk.noisy("Door_Iron", IRON_A, IRON_B, scale=18, roughness=0.6, metallic=0.8)
    parts = [mk.box("Leaf", (3.2, 0.4, 8.0), (0, 0, 4.0), mat=wood, bevel=0.04)]
    for k in range(4):
        parts.append(mk.box("Plank", (0.04, 0.42, 7.9), (-1.2 + k * 0.8, 0, 4.0), mat=iron))
    for z in (1.2, 4.0, 6.8):
        parts.append(mk.box("Band", (3.24, 0.46, 0.3), (0, 0, z), mat=iron, bevel=0.02))
        for k in range(5):
            parts.append(mk.sphere("Stud", 0.06, (-1.3 + k * 0.65, -0.25, z), mat=iron, segments=8, rings=6))
    parts.append(mk.torus("Ring", 0.28, 0.05, (1.1, -0.32, 3.8), rot=(90, 0, 0), mat=iron, major_segments=20))
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
import props_campus  # noqa: E402,F401
import props_lobby  # noqa: E402,F401
import props_meeting  # noqa: E402,F401
