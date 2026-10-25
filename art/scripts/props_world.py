"""The Specter and the map kit: furniture, street props and set pieces (see props.py)."""

import math
import random

import bmesh
import bpy
from mathutils import Vector

import modelkit as mk
from common import srgb
from props import (
    BONE_A,
    BONE_B,
    BRASS_A,
    BRASS_B,
    DEEP_RED,
    INK,
    IRON_A,
    IRON_B,
    PAPER_A,
    PAPER_B,
    RED,
    STEEL_A,
    STEEL_B,
    WOOD_DARK,
    WOOD_LIGHT,
    prop,
)

LAMP = srgb(255, 214, 160)
LEATHER_RED = (srgb(70, 16, 20), srgb(104, 30, 32))
FOLIAGE = (srgb(34, 62, 40), srgb(70, 104, 66))


def cast_iron(name="Iron"):
    return mk.noisy(name, IRON_A, IRON_B, scale=22, detail=10, roughness=0.55, metallic=0.7)


def dark_wood(name="DarkWood"):
    return mk.wood(name, WOOD_LIGHT, WOOD_DARK, scale=4, rings=14)


# The Specter ----------------------------------------------------------------------------------------------


def robe_mesh(name, mat, rings, segments=40, seed=4):
    """A cloak spun from rings [(radius, z, depth scale)]; the lowest ring is torn into a
    ragged hem."""
    rng = random.Random(seed)
    bm = bmesh.new()
    verts_by_ring = []
    for k, (r, z, depth) in enumerate(rings):
        ring = []
        for i in range(segments):
            a = 2 * math.pi * i / segments
            zz = z
            rr = r * (1 + 0.04 * math.sin(a * 7 + k))
            if k == 0:
                zz = z + (rng.random() * 0.9 if i % 2 else rng.random() * 0.2)
                rr *= 1.0 + rng.random() * 0.08
            ring.append(bm.verts.new((math.cos(a) * rr, math.sin(a) * rr * depth, zz)))
        verts_by_ring.append(ring)
    for k in range(len(verts_by_ring) - 1):
        for i in range(segments):
            j = (i + 1) % segments
            bm.faces.new((verts_by_ring[k][i], verts_by_ring[k][j], verts_by_ring[k + 1][j], verts_by_ring[k + 1][i]))
    bm.faces.new(verts_by_ring[-1])
    mesh = bpy.data.meshes.new(name)
    bm.to_mesh(mesh)
    bm.free()
    obj = bpy.data.objects.new(name, mesh)
    mesh.materials.append(mat)
    mk._link(obj)
    mk.smooth(obj)
    solid = obj.modifiers.new("Solidify", "SOLIDIFY")
    solid.thickness = 0.08
    return obj


def wing(name, mat, side):
    """A ragged, bat-like wing: fingers of bone with torn membrane between them."""
    pts = [(0, 0), (1.2, 1.6), (2.6, 3.4), (3.3, 2.6), (2.9, 2.2), (3.6, 1.2), (2.9, 1.0), (3.1, 0.0),
           (2.4, 0.3), (2.2, -0.9), (1.6, -0.2), (0.8, -0.6)]
    pts = [(x * side, y) for x, y in pts]
    if side < 0:
        pts = list(reversed(pts))
    obj = mk.extrude_shape(name, pts, 0.06, mat=mat)
    return obj


# The Deathsinger (2026-10-25: the owner's reference, a lanky death god of the old manga kind: "he looks extremely
# chopped and ugly ... do his model based on the 7th image and please make it high quality"). One connected body grown
# from a skeleton (a skin of the joints, smoothed), gaunt and long-limbed, hunched, its hands hanging past its hips and
# its feet pointed as it floats; a white face with a wide grin of sharp teeth and burning red eyes, dark blue hair in
# spikes, a great collar of black feathers fanning out round a white fur ruff, a studded belt with a skull buckle and
# hanging chains, a short ragged skirt, a skull at one wrist, rings on its fingers, the Manual at its hip. It faces -Y.


def skin_body(name, mat, joints, bones, levels=2):
    """A smooth body grown from a skeleton: `joints` [(x, y, z, rx, ry)] and `bones` [(i, j)], the Skin modifier
    giving each joint its radii and the Subdivision modifier (`levels`) rounding it all into one surface."""
    bm = bmesh.new()
    verts = [bm.verts.new((x, y, z)) for (x, y, z, _, _) in joints]
    for i, j in bones:
        bm.edges.new((verts[i], verts[j]))
    mesh = bpy.data.meshes.new(name)
    bm.to_mesh(mesh)
    bm.free()
    obj = bpy.data.objects.new(name, mesh)
    mesh.materials.append(mat)
    mk._link(obj)
    skin = obj.modifiers.new("Skin", "SKIN")
    skin.use_smooth_shade = True
    layer = mesh.skin_vertices[0].data
    for k, (_, _, _, rx, ry) in enumerate(joints):
        layer[k].radius = (rx, ry)
    # (a root in every separate island of the skeleton: a body may be grown as limbs apart)
    parent = list(range(len(joints)))

    def find(k):
        while parent[k] != k:
            parent[k] = parent[parent[k]]
            k = parent[k]
        return k

    for i, j in bones:
        parent[find(i)] = find(j)
    rooted = set()
    for k in range(len(joints)):
        if find(k) not in rooted:
            rooted.add(find(k))
            layer[k].use_root = True
    sub = obj.modifiers.new("Subdivision", "SUBSURF")
    sub.levels = levels
    sub.render_levels = levels
    return obj


