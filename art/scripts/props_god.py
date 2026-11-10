"""The Devourer of Gods for "A GOD.. IS NOT... AFRAID OF..." (Core set, 2026-11-10; the user: "you completely butchered
the devourer of gods model. Make it 100x more high quality ... give him his actual head"). Our own modelling after the
boss's look (Calamity's cosmic serpent), not its art: a long-skulled armoured head with two slanted pink eyes, a
gaping jaw ringed with teeth, hooked mandibles and a crest of swept-back horns, its plates seamed in cyan; armoured
ring segments with overlapping plates, side spikes and a dorsal spine; a finned tail. Each carries a "Cracks" piece:
glowing fractures over its surface (unbaked: the scene colours them neon), which the scene lights up (SceneDeaths/God) as the god cracks apart.

Along -Y (the head leads), up Z. A segment is 4.6 long and 4.4 across: the scene strings them 4.2 apart."""

import math
import random

from mathutils import Vector

import modelkit as mk
import propkit as pk
import props
from common import srgb
from props import prop
from props_lobby import _blob


def _materials(tag):
    armor = pk.metal(tag + "_Armor", (26, 18, 46), (72, 50, 118), rough=0.32, metallic=0.75, scale=20)
    plate = pk.metal(tag + "_Plate", (40, 28, 70), (96, 70, 150), rough=0.28, metallic=0.8, scale=24)
    bone = mk.noisy(tag + "_Bone", srgb(200, 186, 214), srgb(240, 232, 248), scale=18, roughness=0.5, kind="plastic")
    cyan = pk.glow(tag + "_Cyan", (70, 230, 255), 3.0)
    pink = pk.glow(tag + "_Pink", (255, 80, 220), 3.4)
    crack = mk.flat(tag + "_Crack", srgb(255, 236, 255), 0.4)
    return armor, plate, bone, cyan, pink, crack


def _cracks(name, surface, count, length, mat, seed, radius=0.045):
    """Jagged glowing fracture lines lying on a surface: `surface(u, v)` gives a point (u, v in 0..1) and its outward
    normal; each crack wanders from a random start, forking once, lifted a hair off the surface."""
    rnd = random.Random(seed)
    parts = []
    for c in range(count):
        u, v = rnd.random(), rnd.random()
        du, dv = rnd.uniform(-1, 1), rnd.uniform(-1, 1)
        n = math.hypot(du, dv) or 1
        du, dv = du / n, dv / n
        pts = []
        for s in range(9):
            p, nrm = surface(u, v)
            pts.append(tuple(Vector(p) + Vector(nrm) * 0.04))
            ang = rnd.uniform(-0.9, 0.9)
            du, dv = du * math.cos(ang) - dv * math.sin(ang), du * math.sin(ang) + dv * math.cos(ang)
            u = (u + du * length / 8) % 1.0
            v = min(1.0, max(0.0, v + dv * length / 8))
        parts.append(pk.sweep(f"{name}{c}", pts, [radius * (1.4 - 0.9 * k / 8) for k in range(9)], mat, sides=4))
    return parts


