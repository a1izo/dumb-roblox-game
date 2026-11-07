"""The Academy's practice stations (set "Lobby"): where the Trial is learnt, a ring of seven, each an altar the one
practising stands at and a stone stele behind it with the drill's name on its slate (the game writes the name: the
stele's slate is left bare for it).

Both are hero props (a player stands at arm's length from them): bevelled masonry baked from a weathered copy of
itself (build_props._high_of), skull reliefs, a ledger open on the altar with its quill in the inkwell, candles that
have burnt down over many nights, ash in every corner. They face -Y (where the one practising stands) and stand on
z = 0, about 3.5 studs to the metre."""

import json
import math
import random

import modelkit as mk
import propkit as pk
from common import srgb
from props import prop
from props_lobby import CANDLE, candle, candle_wax
from props_mapown2 import snow_on

# Weathering asked of the high-detail copy (build_props._high_of): pitted, chipped stone; a little grain on bone.
STONE = {"sub": 2, "disp": [("cells", 0.022, 0.55), ("grain", 0.01, 0.09)]}
WORN = {"sub": 1, "disp": [("cells", 0.012, 0.3), ("grain", 0.006, 0.06)]}
BONE = {"sub": 0, "disp": [("grain", 0.004, 0.02)]}


def weathered(obj, detail=STONE):
    obj["dg_detail"] = json.dumps(detail)
    return obj


def _stones(prefix):
    """The Academy's stone: a grey limestone gone dark with age, a darker one for plinths, the black slate the names
    are written on, bone, and the ash that has settled on every ledge."""
    return {
        "stone": mk.noisy(prefix + "_Stone", srgb(76, 76, 78), srgb(118, 116, 112), roughness=0.9),
        "dark": mk.noisy(prefix + "Dark_Stone", srgb(44, 44, 47), srgb(74, 73, 74), roughness=0.92),
        "slate": mk.noisy(prefix + "Slate_Stone", srgb(16, 16, 18), srgb(30, 30, 33), roughness=0.38),
        "bone": mk.noisy(prefix + "_Bone", srgb(150, 144, 128), srgb(204, 198, 180), roughness=0.75),
        "void": mk.flat(prefix + "_Void", srgb(8, 8, 10), roughness=0.95),
        "ash": mk.noisy(prefix + "_Ash", srgb(88, 88, 90), srgb(122, 122, 124), roughness=0.97),
    }


def _profile_body(name, outline, depth, y, mat, bevel=0.05):
    """A slab whose front outline (x, z points, anticlockwise from the front) is extruded `depth` back along +Y from y."""
    obj = mk.extrude_shape(name, outline, depth, loc=(0, y + depth / 2, 0), rot=(90, 0, 0), mat=mat, bevel=bevel)
    return obj


# The stele's measures: the game writes the drill's name on the slate (Lobby.luau drillDesk puts its writing at
# TABLET_PLAQUE, from the stele's foot under its middle; studs, Roblox axes: x across, y up, z toward the altar's
# back, so the plaque's face is at -z).
TABLET_FACE = -0.5  # the stele's front face (Blender y)
TABLET_SLATE = (0.0, 6.5, 6.1, 1.62)  # the slate's middle (x, z), its width and height
SLATE_PROUD = 0.1  # how far the slate stands out of the face


@prop("PracticeTablet", pivot="bottom", material="Slate", collide=False, texture=1024, set="Lobby", anchor=(0, 0),
      detail=True, normal=512)