def feather_blade(name, root, tip, width, mat):
    """One long black feather: a blade swept from the root to the tip, widest a third of the way, flat-ish."""
    axis = (tip - root)
    length = axis.length
    # (its flat face toward the front, so a collar fanned out sideways shows its feathers, not their edges)
    side = axis.cross(Vector((0, 1, 0)))
    if side.length < 0.25 * length:
        side = Vector((1, 0, 0))
    side.normalize()
    normal = side.cross(axis).normalized()
    bm = bmesh.new()
    rows = []
    for k in range(7):
        t = k / 6
        half = width * (math.sin(math.pi * min(1.0, 0.18 + t * 0.95)) ** 0.6) * (1 - 0.6 * t)
        centre = root + axis * t + normal * (0.06 * math.sin(math.pi * t) * length)
        rows.append((bm.verts.new(centre - side * half), bm.verts.new(centre + normal * 0.012),
                     bm.verts.new(centre + side * half)))
    for k in range(6):
        a, b = rows[k], rows[k + 1]
        bm.faces.new((a[0], b[0], b[1], a[1]))
        bm.faces.new((a[1], b[1], b[2], a[2]))
    obj = mk._obj_from_bm(name, bm, mat)
    solid = obj.modifiers.new("Solidify", "SOLIDIFY")
    solid.thickness = 0.02
    return obj


# Street and park ----------------------------------------------------------------------------------------------


@prop("LampPost", pivot="bottom", material="Metal", collide=True, texture=1024)
def lamp_post():
    iron = cast_iron("Lamp_Iron")
    glass = mk.noisy("Lamp_Glass", srgb(40, 44, 52), srgb(70, 76, 90), scale=8, roughness=0.1)
    parts = [
        mk.cylinder("Plinth", 0.62, 0.35, (0, 0, 0.175), mat=iron, verts=8, bevel=0.03),
        mk.cylinder("Plinth2", 0.48, 0.5, (0, 0, 0.6), mat=iron, verts=8, bevel=0.03, radius2=0.36),
        mk.cylinder("Pole", 0.17, 10.6, (0, 0, 6.1), mat=iron, verts=12, radius2=0.12),
    ]
    for z in (1.0, 4.0, 11.2):
        parts.append(mk.torus("Collar", 0.2, 0.05, (0, 0, z), mat=iron, major_segments=16, minor_segments=6))
    # Arm curling out to the front, with a scroll underneath.
    for i in range(10):
        a = math.radians(i * 10)
        parts.append(mk.cylinder("Arm", 0.07, 0.35, (0, -1.1 * math.sin(a), 11.4 + 1.1 * (1 - math.cos(a)) * 0.6),
                                 rot=(90 - i * 6, 0, 0), mat=iron, verts=8))
    parts.append(mk.torus("Scroll", 0.35, 0.04, (0, -0.55, 11.0), rot=(0, 90, 0), mat=iron, major_segments=20,
                          minor_segments=6))
    # Lantern: hexagonal glass box with an iron frame and a pointed roof.
    lx, lz = -1.15, 11.0
    parts.append(mk.cylinder("LanternBase", 0.42, 0.12, (0, lx, lz - 0.7), mat=iron, verts=6))
    parts.append(mk.cylinder("LanternGlass", 0.36, 1.1, (0, lx, lz - 0.1), mat=glass, verts=6, radius2=0.44))
    parts.append(mk.cylinder("LanternRoof", 0.56, 0.5, (0, lx, lz + 0.7), mat=iron, verts=6, radius2=0.05))
    parts.append(mk.sphere("Finial", 0.09, (0, lx, lz + 1.0), mat=iron, segments=10, rings=6))
    for i in range(6):
        a = math.radians(i * 60)
        parts.append(mk.box("Frame", (0.04, 0.04, 1.15), (math.cos(a) * 0.41, lx + math.sin(a) * 0.41, lz - 0.1),
                            mat=iron))
    bulb = [mk.sphere("Bulb", 0.22, (0, lx, lz - 0.1), scale=(1, 1, 1.3), mat=mk.emissive("Lamp_Glow", LAMP, 8),
                      segments=16, rings=10)]
    return parts, bulb


@prop("Bench", pivot="bottom", material="Wood", collide=True, texture=1024)
def bench():
    iron = cast_iron("Bench_Iron")
    wood = dark_wood("Bench_Wood")
    parts = []
    side_profile = [(-0.8, 0), (-0.6, 0), (-0.45, 1.3), (0.55, 1.3), (0.7, 0), (0.9, 0), (0.75, 1.5),
                    (0.95, 3.3), (0.8, 3.35), (0.55, 1.6), (-0.5, 1.6), (-0.65, 2.3), (-0.85, 2.3), (-0.7, 1.4)]
    for x in (-2.6, 2.6):
        side = mk.extrude_shape("Side", side_profile, 0.12, mat=iron, bevel=0.02)
        side.location = (x, 0, 0)
        side.rotation_euler = (math.radians(90), 0, math.radians(90))
        parts.append(side)
    for i in range(5):
        parts.append(mk.box("Seat", (5.8, 0.28, 0.09), (0, -0.55 + i * 0.3, 1.52), mat=wood, bevel=0.03))
    for i in range(3):
        z = 2.0 + i * 0.42
        parts.append(mk.box("Back", (5.8, 0.09, 0.3), (0, 0.72 + i * 0.07, z), rot=(-12, 0, 0), mat=wood, bevel=0.03))
    for x in (-2.6, 2.6):
        parts.append(mk.box("Arm", (0.14, 1.4, 0.1), (x, -0.1, 2.3), mat=iron, bevel=0.03))
    return parts, []