@prop("GodHead", pivot="centre", material="Metal", collide=False, texture=512)
def god_head():
    """The Devourer's head: a long armoured skull, its brow swept back into a crest of six horns, two slanted pink eyes
    under the brow, a gaping jaw ringed with teeth, two hooked mandibles curling forward from the cheeks, cyan seams
    between the plates. Front to -Y."""
    armor, plate, bone, cyan, pink, crack = _materials("GH")
    parts = []
    skull = _blob("Skull", [("ellipsoid", (0, 0.4, 0.7), 2.2, (1.0, 1.7, 0.8)),
                            ("ellipsoid", (0, -2.4, 0.5), 1.6, (1.05, 1.25, 0.62)),
                            ("ellipsoid", (1.5, -0.8, 0.0), 1.05, (1.0, 1.3, 0.9)),
                            ("ellipsoid", (-1.5, -0.8, 0.0), 1.05, (1.0, 1.3, 0.9)),
                            ("ellipsoid", (0, 2.6, 0.9), 1.5, (1.0, 1.0, 0.8)),
                            ("hollow", (0, -3.2, -0.55), 1.1, (1.0, 1.35, 0.55)),  # the gaping mouth
                            ("hollow", (0.95, -2.2, 0.95), 0.42, (1.5, 0.8, 0.5)),  # the eye sockets
                            ("hollow", (-0.95, -2.2, 0.95), 0.42, (1.5, 0.8, 0.5))], 0.14, 0.45, armor)
    parts.append(skull)
    jaw = _blob("Jaw", [("capsule", (1.25, 0.8, -1.0), (0.85, -3.6, -1.15), 0.55),
                        ("capsule", (-1.25, 0.8, -1.0), (-0.85, -3.6, -1.15), 0.55),
                        ("ellipsoid", (0, -3.7, -1.2), 0.75, (1.4, 0.8, 0.6)),
                        ("hollow", (0, -1.6, -0.75), 1.0, (0.95, 2.3, 0.5))], 0.12, 0.5, plate)
    parts.append(jaw)
    # the brow ridges over the eyes, and the eyes themselves (slanted, glowing pink)
    for side in (-1, 1):
        parts.append(pk.sweep("Brow", [(side * 0.3, -3.0, 1.35), (side * 1.0, -2.5, 1.45), (side * 1.7, -1.6, 1.25),
                                       (side * 2.1, -0.4, 0.95)], [0.18, 0.24, 0.2, 0.1], plate, sides=6))
    glows = []
    for side in (-1, 1):
        # (on the skull's surface, not inside it: a slanted lens standing proud of the socket, under its brow)
        eye = mk.sphere("Eye", 0.42, (side * 1.38, -2.3, 1.12), scale=(1.5, 0.8, 0.55), mat=pink, segments=16,
                        rings=8)
        eye.rotation_euler = (math.radians(-20), math.radians(side * -32), math.radians(side * 26))
        glows.append(eye)
    # armour plates over the skull: a crown plate on top, a long nasal plate down the snout, cheek plates
    parts.append(pk.rounded("CrownPlate", (2.6, 2.6, 0.5), (0, 0.6, 2.2), plate, r=0.14, rot=(-12, 0, 0)))
    parts.append(pk.rounded("NasalPlate", (1.3, 3.2, 0.4), (0, -1.9, 1.75), plate, r=0.12, rot=(14, 0, 0)))
    for side in (-1, 1):
        cheek = pk.rounded("CheekPlate", (0.5, 2.4, 1.4), (side * 2.05, -1.1, 0.3), plate, r=0.12)
        cheek.rotation_euler = (0, math.radians(side * 12), math.radians(side * -10))
        parts.append(cheek)
    # teeth round the mouth: upper row from the skull, lower from the jaw, pointing into the gape
    for k in range(9):
        a = math.pi * (0.1 + 0.8 * k / 8)
        x, y = math.cos(a) * 0.95, -3.2 - math.sin(a) * 1.05
        parts.append(mk.cylinder("ToothU", 0.11, 0.5, (x, y, -0.12), mat=bone, verts=6, radius2=0.0, rot=(180, 0, 0)))
        parts.append(mk.cylinder("ToothL", 0.1, 0.42, (x * 0.92, y + 0.15, -0.95), mat=bone, verts=6, radius2=0.0))
    # the mandibles: hooked, curling forward and in from the cheeks
    for side in (-1, 1):
        hook = [(side * 1.9, -1.0, -0.5), (side * 2.4, -2.4, -0.7), (side * 2.2, -3.9, -0.9), (side * 1.6, -4.8, -1.0),
                (side * 0.95, -5.1, -0.9)]
        parts.append(pk.sweep("Mandible", hook, [0.42, 0.36, 0.28, 0.17, 0.04], bone, sides=8))
    # the crest: six horns swept back and up from the brow
    for side in (-1, 1):
        for k, (out, lift, back) in enumerate(((0.5, 1.3, 2.4), (1.2, 1.0, 3.0), (1.9, 0.5, 2.6))):
            root = Vector((side * (0.35 + 0.55 * k), 0.2 + 0.4 * k, 1.75 - 0.35 * k))
            tip = root + Vector((side * out, back, lift + 1.0))
            mid = root.lerp(tip, 0.5) + Vector((0, -0.2, 0.5))
            parts.append(pk.sweep("Horn", [tuple(root), tuple(mid), tuple(tip)], [0.3 - 0.05 * k, 0.2, 0.02], plate,
                                  sides=6))
    # cyan seams between the plates: down each side of the skull and round the back of the head
    for side in (-1, 1):
        glows.append(pk.sweep("Seam", [(side * 1.95, -1.8, 0.3), (side * 2.2, -0.4, 0.5), (side * 2.0, 1.2, 0.8),
                                       (side * 1.4, 2.8, 1.1)], 0.07, cyan, sides=5))
    ring = mk.torus("CollarSeam", 1.75, 0.08, (0, 3.2, 0.7), rot=(90, 0, 0), mat=cyan, major_segments=32,
                    minor_segments=5)
    glows.append(ring)

    def on_skull(u, v):
        a = 2 * math.pi * u
        y = -3.0 + 6.0 * v
        rx = 2.0 * math.sqrt(max(0.05, 1 - ((y + 0.2) / 3.4) ** 2))
        p = (math.cos(a) * rx, y, 0.6 + math.sin(a) * rx * 0.8)
        return p, (math.cos(a), 0.0, math.sin(a))

    cracks = _cracks("Crack", on_skull, 22, 0.55, crack, 7)
    return parts, glows, {"pieces": {"Cracks": props.piece(cracks, bake=False)}}


