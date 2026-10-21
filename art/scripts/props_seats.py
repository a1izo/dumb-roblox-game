"""The chair skins of the shop's Seats (Core set; shop overhaul, 2026-10-21): what a player's own place at the war
table becomes, for everyone to see, in place of the war chair there. Each shares the war chair's seat as the war
room places it (WarChair scaled 1.3: art/scripts/maps/venues/meeting/furnish.py), so every seated pose
(art/scripts/emotes/seats.py) sits in every chair the same way:

    the cushion's top 2.56 high, its middle at y = -0.065; the back's face about 0.84 behind the middle (y = +0.84)
    at seat height; the arms at least 2.26 apart inside (an R6 body is 2 across at the hips, 4 with its arms)

Props face -Y and stand on z = 0; about 3.2 studs across like the scaled war chair, so each replaces it in place."""

import math

import modelkit as mk
import propkit as pk
from common import srgb
from props import prop

SEAT_TOP = 2.56
SEAT_Y = -0.065
BACK_Y = 0.84


def _castor_base(prefix, metal, dark, height):
    """A five-star base on castors with its column up to `height` (an office chair's)."""
    parts = [mk.cylinder(prefix + "Hub", 0.36, 0.3, (0, SEAT_Y, 0.5), mat=metal, verts=12),
             mk.cylinder(prefix + "Column", 0.15, height - 0.6, (0, SEAT_Y, 0.6 + (height - 0.6) / 2), mat=metal,
                         verts=10)]
    for k in range(5):
        a = 2 * math.pi * k / 5 + math.pi / 2
        c, s = math.cos(a), math.sin(a)
        parts.append(mk.tube(prefix + "Leg", (c * 0.26, SEAT_Y + s * 0.26, 0.5), (c * 1.4, SEAT_Y + s * 1.4, 0.36),
                             0.11, 0.08, mat=metal, verts=6))
        parts.append(mk.sphere(prefix + "Castor", 0.19, (c * 1.42, SEAT_Y + s * 1.42, 0.19), scale=(1, 0.7, 1),
                               mat=dark, segments=8, rings=6))
    return parts


@prop("ChairOffice", pivot="bottom", material="Leather", collide=True, texture=512)
def chair_office():
    """The Bureau Office Chair: a worn swivel chair from the night shift, its grey-green leather cracked along the
    seams, a low square back, padded arms, and a coffee ring dried on the right arm."""
    hide = mk.noisy("Cof_Leather", srgb(52, 58, 54), srgb(86, 94, 88), scale=22, roughness=0.62)
    crack = mk.flat("Cof_Crack", srgb(26, 28, 27), 0.8)
    metal = pk.metal("Cof_Steel", (70, 72, 76), (128, 132, 138), rough=0.35, metallic=0.9, scale=26)
    dark = mk.flat("Cof_Dark", srgb(20, 20, 22), 0.5)
    ring = mk.flat("Cof_Coffee", srgb(58, 36, 22), 0.7)
    parts = _castor_base("Cof", metal, dark, SEAT_TOP - 0.62)
    parts += [pk.rounded("Seat", (2.9, 2.7, 0.62), (0, SEAT_Y, SEAT_TOP - 0.31), hide, r=0.2),
              mk.box("SeatPan", (2.5, 2.3, 0.18), (0, SEAT_Y, SEAT_TOP - 0.7), mat=dark, bevel=0.04)]
    # the low back, leaning back a little, on a steel spine from under the seat
    back = pk.rounded("Back", (2.8, 0.55, 2.3), (0, BACK_Y + 0.3, SEAT_TOP + 1.55), hide, r=0.22, rot=(-8, 0, 0))
    parts += [back, mk.tube("Spine", (0, 0.6, SEAT_TOP - 0.5), (0, BACK_Y + 0.42, SEAT_TOP + 0.6), 0.1, mat=metal,
                            verts=8)]
    # the cracks along the seat's and the back's seams
    for x in (-0.7, 0.0, 0.7):
        parts.append(mk.box("SeatCrack", (0.03, 2.2, 0.02), (x, SEAT_Y, SEAT_TOP + 0.005), mat=crack))
    for z in (SEAT_TOP + 0.9, SEAT_TOP + 1.6, SEAT_TOP + 2.3):
        parts.append(mk.box("BackCrack", (2.4, 0.02, 0.03), (0, BACK_Y + 0.02, z), rot=(-8, 0, 0), mat=crack))
    for sx in (-1, 1):
        x = sx * 1.48
        parts += [mk.tube("ArmPost", (x, 0.35, SEAT_TOP - 0.3), (x, 0.2, SEAT_TOP + 0.8), 0.07, mat=metal, verts=6),
                  mk.tube("ArmPost", (x, -0.95, SEAT_TOP - 0.3), (x, -0.85, SEAT_TOP + 0.8), 0.07, mat=metal, verts=6),
                  pk.rounded("ArmPad", (0.42, 1.7, 0.24), (x, -0.35, SEAT_TOP + 0.9), hide, r=0.1)]
    parts.append(mk.torus("CoffeeRing", 0.15, 0.022, (1.48, -0.7, SEAT_TOP + 1.025), mat=ring, major_segments=20,
                          minor_segments=4))
    return parts, []