@prop("Crate", pivot="bottom", material="WoodPlanks", collide=True, texture=1024)
def crate():
    planks = mk.wood("Crate_Planks", srgb(150, 112, 70), srgb(94, 66, 40), scale=5, rings=10)
    frame = mk.wood("Crate_Frame", srgb(110, 80, 48), srgb(70, 48, 28), scale=5, rings=10)
    stencil = mk.flat("Crate_Stencil", srgb(40, 30, 24), 0.9)
    s = 4.0
    parts = [mk.box("Core", (s - 0.2, s - 0.2, s - 0.2), (0, 0, s / 2), mat=planks)]
    # Planks with gaps on every side.
    for axis in range(3):
        for sign in (-1, 1):
            for i in range(4):
                offset = -s / 2 + 0.5 + i * 1.0
                size = [s - 0.3, s - 0.3, s - 0.3]
                size[axis] = 0.08
                loc = [0.0, 0.0, s / 2]
                loc[axis] += sign * (s / 2 - 0.08)
                other = (axis + 1) % 3
                size[other] = 0.92
                loc[other] += offset
                parts.append(mk.box("Plank", tuple(size), tuple(loc), mat=planks, bevel=0.02))
    # Frame battens along every edge.
    for x in (-1, 1):
        for y in (-1, 1):
            parts.append(mk.box("Post", (0.32, 0.32, s), (x * (s / 2 - 0.12), y * (s / 2 - 0.12), s / 2), mat=frame,
                                bevel=0.03))
            parts.append(mk.box("RailX", (s, 0.3, 0.3), (0, y * (s / 2 - 0.12), (s - 0.15) if x > 0 else 0.15),
                                mat=frame, bevel=0.03))
            parts.append(mk.box("RailY", (0.3, s, 0.3), (x * (s / 2 - 0.12), 0, (s - 0.15) if y > 0 else 0.15),
                                mat=frame, bevel=0.03))
    # A stencilled "0" on the front.
    parts.append(mk.torus("Stencil", 0.55, 0.08, (0, -s / 2 - 0.04, s / 2), rot=(90, 0, 0), mat=stencil,
                          major_segments=24, minor_segments=4))
    return parts, []


@prop("Dumpster", pivot="bottom", material="Metal", collide=True, texture=1024)
def dumpster():
    green = mk.noisy("Dump_Paint", srgb(24, 50, 36), srgb(46, 70, 52), scale=10, detail=12, roughness=0.6,
                     metallic=0.4)
    rust = mk.noisy("Dump_Rust", srgb(60, 36, 24), srgb(96, 60, 36), scale=14, roughness=0.8)
    lid = mk.noisy("Dump_Lid", srgb(14, 14, 16), srgb(34, 34, 38), scale=12, roughness=0.5)
    parts = [
        mk.box("Body", (6, 3, 3.4), (0, 0, 2.1), mat=green, bevel=0.06),
        mk.box("Base", (6.2, 3.2, 0.3), (0, 0, 0.5), mat=rust, bevel=0.04),
        mk.box("LidL", (2.95, 3.1, 0.12), (-1.5, 0.05, 3.88), rot=(-6, 0, 0), mat=lid, bevel=0.03),
        mk.box("LidR", (2.95, 3.1, 0.12), (1.5, 0.05, 3.9), rot=(-2, 0, 0), mat=lid, bevel=0.03),
    ]
    for x in (-2.6, 2.6):
        parts.append(mk.box("Pocket", (0.5, 3.3, 0.4), (x, 0, 2.6), mat=rust, bevel=0.04))
        for y in (-1.2, 1.2):
            parts.append(mk.cylinder("Wheel", 0.28, 0.2, (x, y, 0.28), rot=(0, 90, 0), mat=lid, verts=16))
    for i in range(5):
        parts.append(mk.box("Rib", (0.12, 0.06, 3.0), (-2.4 + i * 1.2, -1.53, 2.1), mat=green, bevel=0.02))
    return parts, []


@prop("TrashCan", pivot="bottom", material="Metal", collide=True, texture=512)
def trash_can():
    steel = mk.noisy("Trash_Steel", srgb(70, 72, 76), srgb(110, 112, 118), scale=18, roughness=0.4, metallic=0.8)
    parts = [
        mk.lathe("Can", [(0.0, 0.0), (0.55, 0.0), (0.58, 0.1), (0.6, 2.0), (0.64, 2.05), (0.0, 2.05)], mat=steel,
                 segments=24),
        mk.lathe("Lid", [(0.66, 2.05), (0.66, 2.15), (0.5, 2.3), (0.15, 2.38), (0.0, 2.38)], mat=steel, segments=24),
        mk.torus("Handle", 0.14, 0.03, (0, 0, 2.42), rot=(90, 0, 0), mat=steel, major_segments=12, minor_segments=6),
    ]
    for z in (0.5, 1.0, 1.5):
        parts.append(mk.torus("Rib", 0.6, 0.025, (0, 0, z), mat=steel, major_segments=24, minor_segments=4))
    return parts, []


