"""The Grey Realm's fire (set "Lobby"): the bone braziers burning the realm's pale cold fire round the plaza, the
plateaus and the monolith, and the lantern posts along the ways people walk. Remade 2026-11-03 to the semi-real
standard: forged and riveted iron, bound bones, a real lantern with smoked panes; each keeps the footprint, height,
light and flame of what it replaced (the venue places them where they stood). They face -Y and stand on z = 0."""

import math
import random

import modelkit as mk
import propkit as pk
from common import srgb
from props import prop
from props_academy import weathered
from props_lobby import PALE_FIRE, bone_mat, candle, candle_wax, long_bone

FORGED = {"sub": 1, "disp": [("cells", 0.012, 0.16), ("grain", 0.004, 0.04)]}  # hammered iron
BARK = {"sub": 1, "disp": [("wrinkles", 0.03, 0.3), ("grain", 0.008, 0.06)]}


def _iron(prefix):
    return pk.metal(prefix + "_Iron", (22, 22, 24), (52, 49, 47), rough=0.62, metallic=0.7)


def _rust(prefix):
    return pk.metal(prefix + "Rust_Iron", (40, 30, 26), (70, 56, 46), rough=0.85, metallic=0.4)


@prop("BoneBrazier", pivot="bottom", material="Metal", collide=True, texture=1024, set="Lobby", detail=True, normal=512,
      lights=[dict(at=(0, 0, 5.4), kind="point", color=PALE_FIRE, range=26, brightness=1.15)])
def bone_brazier():
    """A brazier burning with the realm's pale fire: a deep bowl of hammered iron, its lip rolled over, a band of
    rivets round it and four prongs curling up off the rim, held on three long bones that splay to the ground, an iron
    band forged round the three where they cross and clamps at their heads; a bed of embers in the bowl among charred
    bones."""
    bone = bone_mat("Brz")
    iron, rust = _iron("Brz"), _rust("Brz")
    char = mk.noisy("BrzChar_Bone", srgb(30, 28, 26), srgb(60, 56, 50), roughness=0.9)
    rng = random.Random(41)
    # (the ash round its feet is the ground's own: lobby ground.py banks it up round whatever stands in it)
    parts = []
    # The legs: three long bones from their feet out in the ash to the bowl's underside.
    tops = []
    for k in range(3):
        a = 2 * math.pi * k / 3 + 0.3
        foot = (math.cos(a) * 1.28, math.sin(a) * 1.28, 0.04)
        top = (math.cos(a) * 0.5, math.sin(a) * 0.5, 4.02)
        parts += [weathered(p, {"sub": 0, "disp": [("grain", 0.004, 0.02)]}) for p in long_bone(f"Leg{k}", foot, top,
                                                                                                0.12, bone)]
        tops.append(top)
        # an iron clamp round each bone's head, bolted to the bowl
        parts.append(weathered(mk.cylinder(f"Clamp{k}", 0.2, 0.32, (top[0] * 0.98, top[1] * 0.98, 3.78), mat=iron,
                                           verts=10), FORGED))
    # The band forged round the three where they draw together, a knot of wire over it.
    for z, r in ((2.62, 0.82), (2.84, 0.79)):
        parts.append(weathered(mk.torus("Band", r, 0.075, (0, 0, z), mat=rust, major_segments=24, minor_segments=6),
                               FORGED))
    for k in range(3):
        a = 2 * math.pi * k / 3 + 0.3
        parts.append(mk.box("BandRivet", (0.16, 0.16, 0.36), (math.cos(a) * 0.8, math.sin(a) * 0.8, 2.73),
                            rot=(0, 0, math.degrees(a)), mat=iron, bevel=0.04))
    # The bowl: hammered iron, deep, its lip rolled over, a band of rivets round it.
    bowl = mk.lathe("Bowl", [(0.25, 3.82), (0.7, 3.86), (1.08, 4.05), (1.33, 4.42), (1.43, 4.82), (1.46, 4.93),
                             (1.36, 4.95), (1.27, 4.62), (1.02, 4.3), (0.6, 4.14), (0.0, 4.12)], mat=iron, segments=28)
    parts.append(weathered(bowl, FORGED))
    parts.append(weathered(mk.torus("Lip", 1.44, 0.075, (0, 0, 4.95), mat=iron, major_segments=32, minor_segments=8),
                           FORGED))
    parts.append(weathered(mk.torus("Strap", 1.3, 0.05, (0, 0, 4.4), mat=rust, major_segments=32, minor_segments=6),
                           FORGED))
    for k in range(16):
        a = 2 * math.pi * k / 16
        parts.append(mk.sphere("Rivet", 0.055, (math.cos(a) * 1.35, math.sin(a) * 1.35, 4.4), mat=iron, segments=8,
                               rings=5))
    # Four prongs curling up and out off the rim.
    for k in range(4):
        a = 2 * math.pi * k / 4 + 0.25
        pts = []
        for q in range(7):
            u = q / 6
            rr = 1.44 + 0.22 * math.sin(u * math.pi * 0.8)
            pts.append((math.cos(a) * rr, math.sin(a) * rr, 4.92 + 0.62 * u - 0.12 * u * u))
        tip = pts[-1]
        pts.append((tip[0] + math.cos(a) * 0.06, tip[1] + math.sin(a) * 0.06, tip[2] - 0.12))
        parts.append(weathered(pk.sweep(f"Prong{k}", pts, [0.07, 0.07, 0.06, 0.055, 0.045, 0.035, 0.025, 0.012], iron,
                                        sides=6), FORGED))
    # Charred bones in the bowl among the embers.
    for k in range(5):
        a = rng.uniform(0, math.tau)
        d = rng.uniform(0.2, 0.75)
        cx, cy = math.cos(a) * d, math.sin(a) * d
        yaw = rng.uniform(0, math.tau)
        length = rng.uniform(0.4, 0.7)
        parts.append(mk.tube("Char", (cx - math.cos(yaw) * length / 2, cy - math.sin(yaw) * length / 2, 4.5),
                             (cx + math.cos(yaw) * length / 2, cy + math.sin(yaw) * length / 2, 4.58 + rng.uniform(0, 0.1)),
                             0.06, 0.05, mat=char, verts=6))
    # The bed of embers glows; the fire over it is the game's (a living fire, Presentation/Vfx Recipes.flame).
    embers = mk.lathe("Embers", [(0.0, 4.48), (1.05, 4.45), (1.12, 4.5), (0.7, 4.6), (0.0, 4.62)],
                      mat=pk.glow("Brz_Ember", (120, 150, 210), 3), segments=16)
    return parts, [embers], {"flames": [(0, 0, 4.6, 2.6, 1)]}