def practice_tablet():
    """The stele behind a practice altar: a slab of dark grey stone on a two-step plinth, its shoulders cut back and its
    top rising to a low point; a raised moulding round a sunk field with a ring carved in it and a skull standing out
    of the ring, a band of dentils under it; over the field a slate of polished black stone let in for the drill's name
    (left bare: the game writes it). Chipped, pitted and dusted with ash on every ledge."""
    m = _stones("Tab")
    w, top = 6.4, 8.1
    # (everything centred front to back on the body's middle, y = 0: the game places the stele by the middle of its
    # footprint and writes on the slate at TABLET_FACE from there)
    parts = [weathered(mk.box("PlinthLow", (7.4, 2.1, 0.45), (0, 0.0, 0.225), mat=m["dark"], bevel=0.07)),
             weathered(mk.box("PlinthHigh", (6.95, 1.55, 0.4), (0, 0.0, 0.65), mat=m["dark"], bevel=0.06))]
    # The body: shoulders cut back over the slate, a low gable to the top.
    outline = [(-w / 2, 0.84), (w / 2, 0.84), (w / 2, 7.42), (w / 2 - 0.5, 7.78), (1.0, 7.92), (0.0, top), (-1.0, 7.92),
               (-w / 2 + 0.5, 7.78), (-w / 2, 7.42)]
    depth = 1.0
    parts.append(weathered(_profile_body("Body", outline, depth, TABLET_FACE, m["stone"], bevel=0.06)))
    # A cornice under the slate, and the gable's coping.
    parts.append(weathered(mk.box("Cornice", (w + 0.3, depth + 0.3, 0.26), (0, TABLET_FACE + depth / 2, 5.52),
                                  mat=m["stone"], bevel=0.06), WORN))
    for sx in (-1, 1):
        a = math.atan2(top - 7.92, 1.0)
        parts.append(weathered(mk.box("Coping", (1.06, depth + 0.16, 0.18),
                                      (sx * 0.52, TABLET_FACE + depth / 2, (top + 7.92) / 2 + 0.07),
                                      rot=(0, sx * math.degrees(a), 0), mat=m["stone"], bevel=0.04), WORN))
    # The slate for the name, in a thin bevelled frame.
    sx, sz, sw, sh = TABLET_SLATE
    face = TABLET_FACE
    parts.append(mk.box("Slate", (sw, 0.12, sh), (sx, face - SLATE_PROUD + 0.06, sz), mat=m["slate"], bevel=0.02))
    parts += [weathered(p, WORN) for p in pk.frame("SlateFrame", sw + 0.3, sh + 0.3, 0.15, 0.16, (sx, face - 0.05, sz),
                                                    m["dark"])]
    # The field: a raised moulding round it, a ring cut in it with a skull standing out of the ring.
    fx0, fx1, fz0, fz1 = -2.7, 2.7, 1.25, 5.05
    parts += [weathered(p, WORN) for p in pk.frame("Moulding", fx1 - fx0, fz1 - fz0, 0.26, 0.12,
                                                    (0.0, face - 0.05, (fz0 + fz1) / 2), m["stone"])]
    ring_z = 3.45
    parts.append(weathered(mk.torus("Ring", 1.18, 0.1, (0.0, face - 0.02, ring_z), rot=(90, 0, 0), mat=m["stone"],
                                    major_segments=40, minor_segments=8), WORN))
    parts.append(weathered(mk.torus("RingIn", 0.98, 0.05, (0.0, face - 0.01, ring_z), rot=(90, 0, 0), mat=m["dark"],
                                    major_segments=40, minor_segments=6), WORN))
    skull = pk.skull("Skull", (0.0, face - 0.12, ring_z + 0.05), 0.62, m["bone"], m["void"], segments=30, teeth=6)
    for p in skull:
        # (a relief: the skull half sunk into the stone, flattened front to back)
        p.scale = (p.scale[0], p.scale[1] * 0.55, p.scale[2])
        weathered(p, BONE)
    parts += skull
    # Dentils under the ring, and two grooves cut down the field either side of it.
    for k in range(11):
        x = -2.25 + k * 0.45
        parts.append(weathered(mk.box("Dentil", (0.26, 0.1, 0.26), (x, face - 0.04, 1.72), mat=m["stone"], bevel=0.02),
                               WORN))
    for gx in (-2.05, 2.05):
        parts.append(mk.box("Groove", (0.08, 0.02, 2.6), (gx, face - 0.005, ring_z), mat=m["void"]))
    # Ash on the plinth's steps and the cornice (where it has settled), feathered out at its edges.
    parts.append(snow_on(parts[:2] + [parts[3]], m["ash"], cell=0.18, depth=0.05, flat=0.75, name="AshCover"))
    return parts, []


@prop("PracticeAltar", pivot="bottom", material="Slate", collide=False, texture=1024, set="Lobby", anchor=(0, 0),
      detail=True, normal=512, lights=[dict(at=(0, 0.7, 4.0), kind="point", color=CANDLE, range=11, brightness=0.6)])
