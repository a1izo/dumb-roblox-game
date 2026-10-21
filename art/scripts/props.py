"""Every Death's Gambit prop, built in Blender from code (see modelkit.py).

Each builder returns (parts, glow_parts, info): parts are merged into one textured mesh named
after the prop, glow parts into "<Prop>_Glow" (the game turns those to Neon), and info tells
the game how to place it (pivot "bottom" = stands on the floor, "centre" = placed by its
middle) and which Roblox material to use.
"""

import math
import random

from mathutils import Vector

import manual_art
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


# Death's Manual (the owner's design of 2026-10-12): a black hardbound book, 2.0 x 2.7 studs. Nothing on
# it glows and nothing but its drawing and its page edges is another colour than black: a skull in a
# ring, with rays, pressed into the front board in bone-white ink (manual_art.py), and burnt amber
# pages. It is very old. It opens: the front board turns over on its joint, down onto the table as a
# thick book's does at its first pages, and three loose leaves turn over onto it, leaving a ruled page
# open that the game writes names on (src/shared/ManualBook.luau).
MANUAL_BLACK_A = srgb(13, 13, 14)
MANUAL_BLACK_B = srgb(31, 30, 32)
MANUAL_AMBER_A = srgb(136, 70, 22)
MANUAL_AMBER_B = srgb(188, 108, 38)
BOARD = 0.05  # a board's thickness
LEAVES = 3


def _px(x0, y0, x1, y1):
    """A part of a 1024 pixel texture as (u0, v0, u1, v1)."""
    return (x0 / 1024, y0 / 1024, x1 / 1024, y1 / 1024)


# Where each face that carries a picture lies in the Manual's two textures. The front board has one
# of its own (the drawing wants every pixel a held prop may have); the rest of the book shares one.
MANUAL_FRONT = _px(4, 4, 739, 1019)
MANUAL_INSIDE = _px(748, 392, 1020, 1019)
MANUAL_FRONT_REST = _px(748, 4, 1020, 384)
MANUAL_PAGE = _px(4, 258, 564, 1020)
MANUAL_BACK = _px(576, 412, 1016, 1020)
MANUAL_SPINE = _px(4, 130, 564, 250)
MANUAL_FORE = _px(4, 66, 564, 122)
MANUAL_HEAD = _px(576, 348, 1016, 404)
MANUAL_TAIL = _px(576, 284, 1016, 340)
MANUAL_REST = _px(576, 4, 1016, 276)
MANUAL_UNSEEN = _px(4, 4, 60, 58)


def piece(parts, laid=None, into=(0.0, 0.0, 1.0, 1.0), own=False, bake=True, finish=None, exact=None):
    """A piece of a prop that moves by itself (a book's board), for a builder's third value:
    {"pieces": {name: piece(...)}, "laid", "into", "finish", "hinge", "turn", "page"}. Each piece becomes
    a mesh "<Prop>_<name>". laid, into: its faces laid by hand and where the others go (modelkit.unwrap),
    also given for the prop's main mesh; own: it has a texture set of its own instead of the main mesh's
    (exact: that set's size); bake: it is baked (a piece that only repeats faces of the main mesh is
    not); finish: pictures drawn onto the baked maps (modelkit.bake). hinge: {piece: (x, y, z)}, a point
    of the line each piece turns about, which runs along Y; turn: {piece: degrees} it turns, about -Y,
    to lie open; page: where the game writes."""
    return {"parts": parts, "laid": laid, "into": into, "own": own, "bake": bake, "finish": finish, "exact": exact}


def _faced(obj, normal, mat):
    """Gives the faces of a box that look along `normal` another material."""
    obj.data.materials.append(mat)
    for poly in obj.data.polygons:
        if poly.normal.dot(Vector(normal)) > 0.9:
            poly.material_index = len(obj.data.materials) - 1
    return obj