@prop("LanternPost", pivot="bottom", material="Wood", collide=True, texture=512, set="Lobby", anchor=(0, 0),
      detail=True, normal=256, lights=[dict(at=(0, -1.9, 6.6), kind="point", color=PALE_FIRE, range=18, brightness=0.8)])
def lantern_post():
    """A gnarled post of black wood driven into the ash, an iron band round its foot, a scrolled iron bracket out from
    its head; hanging from the bracket on a short chain, an open iron lantern of six posts and two bands, its roof
    peaked to a ring, a stub of candle burning inside. A bone charm is tied to the post."""
    wood = mk.noisy("Lnp_Bark", srgb(28, 26, 26), srgb(64, 60, 58), roughness=0.95)
    iron, rust = _iron("Lnp"), _rust("Lnp")
    bone = bone_mat("Lnp")
    rng = random.Random(7)
    # The post: one gnarled length, bending a little, a knot here and there.
    pts = [(0.0, 0.0, -0.3), (0.05, 0.04, 1.6), (0.16, 0.12, 3.4), (0.14, 0.1, 5.2), (0.06, 0.02, 6.9), (0.02, 0.0, 8.5)]
    radii = [0.3, 0.27, 0.25, 0.23, 0.2, 0.18]
    post = pk.sweep("Post", pts, radii, wood, sides=9)
    parts = [weathered(post, BARK)]
    for z, a in ((2.3, 0.6), (4.6, 2.9), (6.2, 4.4)):
        parts.append(weathered(mk.sphere("Knot", 0.16, (0.12 + math.cos(a) * 0.2, 0.08 + math.sin(a) * 0.2, z),
                                         scale=(1.0, 1.0, 1.4), mat=wood, segments=10, rings=6), BARK))
    parts.append(mk.lathe("Cap", [(0.0, 8.48), (0.24, 8.48), (0.22, 8.6), (0.0, 8.66)], mat=iron, segments=10))
    parts.append(weathered(mk.cylinder("Collar", 0.36, 0.34, (0.02, 0.02, 0.85), mat=rust, verts=12), FORGED))
    # The bracket: an arm out from the head, a scroll under it bracing it back to the post.
    parts.append(weathered(mk.box("Arm", (0.12, 2.1, 0.14), (0.02, -0.95, 8.12), mat=iron, bevel=0.03), FORGED))
    parts.append(weathered(mk.cylinder("ArmBand", 0.25, 0.22, (0.02, 0.0, 8.12), mat=iron, verts=10), FORGED))
    scroll = []
    for q in range(15):
        u = q / 14
        a = u * math.pi * 1.6
        r = 0.55 * (1 - 0.55 * u)
        scroll.append((0.02, -0.25 - 0.9 * u - math.sin(a) * r * 0.4, 7.6 + math.cos(a) * r * 0.9 - 0.5 * u))
    parts.append(weathered(pk.sweep("Scroll", scroll, 0.04, iron, sides=5), FORGED))
    parts.append(weathered(mk.tube("Brace", (0.02, -0.05, 7.1), (0.02, -1.45, 8.06), 0.035, mat=iron, verts=6), FORGED))
    cx, cy, cz = 0.02, -1.9, 6.6
    # The chain down to the lantern's ring.
    for k in range(4):
        z = 8.0 - k * 0.2
        ring = mk.torus("ChainLink", 0.07, 0.022, (cx, cy, z), rot=(90 if k % 2 else 0, 0, 90), mat=iron,
                        major_segments=8, minor_segments=4)
        ring.scale = (1.0, 1.0, 1.6) if k % 2 else (1.0, 1.6, 1.0)
        parts.append(ring)
    # The lantern: a base, six corner posts, six smoked panes, a peaked roof to a ring.
    parts += [mk.cylinder("Base", 0.42, 0.12, (cx, cy, cz - 0.7), mat=iron, verts=6),
              mk.cylinder("BaseFoot", 0.32, 0.1, (cx, cy, cz - 0.82), mat=iron, verts=6),
              mk.cylinder("Top", 0.46, 0.1, (cx, cy, cz + 0.62), mat=iron, verts=6),
              mk.cylinder("Roof", 0.48, 0.42, (cx, cy, cz + 0.88), mat=iron, verts=6, radius2=0.08),
              mk.torus("RoofRing", 0.12, 0.03, (cx, cy, cz + 1.18), rot=(90, 0, 0), mat=iron, major_segments=10,
                       minor_segments=4)]
    for k in range(6):
        a = 2 * math.pi * k / 6
        parts.append(mk.box("CornerPost", (0.05, 0.05, 1.3), (cx + math.cos(a) * 0.4, cy + math.sin(a) * 0.4, cz - 0.04),
                            mat=iron))
    # (open between its posts, two bands round it: the flame shows through, as a pane would have hidden it)
    for z in (cz - 0.28, cz + 0.24):
        parts.append(mk.torus("Band", 0.4, 0.022, (cx, cy, z), mat=iron, major_segments=6, minor_segments=4))
    # A stub of candle inside; its flame is the game's.
    wax = candle_wax("Lnp")
    wick = mk.flat("Lnp_Wick", srgb(16, 14, 13), 0.9)
    body, tip = candle("LnpCandle", cx, cy, cz - 0.64, 0.14, 0.4, wax, wick, rng, drips=2)
    parts += body
    # The charm tied to the post: a finger bone on a cord.
    parts += long_bone("Charm", (0.34, -0.2, 5.0), (0.3, -0.24, 5.75), 0.045, bone)
    parts.append(mk.tube("Cord", (0.22, -0.1, 5.85), (0.3, -0.24, 5.75), 0.012, mat=mk.flat("Lnp_Cord", srgb(60, 52, 44),
                                                                                           0.95), verts=4))
    return parts, [], {"flames": [(tip[0], tip[1], tip[2], 0.6)]}