def practice_altar():
    """The Academy's practice altar, built round the game's invisible drill desk (5 x 3 x 2.4; the one practising
    stands at -Y): a moulded slab of grey stone on two pedestals, each with a sunk panel and a skull standing out of it,
    a carved apron between them over a dark niche; on the slab an old ledger lying open, its quill in a glass inkwell,
    a skull for a paperweight, and candles burnt down at the back corners, their wax run over the edge."""
    m = _stones("Alt")
    leather = mk.noisy("Alt_Leather", srgb(26, 20, 20), srgb(54, 40, 34), roughness=0.62)
    pages = mk.banded("Alt_Pages", srgb(170, 160, 134), srgb(212, 204, 180), frequency=150, axis="Z")
    paper = mk.noisy("Alt_Paper", srgb(186, 176, 150), srgb(222, 214, 192), roughness=0.85)
    ink = mk.flat("Alt_Ink", srgb(14, 12, 12), 0.35)
    glass = mk.flat("AltInk_Glass", srgb(22, 26, 30), 0.12)
    feather = mk.noisy("Alt_Feather", srgb(150, 146, 136), srgb(212, 208, 198), roughness=0.8)
    wax = candle_wax("Alt")
    wick = mk.flat("Alt_Wick", srgb(16, 14, 13), 0.9)
    parts = [weathered(mk.box("Plinth", (5.6, 2.9, 0.3), (0, 0, 0.15), mat=m["dark"], bevel=0.06))]
    # The pedestals: a base course, the shaft with its sunk panel and skull, a capital under the slab.
    for sx in (-1, 1):
        x = sx * 1.92
        parts += [weathered(mk.box("PedBase", (1.5, 2.45, 0.28), (x, 0.0, 0.44), mat=m["stone"], bevel=0.05)),
                  weathered(mk.box("PedShaft", (1.2, 2.15, 1.9), (x, 0.0, 1.53), mat=m["stone"], bevel=0.06)),
                  weathered(mk.box("PedCap", (1.45, 2.4, 0.22), (x, 0.0, 2.59), mat=m["stone"], bevel=0.05))]
        parts += [weathered(p, WORN) for p in pk.frame(f"Panel{sx}", 0.92, 1.5, 0.11, 0.06, (x, -1.085, 1.55),
                                                         m["stone"])]
        skull = pk.skull(f"PedSkull{sx}", (x, -1.12, 1.6), 0.3, m["bone"], m["void"], segments=18, teeth=4)
        for p in skull:
            p.scale = (p.scale[0], p.scale[1] * 0.6, p.scale[2])
            weathered(p, BONE)
        parts += skull
    # The apron between the pedestals, its carved band, and the dark niche under it.
    parts += [weathered(mk.box("Apron", (2.75, 0.5, 0.62), (0, -0.85, 2.29), mat=m["stone"], bevel=0.05)),
              mk.box("Niche", (2.6, 1.9, 1.75), (0, 0.15, 1.18), mat=m["void"]),
              weathered(mk.box("BackWall", (2.7, 0.3, 2.0), (0, 1.0, 1.3), mat=m["dark"], bevel=0.04))]
    for k in range(7):
        parts.append(weathered(mk.box("Dentil", (0.2, 0.1, 0.18), (-1.08 + k * 0.36, -1.12, 2.18), mat=m["stone"],
                                      bevel=0.02), WORN))
    # The slab, moulded: a fillet under the top.
    parts += [weathered(mk.box("SlabUnder", (5.3, 2.62, 0.16), (0, 0, 2.78), mat=m["stone"], bevel=0.05)),
              weathered(mk.box("Slab", (5.62, 2.92, 0.16), (0, 0, 2.93), mat=m["stone"], bevel=0.05))]
    top = 3.01
    # The ledger: leather boards, the page blocks, the open pages curling up toward the spine, a few lines written.
    by = -0.28
    for side in (-1, 1):
        parts.append(mk.box("Board", (1.36, 1.7, 0.05), (side * 0.7, by, top + 0.025), rot=(0, side * -2.0, 0),
                            mat=leather, bevel=0.01))
        parts.append(mk.box("Block", (1.24, 1.58, 0.1), (side * 0.66, by, top + 0.1), rot=(0, side * -2.0, 0),
                            mat=pages))
        rows = []
        for j in range(5):
            y = by - 0.78 + 1.56 * j / 4
            row = []
            for i in range(7):
                u = i / 6  # (0 at the spine, 1 at the fore-edge)
                x = side * (0.03 + 1.24 * u)
                z = top + 0.155 + 0.09 * (1 - u) ** 2.2 - 0.012 * math.sin(math.pi * u)
                row.append((x, y, z))
            rows.append(row if side > 0 else list(reversed(row)))
        parts.append(mk.sheet("Page", rows, mat=paper, apart=0.004))
        for k in range(6):
            lx = side * 0.66
            parts.append(mk.box("Line", (0.82 if k % 3 else 0.6, 0.022, 0.006),
                                (lx + side * (0.08 if k % 3 == 0 else 0.0), by + 0.55 - k * 0.2, top + 0.162),
                                mat=ink))
    parts.append(mk.cylinder("Spine", 0.07, 1.68, (0, by, top + 0.06), rot=(90, 0, 0), mat=leather, verts=10))
    # The inkwell and its quill, at the right; a skull at the left back corner.
    ix, iy = 1.85, 0.42
    parts += [mk.lathe("Inkwell", [(0.0, top), (0.2, top), (0.22, top + 0.08), (0.2, top + 0.2), (0.1, top + 0.26),
                                   (0.08, top + 0.32), (0.0, top + 0.32)], mat=glass, segments=16),
              mk.cylinder("InkTop", 0.07, 0.01, (ix, iy, top + 0.315), mat=ink, verts=10)]
    parts[-2].location = (ix, iy, 0.0)
    quill_a, quill_b = (ix + 0.02, iy + 0.02, top + 0.22), (ix + 0.36, iy + 0.58, top + 1.32)
    parts.append(mk.tube("Quill", quill_a, quill_b, 0.022, 0.012, mat=feather, verts=6))
    vane = []
    for j in range(6):
        u = 0.25 + 0.75 * j / 5
        cx = quill_a[0] + (quill_b[0] - quill_a[0]) * u
        cy = quill_a[1] + (quill_b[1] - quill_a[1]) * u
        cz = quill_a[2] + (quill_b[2] - quill_a[2]) * u
        wv = 0.11 * math.sin(math.pi * min(1.0, (u - 0.2) / 0.85))
        vane.append([(cx - wv, cy + wv * 0.4, cz), (cx, cy, cz + 0.01), (cx + wv * 0.8, cy - wv * 0.3, cz)])
    parts.append(mk.sheet("Vane", vane, mat=feather, apart=0.003))
    skull = pk.skull("DeskSkull", (-1.95, 0.55, top + 0.3), 0.3, m["bone"], m["void"], yaw=18, segments=20, teeth=5)
    parts += [weathered(p, BONE) for p in skull]
    # Candles burnt down at the back corners on pools of old wax, run over the slab's edge.
    rng = random.Random(23)
    flames = []
    for sx in (-1, 1):
        cx = sx * 2.25
        pool = mk.cylinder(f"Pool{sx}", 0.42, 0.04, (cx, 0.98, top + 0.02), mat=wax, verts=18)
        pool.scale = (1.0, 0.8, 1.0)
        parts.append(pool)
        for k, (dx, dy, h) in enumerate(((0.0, 0.0, 0.95), (0.3, -0.12, 0.55))):
            body, tip = candle(f"Candle{sx}{k}", cx + dx * sx, 0.98 + dy, top + 0.03, 0.12, h, wax, wick, rng, drips=2)
            parts += body
            flames.append((tip[0], tip[1], tip[2], 0.45))
        # (where it ran over the back edge and set)
        for q in range(3):
            parts.append(mk.tube(f"Run{sx}{q}", (cx + sx * (q - 1) * 0.16, 1.46, top + 0.01),
                                 (cx + sx * (q - 1) * 0.18, 1.48, top - 0.18 - 0.1 * q), 0.035, 0.05, mat=wax, verts=6))
    parts.append(snow_on([parts[0]] + [p for p in parts if p.name.startswith("PedBase")], m["ash"], cell=0.16,
                         depth=0.04, flat=0.8, name="AshCover"))
    return parts, [], {"flames": flames}