def _leaf(name, x0, x1, y0, y1, z, mat, seed, ear=False):
    """A loose leaf, torn along its fore-edge (ear: the corner at its head is folded away)."""
    rnd = random.Random(seed)
    across, up = 6, 8
    grid = []
    for j in range(up + 1):
        row = []
        for i in range(across + 1):
            x = x0 + (x1 - x0) * i / across
            y = y0 + (y1 - y0) * j / up
            if i == across:
                x -= rnd.uniform(0.0, 0.018) + (0.035 if rnd.random() < 0.2 else 0.0)
            if i > 0 and j in (0, up):
                y += rnd.uniform(-0.006, 0.006)
            row.append((x, y, z))
        grid.append(row)
    if ear:
        grid[up][across] = (grid[up][across - 1][0] + 0.02, grid[up - 1][across][1] + 0.03, z)
    return mk.sheet(name, grid, mat)


@prop("Grimoire", pivot="centre", material="Leather", collide=False)
def grimoire():
    leather = mk.noisy("Manual_Leather", MANUAL_BLACK_A, MANUAL_BLACK_B, roughness=0.55)
    pages = mk.noisy("Manual_Pages", MANUAL_AMBER_A, MANUAL_AMBER_B, roughness=0.85)
    endpaper = mk.flat("Manual_Endpaper", srgb(20, 19, 20), 0.9, kind="paper")
    ribbon = mk.flat("Manual_Ribbon", srgb(12, 12, 13), 0.75)
    across, up = manual_art.COVER  # a board
    page_w, page_h = manual_art.PAGE
    thick = 0.30  # the page block
    x1 = 1.0  # the fore-edge of the boards; the spine's outside is at -1.0
    x0 = x1 - across  # the boards' (and the block's) joint side
    back_z = -(BOARD + thick + 0.03 + BOARD) / 2  # the book's underside (0.03: the loose leaves)
    block_z = back_z + BOARD  # the block's underside
    top_z = block_z + thick  # the page that shows when the book is open
    front_z = -back_z  # the book's top
    px0, px1 = x0, x0 + page_w

    block = mk.box("Block", (page_w, page_h, thick), ((px0 + px1) / 2, 0, block_z + thick / 2), mat=pages, bevel=0.008)
    back = _faced(mk.box("BackBoard", (across, up, BOARD), ((x0 + x1) / 2, 0, back_z + BOARD / 2), mat=leather, bevel=0.012),
                  (0, 0, 1), endpaper)
    # One black ribbon, its tail hanging out at the foot.
    tail = mk.box("Ribbon", (0.11, 0.44, 0.012), (0.3, -up / 2 - 0.1, top_z - 0.02), rot=(-10, 0, 5), mat=ribbon)

    # The spine: a strip a little rounded outward, with four raised bands. Its top, above the open page's
    # height, goes over with the front board (it is the board's joint).
    def strip(inner, depth, y, z0, z1, band=0.0):
        points = [(inner, z0), (inner, z1)]
        steps = max(2, round(8 * (z1 - z0) / (front_z - back_z)))
        for k in range(steps + 1):
            z = z1 + (z0 - z1) * k / steps
            t = (front_z - z) / (front_z - back_z)
            points.append((-1.0 - 0.035 * math.sin(math.pi * t) - band, z))
        return mk.extrude_shape("SpineStrip", points, depth, loc=(0, y, 0), rot=(90, 0, 0), mat=leather, bevel=0.004)

    bands = (-0.93, -0.31, 0.31, 0.93)
    spine_parts = [strip(x0, up, 0, back_z, top_z)] + [strip(-0.99, 0.075, y, back_z, top_z, 0.018) for y in bands]
    joint_parts = [strip(x0, up, 0, top_z, front_z)] + [strip(-0.99, 0.075, y, top_z, front_z, 0.018) for y in bands]

    front = _faced(mk.box("FrontBoard", (across, up, BOARD), ((x0 + x1) / 2, 0, front_z - BOARD / 2), mat=leather, bevel=0.012),
                   (0, 0, -1), endpaper)
    leaf_z = [top_z + 0.006 + 0.008 * i for i in range(LEAVES)]
    leaves = [_leaf(f"Leaf{i + 1}", px0, px1 - 0.012, -page_h / 2 + 0.006, page_h / 2 - 0.006, leaf_z[i], pages,
                    seed=70 + i, ear=(i == LEAVES - 1)) for i in range(LEAVES)]

    page_span = (px0, px1, -page_h / 2, page_h / 2)

    def lay_main(obj):
        done = mk.lay(obj, mk.faces(obj, (0, 0, 1), lambda c: abs(c.z - top_z) < 0.004), MANUAL_PAGE, (1, 0, 0), (0, 1, 0),
                      page_span)
        done |= mk.lay(obj, mk.faces(obj, (0, 0, -1), lambda c: abs(c.z - back_z) < 0.004), MANUAL_BACK, (-1, 0, 0),
                       (0, 1, 0), (-x1, -x0, -up / 2, up / 2))
        inside = lambda c: block_z < c.z < top_z  # noqa: E731
        done |= mk.lay(obj, mk.faces(obj, (1, 0, 0), lambda c: abs(c.x - px1) < 0.004 and inside(c)), MANUAL_FORE,
                       (0, 1, 0), (0, 0, 1), (-page_h / 2, page_h / 2, block_z, top_z))
        done |= mk.lay(obj, mk.faces(obj, (0, 1, 0), lambda c: abs(c.y - page_h / 2) < 0.004 and inside(c)), MANUAL_HEAD,
                       (1, 0, 0), (0, 0, 1), (px0, px1, block_z, top_z))
        done |= mk.lay(obj, mk.faces(obj, (0, -1, 0), lambda c: abs(c.y + page_h / 2) < 0.004 and inside(c)), MANUAL_TAIL,
                       (1, 0, 0), (0, 0, 1), (px0, px1, block_z, top_z))
        # What nobody sees (the block's underside and the board under it, the block's joint side) shares
        # a corner of the texture.
        unseen = (mk.faces(obj, (0, 0, 1), lambda c: abs(c.z - block_z) < 0.004)
                  + mk.faces(obj, (0, 0, -1), lambda c: abs(c.z - block_z) < 0.004)
                  + mk.faces(obj, (-1, 0, 0), lambda c: abs(c.x - x0) < 0.004))
        done |= mk.lay(obj, unseen, MANUAL_UNSEEN, (1, 0, 0), (0, 1, 0))
        spine = [poly.index for poly in obj.data.polygons
                 if poly.normal.x < -0.25 and abs(poly.normal.y) < 0.5 and poly.center.x < x0 - 0.01]
        return done | mk.lay(obj, spine, MANUAL_SPINE, (0, 1, 0), (0, 0, 1), (-up / 2, up / 2, back_z, front_z))

    # Open, the front board lies on the table from the joint down: it turns about the spine's side at the
    # height of the open page, a little past over, until its far corner meets the table. The leaves turn
    # about the gutter onto it, the last to turn on top. (Angles found by a few steps of reckoning.)
    hinge_x, lining = -1.0, (front_z - BOARD) - top_z
    tilt = 0.0
    for _ in range(4):
        tilt = math.asin((top_z - back_z - (front_z - top_z) * math.cos(tilt)) / (x1 - hinge_x))
    leaf_turn = []
    for i in range(LEAVES):
        lie = 0.003 + 0.004 * (LEAVES - 1 - i)  # (the first to turn, the top one, lies lowest)
        slope = tilt
        for _ in range(4):
            far = px0 - (page_w - 0.012) * math.cos(slope)
            reach = (hinge_x + lining * math.sin(tilt) - far) / math.cos(tilt)  # along the open board
            board = top_z - reach * math.sin(tilt) - lining * math.cos(tilt)
            slope = math.asin((leaf_z[i] - board - lie) / (page_w - 0.012))
        leaf_turn.append(180 + math.degrees(slope))

    def lay_front(obj):
        board = lambda c: c.x > x0 - 0.001  # noqa: E731  (not the joint's ends)
        done = mk.lay(obj, mk.faces(obj, (0, 0, 1), board), MANUAL_FRONT, (1, 0, 0), (0, 1, 0), (x0, x1, -up / 2, up / 2))
        return done | mk.lay(obj, mk.faces(obj, (0, 0, -1), board), MANUAL_INSIDE, (-1, 0, 0), (0, 1, 0))

    def lay_leaf(obj):
        recto = [poly.index for poly in obj.data.polygons if poly.normal.z > 0]
        verso = [poly.index for poly in obj.data.polygons if poly.normal.z <= 0]
        done = mk.lay(obj, recto, MANUAL_PAGE, (1, 0, 0), (0, 1, 0), page_span)
        return done | mk.lay(obj, verso, MANUAL_PAGE, (-1, 0, 0), (0, 1, 0), (-px1, -px0, -page_h / 2, page_h / 2))

    def finish_main(color, normal, rough):
        lay = manual_art.lay_on
        lay(color, normal, rough, MANUAL_PAGE, manual_art.page, page_w, page_h)
        lay(color, normal, rough, MANUAL_BACK, manual_art.back, across, up)
        lay(color, normal, rough, MANUAL_SPINE, lambda c, r: manual_art.spine(c, r, up, front_z - back_z), up, front_z - back_z)
        lay(color, normal, rough, MANUAL_FORE, lambda c, r: manual_art.edge(c, r, page_h, thick, 41), page_h, thick)
        lay(color, normal, rough, MANUAL_HEAD, lambda c, r: manual_art.edge(c, r, page_w, thick, 42), page_w, thick)
        lay(color, normal, rough, MANUAL_TAIL, lambda c, r: manual_art.edge(c, r, page_w, thick, 43), page_w, thick)

    def finish_front(color, normal, rough):
        manual_art.lay_on(color, normal, rough, MANUAL_FRONT, manual_art.cover, across, up)

    more = {
        "laid": lay_main,
        "into": MANUAL_REST,
        "finish": finish_main,
        "pieces": {
            "Cover": piece([front, *joint_parts], lay_front, MANUAL_FRONT_REST, own=True, finish=finish_front, exact=1024),
            **{f"Leaf{i + 1}": piece([leaf], lay_leaf, bake=False) for i, leaf in enumerate(leaves)},
        },
        "hinge": {"Cover": (hinge_x, 0, top_z), **{f"Leaf{i + 1}": (px0, 0, leaf_z[i]) for i in range(LEAVES)}},
        "turn": {"Cover": round(180 + math.degrees(tilt), 2),
                 **{f"Leaf{i + 1}": round(leaf_turn[i], 2) for i in range(LEAVES)}},
        "page": {"at": ((px0 + px1) / 2, 0, top_z), "size": [page_w, page_h], **manual_art.RULE},
    }
    return [back, block, tail, *spine_parts], [], more


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


