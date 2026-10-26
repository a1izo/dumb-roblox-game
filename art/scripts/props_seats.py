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
        face = BACK_Y + 0.3 - 0.275 * math.cos(math.radians(8)) + (z - SEAT_TOP - 1.55) * math.sin(math.radians(8))
        parts.append(mk.box("BackCrack", (2.4, 0.02, 0.03), (0, face - 0.006, z), rot=(-8, 0, 0), mat=crack))
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
            parts.append(mk.box("Slat", (w - 0.1, 0.12, slat_h), (0, SEAT_Y + sy * (d / 2 - 0.075), z), mat=wood,
                                bevel=0.02))
        for sx in (-1, 1):
            parts.append(mk.box("Slat", (0.12, d - 0.1, slat_h), (sx * (w / 2 - 0.075), SEAT_Y, z), mat=wood,
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


@prop("ChairBone", pivot="bottom", material="SmoothPlastic", collide=True, texture=1024, ao=0.55, exact=True)
def chair_bone():
    """The Bone Chair: a tall chair grown out of one skeleton, every bone fused into the next. A frame of bone round
    a pale pelvic slab for the seat, four long-bone legs bulging at the knee and splaying into clawed feet, arms that
    run back into the lowest ribs, and a spine of knuckled vertebrae up the back, its ribs sweeping out and round (low
    and wide behind the body, curling forward round the head higher up), ending in a horned skull."""
    from props_world import skin_body

    bone = mk.noisy("Cbn_Bone", srgb(178, 168, 142), srgb(226, 218, 196), scale=16, roughness=0.55,
                    stretch=(1, 1, 0.45))
    void = mk.flat("Cbn_Void", srgb(14, 12, 12), 0.9)
    joints, bones = [], []

    def joint(p, r):
        joints.append((p[0], p[1], p[2], r, r))
        return len(joints) - 1

    def chain(start, points, end=None):
        """Joints through `points` [((x, y, z), r)], each linked to the one before, from joint `start` (or None)
        and on into joint `end` when given: the last new joint's index."""
        last = start
        for p, r in points:
            k = joint(p, r)
            if last is not None:
                bones.append((last, k))
            last = k
        if end is not None:
            bones.append((last, end))
        return last

    def shaft(a, b, r, start, end=None, knob=1.55):
        """A long bone's length from a to b (`start` the joint at a): the neck narrowing into a thin shaft and
        widening again into a knob at b, or on into joint `end`."""
        pts = []
        for t, f in ((0.12, 1.12), (0.26, 0.86), (0.5, 0.76), (0.74, 0.86), (0.88, 1.12), (1.0, knob)):
            if t == 1.0 and end is not None:
                break
            pts.append(((a[0] + (b[0] - a[0]) * t, a[1] + (b[1] - a[1]) * t, a[2] + (b[2] - a[2]) * t), r * f))
        return chain(start, pts, end)

    # The seat's frame: a bone round the slab's edge, a knuckle at each corner where a leg comes up into it.
    zr = SEAT_TOP - 0.24
    fy, by = SEAT_Y - 1.24, SEAT_Y + 1.2
    corners = {(sx, sy): joint((sx * 1.36, fy if sy < 0 else by, zr), 0.27) for sx in (-1, 1) for sy in (-1, 1)}
    sacrum = joint((0, by + 0.02, zr), 0.3)  # where the spine comes down into the frame
    front_mid = joint((0, fy - 0.06, zr - 0.02), 0.16)
    for sx in (-1, 1):
        shaft((sx * 1.36, fy, zr), (sx * 1.36, by, zr), 0.15, corners[(sx, -1)], end=corners[(sx, 1)])
        chain(corners[(sx, -1)], [((sx * 0.7, fy - 0.03, zr - 0.01), 0.13)], end=front_mid)
        chain(corners[(sx, 1)], [((sx * 0.7, by + 0.01, zr), 0.14)], end=sacrum)

    # The legs: down from each corner, bulging at the knee, a clawed foot spread on the floor.
    for (sx, sy), top in corners.items():
        x0, y0 = sx * 1.36, (fy if sy < 0 else by)
        knee = chain(top, [((x0 + sx * 0.03, y0 + sy * 0.03, zr - 0.5), 0.17),
                           ((x0 + sx * 0.06, y0 + sy * 0.05, 1.28), 0.13),
                           ((x0 + sx * 0.08, y0 + sy * 0.07, 1.02), 0.21)])
        fx, fyy = x0 + sx * 0.1, y0 + sy * 0.1
        foot = chain(knee, [((x0 + sx * 0.09, y0 + sy * 0.08, 0.78), 0.13),
                            ((x0 + sx * 0.1, y0 + sy * 0.09, 0.42), 0.12),
                            ((fx, fyy, 0.2), 0.23)])
        for spread in (-0.6, 0.0, 0.6):  # three claws, outward from the chair
            a = math.atan2(sy, sx) + spread
            c, s = math.cos(a), math.sin(a)
            chain(foot, [((fx + c * 0.2, fyy + s * 0.2, 0.12), 0.09),
                         ((fx + c * 0.34, fyy + s * 0.34, 0.07), 0.06),
                         ((fx + c * 0.44, fyy + s * 0.44, 0.035), 0.022)])

    # The spine: vertebrae up the back (knuckles, narrow discs between), leaning back a little as it rises, each
    # with its spike out behind.
    count = 10
    vert = []
    last = sacrum
    for k in range(count):
        t = k / (count - 1)
        z = SEAT_TOP + 0.25 + t * 4.05
        y = BACK_Y + 0.3 + 0.25 * t ** 1.5
        r = 0.27 - 0.06 * t
        if k:
            last = chain(last, [((0, y - 0.01, z - 0.225), r * 0.62)])
        last = chain(last, [((0, y, z), r)])
        vert.append((last, y, z, r))
        chain(last, [((0, y + r + 0.12, z - 0.1), r * 0.45), ((0, y + r + 0.32, z - 0.22), 0.03)])

    # Ribs: out of the vertebrae either side and round. The three low pairs stay behind the body (their tips at the
    # back's face, clear of a sitter's arms), the lowest pair's tips where the arms begin; the upper three curl
    # forward round where the head comes. (vertebra: half-span, the tip's y, how far it drops)
    ribs = {2: (1.5, 0.95, 0.3), 3: (1.52, 0.97, 0.32), 4: (1.5, 0.99, 0.34), 5: (1.36, 0.52, 0.34),
            6: (1.18, 0.34, 0.3), 7: (0.98, 0.36, 0.26)}
    arm_back = {}
    theta_max = math.radians(100)
    for k, (rx, tip_y, drop) in ribs.items():
        root, y_v, z_v, r_v = vert[k]
        reach = (y_v - tip_y) / (1 - math.cos(theta_max))
        for sx in (-1, 1):
            pts = []
            for i in range(1, 8):
                u = i / 7
                th = theta_max * u
                x = sx * (r_v * 0.8 + (rx - r_v * 0.8) * math.sin(th))
                y = y_v + 0.06 * math.sin(th * 1.8) - reach * (1 - math.cos(th))
                pts.append(((x, y, z_v - drop * u ** 1.3), (0.17 if k < 5 else 0.15) - 0.1 * u))
            if k == 2:
                pts[-1] = (pts[-1][0], 0.17)  # the lowest ribs end in a knuckle: the arms' back ends
            tip = chain(root, pts)
            if k == 2:
                arm_back[sx] = tip

    # The arms: from the lowest ribs' knuckles forward to a knuckle over the front corner, a post down from it into
    # the frame.
    for sx in (-1, 1):
        back = joints[arm_back[sx]][:3]
        front = (sx * 1.46, SEAT_Y - 1.1, SEAT_TOP + 0.86)
        knuckle = shaft(back, front, 0.14, arm_back[sx], knob=1.6)
        shaft(front, (sx * 1.36, fy, zr), 0.11, knuckle, end=corners[(sx, -1)])

    # The top of the spine: the atlas up into the skull, and two horns curving out of its temples.
    top, y_t, z_t, _ = vert[-1]
    sk_y, sk_z, sk_r = y_t - 0.12, z_t + 0.62, 0.44
    atlas = chain(top, [((0, y_t - 0.04, z_t + 0.24), 0.17), ((0, sk_y + 0.05, sk_z - 0.2), 0.2)])
    for sx in (-1, 1):
        chain(atlas, [((sx * 0.22, sk_y + 0.05, sk_z + 0.15), 0.16),
                      ((sx * 0.5, sk_y + 0.12, sk_z + 0.3), 0.17),
                      ((sx * 0.82, sk_y + 0.2, sk_z + 0.55), 0.14),
                      ((sx * 1.0, sk_y + 0.24, sk_z + 0.92), 0.1),
                      ((sx * 0.96, sk_y + 0.2, sk_z + 1.28), 0.065),
                      ((sx * 0.8, sk_y + 0.1, sk_z + 1.54), 0.02)])

    # (grown smooth at two levels, then thinned: rounder than one level at the same count)
    skeleton = skin_body("Skeleton", bone, joints, bones, levels=2)
    skeleton.modifiers.new("Decimate", "DECIMATE").ratio = 0.16
    parts = [skeleton]
    parts += pk.skull("Skull", (0, sk_y, sk_z), sk_r, bone, void, segments=40)  # (the chair under 20,000 triangles)

    # The seat: a slab of pale bone set in the frame, its outline a broad pelvic plate (a notch at the back where
    # the spine comes down), softened and pitted.
    outline = []
    for i in range(40):
        a = 2 * math.pi * i / 40
        c, s = math.cos(a), math.sin(a)
        x = 1.3 * math.copysign(abs(c) ** 0.55, c)
        y = 1.2 * math.copysign(abs(s) ** 0.55, s)
        if s > 0.85:
            y -= 0.18 * (s - 0.85) / 0.15
        outline.append((x, SEAT_Y + y))
    slab = mk.extrude_shape("Seat", outline, 0.3, loc=(0, 0, SEAT_TOP - 0.15), mat=bone, bevel=0.1)
    mk.subdivide(slab, 1)
    mk.displace_noise(slab, strength=0.035, scale=0.35, name="CbnPits")
    parts.append(slab)
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