# The plaza's stones: the stele Most Wins is written on, the round bases the tableaux and the bell stand on, the
# twelve candle stones of the ready circle.

WINS_BOARD = (0.0, 6.0, 10.6, 10.6)  # the slate's middle (x, z), its width and height (plan.STELES "wins": 10 x 10)
WINS_FACE = -1.2  # the stele's front face (plan.STELE_T is 2.4 deep)


@prop("WinsStele", pivot="bottom", material="Slate", collide=False, texture=1024, set="Lobby", anchor=(0, 0),
      detail=True, normal=512)
def wins_stele():
    """The stele beside the throne that the one board left in the world is written on (Most Wins; the game draws the
    board on its slate): a broad slab of the Academy's stone on a two-step plinth, fluted pilasters at its edges, a
    pediment over a cornice, a crown carved over a skull at its top, the slate let into a moulded frame."""
    m = _stones("Win")
    w, depth = 14.0, 2.4
    parts = [weathered(mk.box("PlinthLow", (16.6, 4.6, 0.5), (0, 0.0, 0.25), mat=m["dark"], bevel=0.08)),
             weathered(mk.box("PlinthHigh", (15.6, 3.6, 0.45), (0, 0.0, 0.72), mat=m["dark"], bevel=0.07))]
    outline = [(-w / 2, 0.94), (w / 2, 0.94), (w / 2, 13.2), (-w / 2, 13.2)]
    parts.append(weathered(_profile_body("Body", outline, depth, WINS_FACE, m["stone"], bevel=0.08)))
    # The cornice and the pediment over it, rising to a low point.
    parts.append(weathered(mk.box("Cornice", (w + 0.9, depth + 0.6, 0.5), (0, 0.0, 13.45), mat=m["stone"], bevel=0.08),
                           WORN))
    gable = [(-w / 2 - 0.2, 13.7), (w / 2 + 0.2, 13.7), (0.0, 15.6)]
    parts.append(weathered(_profile_body("Pediment", gable, depth - 0.2, WINS_FACE + 0.1, m["stone"], bevel=0.06), WORN))
    # Fluted pilasters down its two edges.
    for sx in (-1, 1):
        x = sx * (w / 2 - 0.75)
        parts.append(weathered(mk.box("Pilaster", (1.3, 0.3, 11.6), (x, WINS_FACE - 0.12, 7.1), mat=m["stone"],
                                      bevel=0.05), WORN))
        for k in range(3):
            parts.append(mk.box("Flute", (0.14, 0.04, 10.6), (x + (k - 1) * 0.36, WINS_FACE - 0.28, 7.1), mat=m["void"]))
        parts.append(weathered(mk.box("Capital", (1.6, 0.5, 0.5), (x, WINS_FACE - 0.2, 13.05), mat=m["stone"],
                                      bevel=0.06), WORN))
        parts.append(weathered(mk.box("PilasterBase", (1.6, 0.5, 0.45), (x, WINS_FACE - 0.2, 1.17), mat=m["stone"],
                                      bevel=0.06), WORN))
    # The slate in its moulded frame.
    bx, bz, bw, bh = WINS_BOARD
    parts.append(mk.box("Slate", (bw, 0.12, bh), (bx, WINS_FACE - 0.04, bz), mat=m["slate"], bevel=0.02))
    parts += [weathered(p, WORN) for p in pk.frame("Frame", bw + 0.7, bh + 0.7, 0.35, 0.24, (bx, WINS_FACE - 0.1, bz),
                                                    m["stone"])]
    # The crown carved over a skull, between the frame's top and the cornice.
    cz = 12.0
    skull = pk.skull("Skull", (0.0, WINS_FACE - 0.14, cz - 0.2), 0.62, m["bone"], m["void"], segments=30, teeth=6)
    for p in skull:
        p.scale = (p.scale[0], p.scale[1] * 0.55, p.scale[2])
        weathered(p, BONE)
    parts += skull
    parts.append(weathered(mk.box("CrownBand", (1.5, 0.3, 0.26), (0.0, WINS_FACE - 0.18, cz + 0.42), mat=m["bone"],
                                  bevel=0.04), BONE))
    for k in range(5):
        x = -0.6 + k * 0.3
        tall = 0.5 if k in (0, 4) else (0.7 if k == 2 else 0.6)
        parts.append(weathered(mk.cylinder("CrownPoint", 0.11, tall, (x, WINS_FACE - 0.18, cz + 0.55 + tall / 2),
                                           mat=m["bone"], verts=4, radius2=0.0), BONE))
    for sx in (-1, 1):
        parts.append(weathered(mk.torus("Wreath", 0.95, 0.08, (sx * 1.35, WINS_FACE - 0.08, cz - 0.1), rot=(90, 0, 0),
                                        mat=m["stone"], major_segments=18, minor_segments=5), WORN))
    parts.append(snow_on(parts[:2] + [parts[3]], m["ash"], cell=0.25, depth=0.05, flat=0.75, name="AshCover"))
    return parts, []