@prop("Hydrant", pivot="bottom", material="Metal", collide=True, texture=512)
def hydrant():
    paint = mk.noisy("Hyd_Paint", srgb(130, 18, 24), srgb(170, 34, 36), scale=16, roughness=0.5, metallic=0.3)
    cap = mk.noisy("Hyd_Cap", srgb(60, 60, 64), srgb(100, 100, 106), scale=16, roughness=0.4, metallic=0.8)
    parts = [
        mk.lathe("Body", [(0.0, 0.0), (0.4, 0.0), (0.4, 0.15), (0.3, 0.2), (0.28, 1.3), (0.34, 1.35), (0.3, 1.5),
                          (0.2, 1.8), (0.0, 1.85)], mat=paint, segments=20),
        mk.cylinder("Nozzle", 0.12, 0.3, (0.38, 0, 1.0), rot=(0, 90, 0), mat=cap, verts=12),
        mk.cylinder("Nozzle", 0.12, 0.3, (-0.38, 0, 1.0), rot=(0, 90, 0), mat=cap, verts=12),
        mk.cylinder("Front", 0.16, 0.25, (0, -0.35, 1.0), rot=(90, 0, 0), mat=cap, verts=12),
        mk.cylinder("Bolt", 0.06, 0.15, (0, 0, 1.9), mat=cap, verts=6),
    ]
    return parts, []


@prop("Tree", pivot="bottom", material="Grass", collide=True, texture=1024, anchor=(0, 0))
def tree():
    """A city tree in leaf, for the beds on Tokyo's station plaza: a grey-brown trunk dividing into upswept limbs that
    divide again, clumps of dark leaves at the twigs (grown like Tokyo's cherries: props_tokyo_trees.tree), fitted
    into the box the beds were laid out round (build_props.FIT_TO_KEPT). The anchor is the trunk's foot."""
    import props_tokyo_trees as trees

    bark = mk.noisy("Tree_Bark", srgb(52, 44, 38), srgb(92, 80, 68), scale=10, roughness=0.9, stretch=(1, 1, 0.25))
    greens = [mk.noisy("Tree_Leaf1", srgb(30, 56, 32), srgb(60, 92, 50), scale=36, roughness=0.85),
              mk.noisy("Tree_Leaf2", srgb(38, 66, 36), srgb(74, 108, 58), scale=36, roughness=0.85),
              mk.noisy("Tree_Leaf3", srgb(26, 46, 28), srgb(50, 78, 42), scale=36, roughness=0.85)]
    parts = trees.tree("Tree_", 31, trunk_h=4.4, trunk_r=0.55, limbs=6, limb_len=4.2, depth=2, spread=0.6, rise=0.62,
                       droop=0.25, bark=bark, foliage=greens, clump_r=1.55, clumps_per_tip=4, lift=0.3)
    # (the crown filled in over the fork, so it reads as one canopy and not a ring of balls)
    rng = random.Random(32)
    for k in range(16):
        a = 2 * math.pi * k / 16 + rng.uniform(-0.2, 0.2)
        r = rng.uniform(0.8, 3.4) if k % 2 else rng.uniform(2.4, 3.8)
        c = mk.sphere("Tree_Inner", rng.uniform(1.7, 2.3), (math.cos(a) * r, math.sin(a) * r, rng.uniform(6.6, 9.8)),
                      scale=(1, 1, rng.uniform(0.62, 0.78)), mat=greens[k % 3], segments=9, rings=6)
        mk.displace_noise(c, strength=0.6, scale=0.9, name="Tree_InnerNoise")
        parts.append(c)
    return parts, []


@prop("Plant", pivot="bottom", material="Grass", collide=True, texture=512)
def plant():
    pot = mk.noisy("Plant_Pot", srgb(40, 30, 28), srgb(70, 52, 44), scale=10, roughness=0.8)
    soil = mk.flat("Plant_Soil", srgb(22, 16, 12), 1.0)
    leaf = mk.noisy("Plant_Leaf", *FOLIAGE, scale=6, roughness=0.7)
    parts = [
        mk.lathe("Pot", [(0.0, 0.0), (0.6, 0.0), (0.8, 1.6), (0.9, 1.7), (0.9, 1.85), (0.0, 1.85)], mat=pot,
                 segments=24),
        mk.cylinder("Soil", 0.82, 0.05, (0, 0, 1.78), mat=soil, verts=24),
    ]
    rng = random.Random(3)
    for i in range(14):
        a = i * (math.tau / 14) + rng.uniform(-0.2, 0.2)
        tilt = rng.uniform(25, 55)
        length = rng.uniform(1.6, 2.6)
        blade = mk.extrude_shape("Leaf", [(0, 0), (0.25, 0.6), (0.18, 1.4), (0, 2.0), (-0.18, 1.4), (-0.25, 0.6)], 0.03,
                                 mat=leaf)
        blade.scale = (1, length / 2.0, 1)
        blade.location = (0, 0, 1.8)
        blade.rotation_euler = (math.radians(90 - tilt), 0, a)
        parts.append(blade)
    return parts, []


@prop("Car", pivot="bottom", material="SmoothPlastic", collide=True, texture=1024)
def car():
    """A black saloon, chrome-trimmed: its body from a side profile, a dark glass cabin on its pillars, door seams and
    handles, mirrors, bumpers, plates and spoked wheels in their arches (Tokyo's cars' own body,
    props_tokyo_transit.car_body), drawn at a car's size and fitted into the box the Campus's parking was laid out round
    (build_props.FIT_TO_KEPT); its head and tail lamps lit."""
    import propkit as pk
    import props_tokyo_transit as transit

    length, width, split = 14.6, 6.4, 2.8
    parts, glows = transit.car_body("CR_", length=length, width=width, height=4.7, lower=(16, 16, 20),
                                    upper=(16, 16, 20), split=split, hood=4.0, boot=2.9, glass_tint=(18, 22, 30))
    half = length / 2
    chrome = pk.chrome("CR_Strip")
    for sx in (-1, 1):
        # (a chrome strip down each flank, under the windows' line)
        parts.append(mk.box("Strip", (0.04, length - 2.2, 0.07), (sx * (width / 2 + 0.01), 0.2, split - 0.35), mat=chrome))
        glows += [pk.rounded("Headlight", (1.1, 0.1, 0.32), (sx * (width / 2 - 0.9), -half - 0.07, 2.05),
                             pk.glow("Car_Head", (255, 236, 200), 5), r=0.05),
                  pk.rounded("Tail", (1.0, 0.1, 0.36), (sx * (width / 2 - 0.8), half + 0.05, split - 0.7),
                             pk.glow("Car_Tail", (220, 30, 36), 4), r=0.05)]
    return parts, glows