def _segment(tag, length, radius, spikes=True, fins=False):
    armor, plate, bone, cyan, pink, crack = _materials(tag)
    parts = []
    # the core: a barrel round Y
    prof = [(radius * 0.82, -length / 2), (radius * 0.96, -length * 0.3), (radius, 0.0), (radius * 0.96, length * 0.3),
            (radius * 0.84, length / 2)]
    core = mk.lathe("Core", prof, mat=armor, segments=28)
    core.rotation_euler = (math.radians(-90), 0, 0)
    parts.append(core)
    # eight overlapping plates round it, each leaning back a little like a scale
    for k in range(8):
        a = 2 * math.pi * (k + 0.5) / 8
        c = Vector((math.cos(a) * (radius + 0.12), -0.2, math.sin(a) * (radius + 0.12)))
        p = pk.rounded("Plate", (radius * 0.78, length * 0.7, 0.24), tuple(c), plate, r=0.08)
        p.rotation_euler = (math.radians(-8), -(a - math.pi / 2), 0)
        parts.append(p)
    glows = [mk.torus("Seam", radius * 0.97, 0.07, (0, -length * 0.42, 0), rot=(90, 0, 0), mat=cyan,
                      major_segments=32, minor_segments=5)]
    for side in (-1, 1):
        glows.append(mk.sphere("Light", 0.18, (side * radius * 0.55, -0.4, -radius * 0.86), mat=pink, segments=10,
                               rings=6))
    if spikes:
        # a curved spike out of each side, raking back; a dorsal spine
        for side in (-1, 1):
            parts.append(pk.sweep("Spike", [(side * radius * 0.9, -0.6, 0.3), (side * (radius + 1.2), 0.6, 0.5),
                                            (side * (radius + 1.9), 2.0, 0.2)], [0.42, 0.24, 0.02], bone, sides=7))
        parts.append(pk.sweep("Spine", [(0, -0.8, radius * 0.95), (0, 0.4, radius + 1.0), (0, 1.8, radius + 1.4)],
                              [0.36, 0.2, 0.02], bone, sides=7))
    if fins:
        for k in range(3):
            a = math.radians(90 + (k - 1) * 120)
            base = Vector((math.cos(a) * radius * 0.6, length * 0.3, math.sin(a) * radius * 0.6))
            tip = base + Vector((math.cos(a) * 1.8, 2.6, math.sin(a) * 1.8))
            parts.append(pk.sweep("Fin", [tuple(base), tuple(base.lerp(tip, 0.5)), tuple(tip)], [0.5, 0.3, 0.03],
                                  plate, sides=6))

    def on_ring(u, v):
        a = 2 * math.pi * u
        y = -length / 2 + length * v
        r = radius + 0.3
        return (math.cos(a) * r, y, math.sin(a) * r), (math.cos(a), 0.0, math.sin(a))

    cracks = _cracks("Crack", on_ring, 14, 0.5, crack, len(tag) * 13 + int(radius * 10))
    return parts, glows, {"pieces": {"Cracks": props.piece(cracks, bake=False)}}


@prop("GodBody", pivot="centre", material="Metal", collide=False, texture=512)
def god_body():
    """One armoured ring of the Devourer's body: a barrel core under eight overlapping plates, a curved spike out of
    each side and a dorsal spine, a cyan seam at its front edge, two pink lights below. Along Y."""
    return _segment("GB", 4.6, 2.2)


@prop("GodTail", pivot="centre", material="Metal", collide=False, texture=256)
def god_tail():
    """The Devourer's tail: a tapering armoured segment ending in three swept fins. Along Y."""
    return _segment("GT", 3.6, 1.5, spikes=False, fins=True)