@prop("TableauBase", pivot="bottom", material="Slate", collide=True, texture=512, set="Lobby", detail=True, normal=256)
def tableau_base():
    """A low round base of old stone the tableaux' figures stand on (and, smaller, the bell): a moulded rim over a
    plain foot, its top laid with wedge flags round a central round stone, a dark ring let in near the edge and worn
    through in places. Its top 0.7 over its foot, 13 across (plan.TABLEAU_R 6, and its foot's flare)."""
    m = _stones("Tab0")
    r, h = 6.0, 0.7
    rng = random.Random(52)
    parts = [weathered(mk.lathe("Foot", [(0.0, 0.0), (r + 0.6, 0.0), (r + 0.55, h * 0.36), (r + 0.3, h * 0.5),
                                         (r + 0.05, h * 0.6), (0.0, h * 0.6)], mat=m["dark"], segments=48)),
             weathered(mk.lathe("Rim", [(0.0, h * 0.58), (r + 0.06, h * 0.58), (r + 0.12, h * 0.78), (r, h - 0.08),
                                        (0.0, h - 0.08)], mat=m["stone"], segments=48), WORN)]
    # The flags: a ring of wedges round a central stone, each its own, a hair apart, a little out of level; their tops
    # at h, where the figures stand.
    parts.append(weathered(mk.cylinder("Centre", 1.6, 0.08, (0, 0, h - 0.04), mat=m["stone"], verts=24), WORN))
    for r0, r1, count in ((1.66, 3.9, 10), (3.96, r - 0.02, 16)):
        for k in range(count):
            a0 = math.tau * (k + 0.03) / count
            a1 = math.tau * (k + 0.97) / count
            pts = [(math.cos(a0) * r0, math.sin(a0) * r0), (math.cos(a1) * r0, math.sin(a1) * r0),
                   (math.cos(a1) * r1, math.sin(a1) * r1), (math.cos(a0) * r1, math.sin(a0) * r1)]
            thick = 0.08 + rng.uniform(-0.02, 0.01)
            flag = mk.extrude_shape("Flag", pts, thick, loc=(0, 0, h - 0.04 + rng.uniform(-0.012, 0.0)),
                                    mat=m["stone"], bevel=0.02)
            parts.append(weathered(flag, WORN))
    # The dark ring let in near the edge, worn through in places.
    for k in range(18):
        if rng.random() < 0.25:
            continue
        a0, a1 = math.tau * k / 18, math.tau * (k + 0.9) / 18
        pts = [(math.cos(a0) * (r - 1.3), math.sin(a0) * (r - 1.3)), (math.cos(a1) * (r - 1.3), math.sin(a1) * (r - 1.3)),
               (math.cos(a1) * (r - 0.65), math.sin(a1) * (r - 0.65)), (math.cos(a0) * (r - 0.65), math.sin(a0) * (r - 0.65))]
        parts.append(mk.extrude_shape("Inlay", pts, 0.03, loc=(0, 0, h - 0.005), mat=m["slate"]))
    return parts, []