@prop("ChairCrate", pivot="bottom", material="Wood", collide=True, texture=512)
def chair_crate():
    """The Death God's Crate: an old slatted apple crate turned over for a seat, the wood gone grey, a faded apple
    stencilled on its front, and three claw marks raked down its right side."""
    wood = mk.wood("Ccr_Wood", srgb(120, 112, 100), srgb(70, 64, 58), scale=5.0)
    post = mk.wood("Ccr_Post", srgb(96, 88, 78), srgb(54, 50, 44), scale=4.0)
    gouge = mk.flat("Ccr_Gouge", srgb(30, 26, 22), 0.9)
    stencil = mk.flat("Ccr_Stencil", srgb(118, 40, 38), 0.85)
    w, d = 3.0, 2.8
    parts = []
    for sx in (-1, 1):
        for sy in (-1, 1):
            parts.append(mk.box("Post", (0.22, 0.22, SEAT_TOP), (sx * (w / 2 - 0.11), SEAT_Y + sy * (d / 2 - 0.11),
                                                                 SEAT_TOP / 2), mat=post, bevel=0.03))
    slat_h, gap = 0.62, 0.2
    for k in range(3):
        z = 0.2 + k * (slat_h + gap) + slat_h / 2
        for sy in (-1, 1):
            parts.append(mk.box("Slat", (w - 0.1, 0.12, slat_h), (0, SEAT_Y + sy * (d / 2 - 0.06), z), mat=wood,
                                bevel=0.02))
        for sx in (-1, 1):
            parts.append(mk.box("Slat", (0.12, d - 0.1, slat_h), (sx * (w / 2 - 0.06), SEAT_Y, z), mat=wood,
                                bevel=0.02))
    for k in range(5):  # the bottom of the crate, upside down: the seat
        y = SEAT_Y - d / 2 + 0.3 + k * (d - 0.6) / 4
        parts.append(mk.box("Top", (w, 0.5, 0.14), (0, y, SEAT_TOP - 0.07), mat=wood, bevel=0.02))
    # a faded apple on the front, and three claw marks down the right side
    parts += [mk.cylinder("Apple", 0.38, 0.02, (0.0, SEAT_Y - d / 2 - 0.005, 1.25), rot=(90, 0, 0), mat=stencil,
                          verts=20),
              mk.box("AppleStem", (0.06, 0.02, 0.2), (0.0, SEAT_Y - d / 2 - 0.006, 1.7), mat=stencil)]
    for k in range(3):
        parts.append(mk.box("Claw", (0.02, 0.09, 1.7), (w / 2 + 0.005, SEAT_Y - 0.55 + k * 0.32, 1.35),
                            rot=(22, 0, 0), mat=gouge))
    return parts, []