# Offices ------------------------------------------------------------------------------------------------


@prop("Desk", pivot="bottom", material="Wood", collide=True, texture=1024)
def desk():
    wood = dark_wood("Desk_Wood")
    metal = mk.noisy("Desk_Metal", srgb(30, 30, 34), srgb(60, 60, 66), scale=16, roughness=0.4, metallic=0.8)
    plastic = mk.noisy("Desk_Plastic", srgb(196, 188, 170), srgb(222, 214, 196), scale=20, roughness=0.6)
    screen = mk.flat("Desk_Screen", srgb(16, 22, 20), 0.2)
    paper = mk.noisy("Desk_Paper", PAPER_B, PAPER_A, scale=40, roughness=0.9)
    brass = mk.noisy("Desk_Brass", BRASS_B, BRASS_A, scale=14, roughness=0.3, metallic=1.0)
    parts = [
        mk.box("Top", (6.0, 3.0, 0.22), (0, 0, 2.94), mat=wood, bevel=0.05),
        mk.box("Pedestal", (1.9, 2.7, 2.8), (-1.95, 0.05, 1.45), mat=wood, bevel=0.04),
        mk.box("Modesty", (4.0, 0.12, 1.6), (1.0, 1.3, 2.0), mat=wood, bevel=0.03),
        mk.box("LegR", (0.22, 2.7, 2.83), (2.85, 0.05, 1.42), mat=wood, bevel=0.03),
    ]
    for i in range(3):
        z = 0.55 + i * 0.9
        parts.append(mk.box("Drawer", (1.7, 0.06, 0.78), (-1.95, -1.33, z), mat=wood, bevel=0.03))
        parts.append(mk.box("Handle", (0.5, 0.08, 0.07), (-1.95, -1.4, z + 0.15), mat=brass, bevel=0.02))
    # A boxy CRT monitor and keyboard.
    parts.append(mk.box("Monitor", (1.9, 1.7, 1.5), (1.1, 0.5, 3.85), mat=plastic, bevel=0.12))
    parts.append(mk.box("MonitorBack", (1.4, 0.9, 1.1), (1.1, 1.3, 3.8), mat=plastic, bevel=0.15))
    parts.append(mk.box("Bezel", (1.5, 0.05, 1.1), (1.1, -0.36, 3.9), mat=screen, bevel=0.05))
    parts.append(mk.box("Keyboard", (1.8, 0.65, 0.12), (1.0, -0.85, 3.11), rot=(4, 0, 0), mat=plastic, bevel=0.04))
    # Papers and a desk lamp.
    for i, (x, y, r) in enumerate(((-1.4, -0.4, 8), (-1.1, -0.2, -5), (-1.7, 0.3, 14))):
        parts.append(mk.box("Paper", (1.0, 1.3, 0.02), (x, y, 3.06 + i * 0.02), rot=(0, 0, r), mat=paper))
    parts.append(mk.cylinder("LampBase", 0.35, 0.1, (-2.4, 0.9, 3.1), mat=brass, verts=16))
    parts.append(mk.cylinder("LampArm", 0.04, 1.3, (-2.4, 0.75, 3.7), rot=(-20, 0, 0), mat=brass, verts=8))
    parts.append(mk.cylinder("LampShade", 0.5, 0.45, (-2.4, 0.35, 4.3), rot=(-35, 0, 0), mat=mk.flat("Desk_Shade",
                             srgb(20, 60, 36), 0.4), verts=16, radius2=0.18))
    glow = [
        mk.box("Screen", (1.3, 0.04, 0.9), (1.1, -0.39, 3.9), mat=mk.emissive("Desk_Glow", srgb(80, 220, 150), 3)),
        mk.sphere("Bulb", 0.14, (-2.4, 0.18, 4.12), mat=mk.emissive("Desk_Bulb", LAMP, 6), segments=10, rings=8),
    ]
    return parts, glow


@prop("OfficeChair", pivot="bottom", material="Leather", collide=True, texture=512)
def office_chair():
    leather = mk.noisy("Chair_Leather", srgb(22, 20, 22), srgb(44, 40, 42), scale=10, roughness=0.5)
    metal = mk.noisy("Chair_Metal", srgb(60, 60, 66), srgb(110, 110, 118), scale=16, roughness=0.3, metallic=1.0)
    parts = []
    for i in range(5):
        a = math.radians(i * 72)
        parts.append(mk.box("Leg", (0.14, 0.9, 0.12), (math.sin(a) * 0.45, math.cos(a) * 0.45, 0.28),
                            rot=(0, 0, -math.degrees(a)), mat=metal, bevel=0.03))
        parts.append(mk.sphere("Caster", 0.12, (math.sin(a) * 0.88, math.cos(a) * 0.88, 0.12), mat=metal,
                               segments=10, rings=6))
    parts.append(mk.cylinder("Gas", 0.09, 1.1, (0, 0, 0.85), mat=metal, verts=12))
    parts.append(mk.box("Seat", (1.8, 1.7, 0.35), (0, -0.05, 1.55), mat=leather, bevel=0.14, segments=3))
    parts.append(mk.box("Back", (1.7, 0.3, 2.0), (0, 0.8, 2.75), rot=(-8, 0, 0), mat=leather, bevel=0.14, segments=3))
    # (the back held up: a steel spine from under the seat into the back's lower half)
    parts.append(mk.tube("Spine", (0, 0.35, 1.4), (0, 0.82, 1.62), 0.07, mat=metal, verts=8))
    parts.append(mk.tube("Spine", (0, 0.82, 1.62), (0, 0.9, 2.3), 0.07, mat=metal, verts=8))
    parts.append(mk.box("SpinePlate", (0.5, 0.06, 0.7), (0, 0.98, 2.1), rot=(-8, 0, 0), mat=metal, bevel=0.02))
    for x in (-0.95, 0.95):
        parts.append(mk.box("ArmPost", (0.1, 0.1, 0.55), (x, 0.1, 1.9), mat=metal))
        parts.append(mk.box("ArmPad", (0.2, 0.9, 0.1), (x, 0.0, 2.2), mat=leather, bevel=0.04))
    return parts, []