@prop("CandleStone", pivot="bottom", material="Slate", collide=False, texture=512, set="Lobby", detail=True, normal=256)
def candle_stone():
    """One of the twelve candle stones round the plaza's middle (a candle burns on each for every player who is
    ready; the game stands it on the stone's top): a squat post of old stone narrowing at its waist, a dished top worn
    by years of candles, old wax run down its side and pooled at its foot. Its top 1.7 over its foot (plan.READY_H)."""
    m = _stones("Cst")
    wax = candle_wax("Cst")
    h = 1.7
    parts = [weathered(mk.lathe("Post", [(0.0, 0.0), (0.98, 0.0), (0.9, 0.12), (0.8, 0.32), (0.7, 0.9), (0.72, h - 0.38),
                                         (0.86, h - 0.24), (0.9, h - 0.12), (0.84, h - 0.02), (0.55, h), (0.0, h - 0.05)],
                                 mat=m["stone"], segments=20))]
    # Old wax: a pool on the top, a few runs down the side ending in beads, a puddle at the foot.
    parts.append(mk.cylinder("TopWax", 0.5, 0.05, (0, 0, h - 0.04), mat=wax, verts=16))
    rng = random.Random(9)
    for k in range(4):
        a = rng.uniform(0, math.tau)
        length = rng.uniform(0.35, 0.9)
        top = (math.cos(a) * 0.86, math.sin(a) * 0.86, h - 0.08)
        bottom = (math.cos(a) * 0.74, math.sin(a) * 0.74, h - 0.08 - length)
        parts.append(mk.tube("Run", top, bottom, 0.05, 0.065, mat=wax, verts=6))
        parts.append(mk.sphere("Bead", 0.08, bottom, scale=(1.0, 1.0, 1.3), mat=wax, segments=8, rings=5))
    puddle = mk.cylinder("Puddle", 0.62, 0.04, (0.55, 0.3, 0.02), mat=wax, verts=14)
    puddle.scale = (1.0, 0.7, 1.0)
    parts.append(puddle)
    return parts, []


# The name duel's stones (landmarks.duel places them, the game writes on their slates: LobbyGames DUEL_SLATE_Y and
# DUEL_SLATE_SLOPE are this slope's middle and pitch).
DUEL_SLOPE = (2.9, 0.8 / 1.7)  # the slope's height over the stone's middle, and how steeply it rises toward the front


def _slope_z(y):
    """The slope's height over the point y (front is -y, where the stone looks at the other one)."""
    return DUEL_SLOPE[0] - DUEL_SLOPE[1] * y