@prop("ChipBag", pivot="bottom", material="SmoothPlastic", collide=False, texture=256)
def chip_bag():
    """An open bag of potato chips stood on the desk: puffed red foil with a yellow band, the top rolled
    open and chips showing (Diavolo's role cutscene: the hidden page is in the bag)."""
    foil = mk.noisy("CB_Foil", srgb(150, 20, 26), srgb(196, 36, 40), scale=18, roughness=0.25, metallic=0.6)
    band = mk.flat("CB_Band", srgb(236, 196, 60), 0.4)
    inside = mk.noisy("CB_Inside", srgb(150, 150, 156), srgb(196, 196, 204), scale=20, roughness=0.2, metallic=0.9)
    potato = mk.noisy("CB_Chip", srgb(196, 150, 60), srgb(236, 196, 104), roughness=0.5, kind="plastic")
    parts = [mk.box("Bag", (0.9, 0.4, 1.05), (0, 0, 0.525), mat=foil, bevel=0.16),
             mk.box("Band", (0.92, 0.42, 0.22), (0, 0, 0.58), mat=band, bevel=0.08),
             mk.box("Mouth", (0.76, 0.3, 0.08), (0, 0, 1.06), mat=inside, bevel=0.03)]
    for k, (x, y, r) in enumerate(((-0.17, -0.03, 20), (0.14, 0.04, -15), (0.0, -0.07, 40))):
        parts.append(mk.box("Chip", (0.3, 0.03, 0.26), (x, y, 1.12 + 0.03 * k), rot=(70 + r * 0.3, r, 0), mat=potato,
                            bevel=0.01))
    return parts, []


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
import props_shop  # noqa: E402,F401
import props_emotes  # noqa: E402,F401
import props_seats  # noqa: E402,F401