@prop("FilingCabinet", pivot="bottom", material="Metal", collide=True, texture=512)
def filing_cabinet():
    body = mk.noisy("File_Body", srgb(70, 76, 72), srgb(100, 106, 100), scale=14, detail=12, roughness=0.5,
                    metallic=0.6)
    metal = mk.noisy("File_Metal", STEEL_B, STEEL_A, scale=18, roughness=0.3, metallic=1.0)
    label = mk.noisy("File_Label", PAPER_B, PAPER_A, scale=40, roughness=0.9)
    parts = [mk.box("Body", (2.4, 2.0, 5.0), (0, 0, 2.5), mat=body, bevel=0.06)]
    for i in range(3):
        z = 0.95 + i * 1.6
        parts.append(mk.box("Drawer", (2.2, 0.08, 1.45), (0, -1.02, z), mat=body, bevel=0.04))
        parts.append(mk.box("Handle", (0.8, 0.12, 0.12), (0, -1.1, z + 0.25), mat=metal, bevel=0.03))
        parts.append(mk.box("Label", (0.6, 0.04, 0.28), (0, -1.07, z + 0.55), mat=label))
    return parts, []


@prop("Bookshelf", pivot="bottom", material="Wood", collide=True, texture=1024)
def bookshelf():
    wood = dark_wood("Shelf_Wood")
    colours = [srgb(110, 20, 26), srgb(30, 44, 80), srgb(170, 140, 80), srgb(34, 60, 38), srgb(60, 40, 30),
               srgb(20, 20, 24), srgb(140, 130, 118)]
    books = [mk.noisy(f"Shelf_Book{i}", c, tuple(min(1.0, v * 1.4) for v in c), scale=30, roughness=0.7)
             for i, c in enumerate(colours)]
    parts = [
        mk.box("Back", (3.0, 0.1, 8.0), (0, 0.75, 4.0), mat=wood),
        mk.box("SideL", (0.15, 1.6, 8.0), (-1.45, 0, 4.0), mat=wood, bevel=0.03),
        mk.box("SideR", (0.15, 1.6, 8.0), (1.45, 0, 4.0), mat=wood, bevel=0.03),
        mk.box("Crown", (3.2, 1.75, 0.2), (0, 0, 8.0), mat=wood, bevel=0.05),
    ]
    rng = random.Random(11)
    for level in range(4):
        z = 0.2 + level * 1.95
        parts.append(mk.box("Board", (2.8, 1.5, 0.12), (0, 0, z), mat=wood, bevel=0.02))
        x = -1.3
        while x < 1.25:
            thick = rng.uniform(0.14, 0.26)
            tall = rng.uniform(1.1, 1.6)
            if rng.random() < 0.12:
                x += thick
                continue
            lean = rng.uniform(-6, 6) if rng.random() < 0.2 else 0
            parts.append(mk.box("Book", (thick, rng.uniform(0.9, 1.2), tall),
                                (x + thick / 2, -0.05, z + 0.06 + tall / 2), rot=(0, lean, 0),
                                mat=rng.choice(books), bevel=0.015))
            x += thick + 0.01
    return parts, []