@prop("DuelStone", pivot="bottom", material="Slate", collide=True, texture=512, set="Lobby", detail=True, normal=256)
def duel_stone():
    """One of the name duel's two stones under the carcass's ribs: a waist-high lectern of old stone, its top sloping
    up toward the other stone with a slate of black stone let into it (the duellist stands behind, the low side, and
    writes; the game shows the writing on the slate), a moulded base, sunk panels down its sides, a bone ornament on
    its front."""
    m = _stones("Duel")
    w, d = 3.4, 1.7
    parts = [weathered(mk.box("Base", (w + 1.0, d + 1.0, 0.5), (0, 0, 0.25), mat=m["dark"], bevel=0.07))]
    side = [(-d / 2, 0.5), (d / 2, 0.5), (d / 2, _slope_z(d / 2)), (-d / 2, _slope_z(-d / 2))]
    body = mk.extrude_shape("Body", side, w, loc=(0, 0, 0), rot=(90, 0, 90), mat=m["stone"], bevel=0.05)
    parts.append(weathered(body))
    # A moulded band round it under the slope's low edge.
    parts.append(weathered(mk.box("Band", (w + 0.16, d + 0.16, 0.18), (0, 0, 2.18), mat=m["stone"], bevel=0.04), WORN))
    # Sunk panels down its two sides, and on its front a bone ornament: two crossed long bones.
    for sx in (-1, 1):
        x = sx * (w / 2 + 0.02)
        for name, size, at in (("PanelTop", (0.06, 1.1, 0.1), (x, 0, 1.85)), ("PanelFoot", (0.06, 1.1, 0.1), (x, 0, 0.75)),
                               ("PanelSide", (0.06, 0.1, 1.0), (x, -0.5, 1.3)), ("PanelSide", (0.06, 0.1, 1.0), (x, 0.5, 1.3))):
            parts.append(weathered(mk.box(name, size, at, mat=m["stone"], bevel=0.02), WORN))
    for k, a in enumerate((32, -32)):
        bone = mk.cylinder(f"Bone{k}", 0.07, 1.3, (0, -d / 2 - 0.06, 1.35), rot=(0, a, 0), mat=m["bone"], verts=8)
        parts.append(weathered(bone, BONE))
        for e in (-1, 1):
            r = math.radians(a)
            parts.append(mk.sphere(f"Knob{k}", 0.1, (e * 0.62 * math.sin(r), -d / 2 - 0.06, 1.35 + e * 0.62 * math.cos(r)),
                                   mat=m["bone"], segments=8, rings=5))
    # The slate on the slope, lifted a hair along its normal, in a thin frame.
    pitch = math.atan(DUEL_SLOPE[1])
    margin = 0.3
    length = math.hypot(d, d * DUEL_SLOPE[1]) - 2 * margin
    nz, ny = math.cos(pitch), -math.sin(pitch)  # the slope's normal (up and toward the front)
    centre = (0.0, ny * 0.03, DUEL_SLOPE[0] + nz * 0.03)
    slate = mk.box("Slate", (w - 2 * margin, length, 0.05), centre, rot=(math.degrees(pitch), 0, 0), mat=m["slate"])
    parts.append(slate)
    frame = mk.box("SlateFrame", (w - 2 * margin + 0.22, length + 0.22, 0.04), (0.0, ny * 0.012, DUEL_SLOPE[0] + nz * 0.012),
                   rot=(math.degrees(pitch), 0, 0), mat=m["dark"], bevel=0.015)
    parts.append(weathered(frame, WORN))
    return parts, []


# The Academy's gate (2026-11-07, the user: "fix the academy entrance thing": its name hung on a bare black board under
# the cave's lintel with nothing holding it). Its measures, for landmarks.grotto (which stands it in the mouth and lays
# its solids): the clear way between the posts, each post's size, the gate's top (under the shelf of rock over the
# mouth), and the lintel's height and depth.
GATE_OPEN = 16.0  # plan.GROTTO_MOUTH_W
GATE_POST = (2.3, 2.7)  # a post's width (x) and depth (y)
GATE_TOP = 12.4
GATE_LINTEL = (2.0, 2.9)  # its height (z) and depth (y)
GATE_CAP = 0.45  # the capitals' height, under the lintel
GATE_PLINTH = 0.7
GATE_NAME_Z = GATE_TOP - 0.32 - GATE_LINTEL[0] / 2  # the middle of the name's slate on the lintel's face
@prop("AcademyGate", pivot="bottom", material="Slate", collide=False, texture=1024, set="Lobby", anchor=(0, 0),
      detail=True, normal=512)