@prop("ChairBone", pivot="bottom", material="SmoothPlastic", collide=True, texture=512)
def chair_bone():
    """The Bone Chair: a tall chair of fused bone, the seat a slab of pale bone on four long-bone legs, the arms
    two long bones, and the back a ribcage curving round a spine that rises to a crown of short horns."""
    bone = mk.noisy("Cbn_Bone", srgb(196, 186, 162), srgb(232, 224, 204), scale=14, roughness=0.55)
    old = mk.noisy("Cbn_Old", srgb(150, 140, 118), srgb(188, 178, 154), scale=18, roughness=0.6)
    parts = [pk.rounded("Seat", (3.0, 2.7, 0.42), (0, SEAT_Y, SEAT_TOP - 0.21), bone, r=0.16)]

    def long_bone(name, a, b, r):
        return [mk.tube(name, a, b, r, mat=bone, verts=8), mk.sphere(name + "Knob", r * 1.6, a, mat=old, segments=10,
                                                                     rings=8),
                mk.sphere(name + "Knob", r * 1.6, b, mat=old, segments=10, rings=8)]

    for sx in (-1, 1):
        for sy in (-1, 1):
            parts += long_bone("Leg", (sx * 1.25, SEAT_Y + sy * 1.05, 0.15), (sx * 1.2, SEAT_Y + sy * 1.0,
                                                                              SEAT_TOP - 0.42), 0.13)
        parts += long_bone("Arm", (sx * 1.5, 0.75, SEAT_TOP + 0.95), (sx * 1.5, -1.15, SEAT_TOP + 0.85), 0.12)
        parts += long_bone("ArmPost", (sx * 1.45, -1.1, SEAT_TOP - 0.1), (sx * 1.5, -1.12, SEAT_TOP + 0.75), 0.09)
    # the spine up the middle of the back, a vertebra at a time
    top = SEAT_TOP + 4.4
    for k in range(10):
        z = SEAT_TOP + 0.3 + k * (top - SEAT_TOP - 0.3) / 9
        y = BACK_Y + 0.35 + 0.06 * k
        parts.append(mk.cylinder("Vertebra", 0.24 - 0.008 * k, 0.26, (0, y, z), mat=bone if k % 2 else old, verts=10))
    parts.append(mk.tube("Cord", (0, BACK_Y + 0.35, SEAT_TOP + 0.2), (0, BACK_Y + 0.89, top + 0.1), 0.11, mat=old,
                         verts=8))
    # ribs: four broad pairs, each sweeping out from the spine, round the back's edge and forward beside the body,
    # so the back reads as a cage (thick near the spine, thinning to the tips)
    for k in range(4):
        z = SEAT_TOP + 1.0 + k * 0.85
        y0 = BACK_Y + 0.45 + 0.06 * (k + 1)
        span = 1.55 - 0.1 * k
        for sx in (-1, 1):
            pts = []
            for i in range(7):
                a = math.pi / 2 * i / 6  # from straight out of the spine to straight forward
                pts.append((sx * span * math.sin(a), y0 - (y0 - BACK_Y + 0.25) * (1 - math.cos(a)) * 0.95,
                            z - 0.18 * i / 6))
            for t in range(6):
                r0 = 0.17 - 0.016 * t
                parts.append(mk.tube("Rib", pts[t], pts[t + 1], r0, r0 - 0.016, mat=bone, verts=8))
    for sx in (-1, 1):  # the crown: two short curved horns either side of the spine's top
        parts += [mk.tube("Horn", (sx * 0.2, BACK_Y + 0.95, top), (sx * 0.65, BACK_Y + 0.85, top + 0.55), 0.22, 0.14,
                          mat=old, verts=10),
                  mk.tube("Horn", (sx * 0.65, BACK_Y + 0.85, top + 0.55), (sx * 0.8, BACK_Y + 0.6, top + 1.05), 0.14,
                          0.03, mat=old, verts=10)]
    return parts, []