@prop("VendingMachine", pivot="bottom", material="SmoothPlastic", collide=True, texture=1024)
def vending_machine():
    """A Japanese drinks machine in red: a rounded cabinet on a black plinth; behind its framed window three shelves
    of sample cans and bottles, each with its price tag and a lit button under it; the coin slot, note reader, little
    display and coin return to the right; the pick-up bay with its push flap below; a lit header and the side panels'
    vents."""
    import propkit as pk

    red = pk.paint("Vend_Body", (176, 26, 34), rough=0.35, wear=14)
    white = pk.plastic("Vend_White", (232, 230, 226))
    dark = pk.metal("Vend_Dark", (16, 16, 18), (32, 32, 36), rough=0.5, metallic=0.2)
    back = pk.plastic("Vend_Back", (200, 206, 214))
    steel = pk.metal("Vend_Steel", (120, 122, 128), (170, 172, 178), rough=0.3, metallic=0.9)
    tag = pk.plastic("Vend_Tag", (246, 244, 236))
    ink = pk.plastic("Vend_Ink", (24, 24, 28))
    tins = [pk.paint(f"Vend_Can{i}", c, rough=0.25, wear=6) for i, c in enumerate(
        ((200, 30, 36), (30, 80, 170), (236, 190, 50), (40, 140, 80), (236, 236, 232), (120, 60, 30)))]
    caps = pk.plastic("Vend_Cap", (236, 236, 232))
    fy = -1.2  # the front
    # The cabinet in five blocks round the window's opening (its back, the base under the window, the head over it,
    # a jamb on the left and the coin column on the right), so the samples stand inside it, not behind its front.
    parts = [pk.rounded("Back", (4.0, 1.85, 6.75), (0, 0.375, 3.525), red, r=0.12),
             pk.rounded("Base", (4.0, 0.7, 2.6), (0, -0.85, 1.45), red, r=0.08),
             pk.rounded("Head", (4.0, 0.7, 0.55), (0, -0.85, 6.625), red, r=0.08),
             pk.rounded("Jamb", (0.2, 0.7, 3.6), (-1.9, -0.85, 4.55), red, r=0.05),
             pk.rounded("CoinColumn", (1.0, 0.7, 3.6), (1.5, -0.85, 4.55), red, r=0.05),
             pk.rounded("Plinth", (3.9, 2.4, 0.3), (0, 0.05, 0.15), dark, r=0.04),
             mk.box("WinBack", (2.8, 0.04, 3.6), (-0.4, -0.57, 4.55), mat=back)]
    parts += pk.frame("WinFrame", 2.95, 3.7, 0.1, 0.12, (-0.4, fy - 0.02, 4.55), steel)
    # Three shelves of samples, cans and bottles by turns, a price tag and a button under each.
    for row in range(3):
        z = 3.0 + row * 1.12
        parts.append(mk.box("Shelf", (2.8, 0.6, 0.05), (-0.4, -0.85, z), mat=white))
        for col in range(5):
            x = -1.55 + col * 0.58
            mat = tins[(row * 5 + col) % len(tins)]
            if (row + col) % 2:
                parts += pk.bottle("Bottle", x, -0.85, z + 0.025, mat, caps, r=0.16, h=0.78)
            else:
                parts += pk.can("Can", x, -0.85, z + 0.025, mat, steel, r=0.16, h=0.56)
            parts.append(mk.box("Tag", (0.4, 0.04, 0.13), (x, fy + 0.03, z - 0.03), mat=tag))
            parts += pk.label("Price", "130", 0.08, (x, fy + 0.005, z - 0.03), ink)
    # The coin side: the slot, the note reader, the display, the return lever and its cup.
    parts += [pk.rounded("CoinPlate", (0.62, 0.08, 0.9), (1.55, fy - 0.03, 4.4), steel, r=0.03),
              mk.box("CoinSlot", (0.06, 0.06, 0.3), (1.55, fy - 0.08, 4.55), mat=dark),
              pk.rounded("NoteReader", (0.62, 0.12, 0.5), (1.55, fy - 0.04, 3.7), dark, r=0.04),
              mk.box("NoteSlot", (0.46, 0.06, 0.03), (1.55, fy - 0.11, 3.8), mat=steel),
              mk.box("Lever", (0.12, 0.12, 0.34), (1.55, fy - 0.1, 3.15), rot=(0, 20, 0), mat=steel),
              pk.rounded("ReturnCup", (0.5, 0.2, 0.32), (1.55, fy - 0.06, 2.6), dark, r=0.05),
              # the bay: a dark mouth across the bottom, its flap pushed in a little, PUSH on it
              mk.box("BayMouth", (2.9, 0.12, 0.95), (-0.25, fy + 0.02, 1.15), mat=dark),
              pk.rounded("Flap", (2.7, 0.06, 0.8), (-0.25, fy - 0.02, 1.15), white, r=0.02, rot=(-8, 0, 0)),
              pk.rounded("Kick", (3.9, 0.12, 0.35), (0, fy - 0.01, 0.48), dark, r=0.03)]
    parts += pk.label("Push", "PUSH", 0.13, (-0.25, fy - 0.08, 1.25), ink)
    parts += pk.label("Cold", "つめた〜い", 0.16, (-0.4, fy - 0.03, 2.62), pk.plastic("Vend_Blue", (30, 90, 200)))
    for sx in (-1, 1):
        for k in range(6):
            parts.append(mk.box("Vent", (0.04, 1.4, 0.06), (sx * 2.0, 0.2, 0.9 + k * 0.16), mat=dark))
    glows = [pk.rounded("Header", (3.7, 0.08, 0.4), (0, fy - 0.03, 6.63), pk.glow("Vend_Glow", (226, 240, 255), 3), r=0.04),
             mk.box("Display", (0.42, 0.04, 0.16), (1.55, fy - 0.08, 4.12), mat=pk.glow("Vend_Digits", (90, 255, 140), 4))]
    for row in range(3):
        for col in range(5):
            glows.append(mk.box("Button", (0.2, 0.06, 0.07), (-1.55 + col * 0.58, fy + 0.03, 3.0 + row * 1.12 - 0.12),
                                mat=pk.glow("Vend_Button", (120, 200, 255), 3)))
    parts += pk.label("Brand", "DRINK", 0.26, (0, fy - 0.08, 6.63), ink)
    return parts, glows