def academy_gate():
    """The gate of the Academy in the grotto's mouth: two posts of the Academy's dark old stone on stepped plinths,
    fluted down their faces, a skull carved under each capital, and across them a heavy lintel carrying the shelf of
    rock over the mouth, a moulded band at its top and foot, a slate of black stone let into its face, a small skull at
    each of its ends. The name is the game's to write on the slate (Lobby.luau, at the anchor academyGate), like the
    steles' names: cut in relief it baked grey on grey and could not be read in the cave's dark. Ash on every ledge.
    Its front faces -Y (out of the cave); the way through is GATE_OPEN wide and stands on z = 0. Solid where a body meets
    it (landmarks.academy_gate lays its blocks: collide is off so that no stand-in box shuts the mouth before the
    import lands)."""
    m = _stones("Gate")
    pw, pd = GATE_POST
    lh, ld = GATE_LINTEL
    px = GATE_OPEN / 2 + pw / 2
    cap_top = GATE_TOP - lh
    shaft_top = cap_top - GATE_CAP
    parts = []
    for side in (-1, 1):
        x = side * px
        parts.append(weathered(mk.box("PlinthLow", (pw + 1.0, pd + 1.0, 0.4), (x, 0.0, 0.2), mat=m["dark"], bevel=0.08)))
        parts.append(weathered(mk.box("PlinthHigh", (pw + 0.5, pd + 0.5, GATE_PLINTH - 0.4),
                                      (x, 0.0, 0.4 + (GATE_PLINTH - 0.4) / 2), mat=m["dark"], bevel=0.07)))
        shaft = mk.box("Shaft", (pw, pd, shaft_top - GATE_PLINTH), (x, 0.0, (GATE_PLINTH + shaft_top) / 2),
                       mat=m["stone"], bevel=0.1)
        parts.append(weathered(shaft))
        # Five shallow flutes down the face, stopping short of the skull and the band at the foot.
        for k in range(5):
            fx = x + (k - 2) * 0.38
            parts.append(mk.box("Flute", (0.09, 0.04, shaft_top - GATE_PLINTH - 2.9),
                                (fx, -pd / 2 - 0.004, (GATE_PLINTH + shaft_top) / 2 - 0.55), mat=m["dark"]))
        # A moulded band near the foot, and the capital under the lintel.
        parts.append(weathered(mk.box("Band", (pw + 0.18, pd + 0.18, 0.22), (x, 0.0, GATE_PLINTH + 0.55), mat=m["stone"],
                                      bevel=0.04), WORN))
        parts.append(weathered(mk.box("Capital", (pw + 0.55, pd + 0.45, GATE_CAP), (x, 0.0, shaft_top + GATE_CAP / 2),
                                      mat=m["stone"], bevel=0.07), WORN))
        # A skull under each capital, half sunk in the stone.
        skull = pk.skull("Skull", (x, -pd / 2 - 0.14, shaft_top - 1.0), 0.52, m["bone"], m["void"], segments=22, teeth=5)
        for p in skull:
            p.scale = (p.scale[0], p.scale[1] * 0.55, p.scale[2])
            weathered(p, BONE)
        parts += skull
    # The lintel across the posts, a band at its foot and a cornice on top, and the slate with the name.
    span = GATE_OPEN + 2 * pw + 1.4
    parts.append(weathered(mk.box("Lintel", (span, ld, lh - 0.32), (0.0, 0.0, cap_top + (lh - 0.32) / 2), mat=m["stone"],
                                  bevel=0.1)))
    parts.append(weathered(mk.box("LintelFoot", (span - 0.3, ld + 0.16, 0.2), (0.0, 0.0, cap_top + 0.1), mat=m["dark"],
                                  bevel=0.04), WORN))
    parts.append(weathered(mk.box("Cornice", (span + 0.6, ld + 0.5, 0.32), (0.0, 0.0, GATE_TOP - 0.16), mat=m["stone"],
                                  bevel=0.07), WORN))
    sw, sh = 11.2, 1.3
    face = -ld / 2
    parts.append(mk.box("Slate", (sw, 0.12, sh), (0.0, face - 0.04, GATE_NAME_Z), mat=m["slate"], bevel=0.02))
    parts += [weathered(p, WORN) for p in pk.frame("SlateFrame", sw + 0.34, sh + 0.34, 0.17, 0.18,
                                                    (0.0, face - 0.06, GATE_NAME_Z), m["dark"])]
    # Two small skulls closing the slate's ends.
    for side in (-1, 1):
        skull = pk.skull("EndSkull", (side * (sw / 2 + 0.72), face - 0.12, GATE_NAME_Z), 0.34, m["bone"], m["void"],
                         segments=16, teeth=4)
        for p in skull:
            p.scale = (p.scale[0], p.scale[1] * 0.5, p.scale[2])
            weathered(p, BONE)
        parts += skull
    # Ash on the plinths, the capitals and the cornice.
    ledges = [p for p in parts if p.name.startswith(("PlinthLow", "PlinthHigh", "Capital", "Cornice"))]
    parts.append(snow_on(ledges, m["ash"], cell=0.32, depth=0.05, flat=0.75, name="AshCover"))
    return parts, []