@prop("ChairThrone", pivot="bottom", material="Slate", collide=True, texture=512)
def chair_throne():
    """Diavolo's Throne: a high throne of black stone, its back rising to a point with a skull carved at the crest,
    solid arms ending in scrolls, an oxblood velvet cushion, and a thin crimson line cut round the back's edge."""
    stone = mk.noisy("Cth_Stone", srgb(16, 15, 17), srgb(38, 36, 40), scale=10, roughness=0.32)
    carved = mk.noisy("Cth_Carved", srgb(46, 44, 48), srgb(78, 76, 80), scale=16, roughness=0.5)
    velvet = mk.noisy("Cth_Velvet", srgb(52, 10, 16), srgb(86, 18, 26), scale=30, roughness=0.85)
    line = mk.flat("Cth_Line", srgb(120, 14, 26), 0.4)
    hollow = mk.flat("Cth_Hollow", srgb(4, 4, 5), 0.9)
    parts = [mk.box("Plinth", (3.7, 3.4, 0.35), (0, SEAT_Y + 0.1, 0.175), mat=stone, bevel=0.06),
             mk.box("Seat", (3.0, 2.8, SEAT_TOP - 0.6), (0, SEAT_Y, 0.35 + (SEAT_TOP - 0.95) / 2), mat=stone,
                    bevel=0.05),
             pk.rounded("Cushion", (2.4, 2.6, 0.28), (0, SEAT_Y - 0.02, SEAT_TOP - 0.14), velvet, r=0.1)]
    # the back: a tall slab rising to a point (an extruded pentagon), the crimson line just inside its edge
    w, h0, h1, apex = 3.0, SEAT_TOP - 0.6, SEAT_TOP + 5.0, SEAT_TOP + 6.0
    outline = [(-w / 2, h0), (w / 2, h0), (w / 2, h1), (0.0, apex), (-w / 2, h1)]
    back = mk.extrude_shape("Back", outline, 0.6, loc=(0, BACK_Y + 0.3, 0), rot=(90, 0, 0), mat=stone, bevel=0.05)
    parts.append(back)
    inset = 0.18
    edge = [(-w / 2 + inset, h0 + 0.6), (w / 2 - inset, h0 + 0.6), (w / 2 - inset, h1 - 0.05), (0.0, apex - 0.3),
            (-w / 2 + inset, h1 - 0.05), (-w / 2 + inset, h0 + 0.6)]
    for a, b in zip(edge, edge[1:]):
        parts.append(mk.tube("Line", (a[0], BACK_Y - 0.005, a[1]), (b[0], BACK_Y - 0.005, b[1]), 0.03, mat=line, verts=4))
    # solid arms ending in scrolls
    for sx in (-1, 1):
        parts += [mk.box("Arm", (0.42, 2.6, 0.95), (sx * 1.5, SEAT_Y + 0.05, SEAT_TOP + 0.2), mat=stone, bevel=0.06),
                  mk.cylinder("Scroll", 0.36, 0.46, (sx * 1.5, SEAT_Y - 1.3, SEAT_TOP + 0.5), rot=(0, 90, 0), mat=carved,
                              verts=16)]
    # the skull at the crest, carved out of the back's face
    cz = apex - 1.25
    parts += [mk.sphere("Skull", 0.58, (0, BACK_Y - 0.15, cz), scale=(1, 0.75, 1), mat=carved, segments=16, rings=10),
              mk.box("Jaw", (0.72, 0.3, 0.36), (0, BACK_Y - 0.32, cz - 0.55), mat=carved, bevel=0.05)]
    for sx in (-1, 1):
        parts.append(mk.sphere("Socket", 0.15, (sx * 0.22, BACK_Y - 0.55, cz + 0.05), scale=(1, 0.6, 1.1), mat=hollow,
                               segments=10, rings=6))
    parts.append(mk.box("Nose", (0.1, 0.1, 0.18), (0, BACK_Y - 0.59, cz - 0.2), mat=hollow))
    return parts, []