@prop("ServerRack", pivot="bottom", material="Metal", collide=True, texture=512)
def server_rack():
    frame = mk.noisy("Rack_Frame", srgb(20, 22, 26), srgb(40, 42, 48), scale=14, roughness=0.4, metallic=0.8)
    unit = mk.noisy("Rack_Unit", srgb(30, 32, 36), srgb(54, 56, 62), scale=20, roughness=0.4, metallic=0.6)
    parts = [mk.box("Frame", (3.0, 3.0, 8.0), (0, 0, 4.0), mat=frame, bevel=0.05)]
    for i in range(10):
        parts.append(mk.box("Unit", (2.6, 0.1, 0.6), (0, -1.5, 0.7 + i * 0.7), mat=unit, bevel=0.02))
        for v in range(8):
            parts.append(mk.box("Vent", (0.12, 0.02, 0.35), (-1.0 + v * 0.18, -1.56, 0.7 + i * 0.7), mat=frame))
    glow = []
    rng = random.Random(5)
    for i in range(10):
        for led in range(3):
            colour = (srgb(60, 255, 120), srgb(80, 170, 255), srgb(255, 170, 60))[rng.randrange(3)]
            glow.append(mk.box("Led", (0.08, 0.03, 0.08), (0.8 + led * 0.2, -1.57, 0.8 + i * 0.7),
                               mat=mk.emissive(f"Rack_Led{led}{i}", colour, 5)))
    return parts, glow


@prop("Sofa", pivot="bottom", material="Leather", collide=True, texture=1024)
def sofa():
    leather = mk.noisy("Sofa_Leather", *LEATHER_RED, scale=8, roughness=0.45)
    wood = dark_wood("Sofa_Wood")
    parts = [
        mk.box("Base", (7.0, 3.0, 1.0), (0, 0, 0.9), mat=leather, bevel=0.2, segments=3),
        mk.box("Back", (7.0, 0.8, 2.2), (0, 1.1, 2.0), mat=leather, bevel=0.3, segments=3),
    ]
    for x in (-3.3, 3.3):
        parts.append(mk.box("Arm", (0.8, 3.0, 1.8), (x, 0, 1.6), mat=leather, bevel=0.3, segments=3))
    for x in (-1.7, 0, 1.7):
        parts.append(mk.box("Cushion", (1.65, 2.2, 0.45), (x, -0.25, 1.62), mat=leather, bevel=0.18, segments=3))
    for x in (-2.4, -1.2, 0, 1.2, 2.4):
        for z in (2.2, 2.8):
            parts.append(mk.sphere("Button", 0.07, (x, 0.68, z), mat=mk.flat("Sofa_Button", DEEP_RED, 0.5),
                                   segments=8, rings=6))
    for x in (-3.3, 3.3):
        for y in (-1.2, 1.2):
            parts.append(mk.cylinder("Foot", 0.14, 0.4, (x, y, 0.2), mat=wood, verts=10, radius2=0.1))
    return parts, []


@prop("Table", pivot="bottom", material="Wood", collide=True, texture=512)
def table():
    wood = dark_wood("Table_Wood")
    parts = [mk.box("Top", (5.0, 3.0, 0.22), (0, 0, 2.64), mat=wood, bevel=0.06),
             mk.box("Apron", (4.5, 2.5, 0.35), (0, 0, 2.36), mat=wood, bevel=0.03)]
    for x in (-2.2, 2.2):
        for y in (-1.2, 1.2):
            parts.append(mk.lathe("Leg", [(0.0, 0.0), (0.12, 0.0), (0.16, 0.3), (0.1, 0.8), (0.15, 1.4),
                                          (0.12, 2.0), (0.14, 2.3), (0.0, 2.3)], (x, y, 0), mat=wood, segments=12))
    return parts, []


@prop("MeetingTable", pivot="bottom", material="Wood", collide=True, texture=1024)
def meeting_table():
    wood = mk.wood("Meet_Wood", srgb(70, 40, 28), srgb(34, 18, 12), scale=2, rings=30)
    iron = cast_iron("Meet_Iron")
    felt = mk.noisy("Meet_Felt", srgb(18, 24, 20), srgb(30, 40, 34), scale=30, roughness=1.0)
    parts = [
        mk.cylinder("Top", 13.0, 0.5, (0, 0, 3.0), mat=wood, verts=64, bevel=0.1),
        mk.cylinder("Inset", 10.5, 0.06, (0, 0, 3.26), mat=felt, verts=64),
        mk.cylinder("Rim", 13.05, 0.2, (0, 0, 2.7), mat=iron, verts=64),
        mk.cylinder("Pedestal", 2.4, 2.6, (0, 0, 1.4), mat=iron, verts=32, radius2=1.6),
        mk.cylinder("Foot", 4.0, 0.3, (0, 0, 0.15), mat=iron, verts=32, bevel=0.05),
    ]
    glow = [
        mk.torus("Ring", 11.0, 0.08, (0, 0, 3.27), mat=mk.emissive("Meet_Glow", RED, 4), major_segments=96,
                 minor_segments=6),
        mk.torus("Zero", 1.6, 0.14, (0, 0, 3.3), mat=mk.emissive("Meet_Glow", RED, 4), major_segments=48,
                 minor_segments=6),
    ]
    glow[1].scale = (0.75, 1.0, 1.0)
    return parts, glow


@prop("Chair", pivot="bottom", material="Wood", collide=True, texture=512)
def chair():
    wood = dark_wood("WChair_Wood")
    seat = mk.noisy("WChair_Seat", *LEATHER_RED, scale=10, roughness=0.5)
    parts = [mk.box("Seat", (1.8, 1.8, 0.25), (0, 0, 1.62), mat=seat, bevel=0.08)]
    for x in (-0.75, 0.75):
        for y in (-0.75, 0.75):
            tall = 3.9 if y > 0 else 1.5
            parts.append(mk.box("Leg", (0.16, 0.16, tall), (x, y, tall / 2), mat=wood, bevel=0.03))
    for z in (2.4, 3.0, 3.6):
        parts.append(mk.box("Rail", (1.5, 0.1, 0.25), (0, 0.75, z), mat=wood, bevel=0.03))
    return parts, []
