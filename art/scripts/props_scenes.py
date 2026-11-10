"""What the scene deaths' extra characters wear and carry (Core set, 2026-11-09; the user: "the extra characters look like
they have random things on their head ... make sure they look made by a human"). Before this they wore Roblox parts
welded to the head and chest (a ball for a helmet, a slab for a visor, a block for a vest). Each piece here is built
round the R6 body part it is worn on, so it sits on it instead of floating: a head 1.2 studs across with its middle at
the origin, a torso 2 x 2 x 1, an arm 1 x 2 x 1. Front to -Y, up Z. src/client/Presentation/SceneDeaths/Costumes.luau
says where each goes and how big (the game scales it to its biggest side, as EmoteProps does).

- SceneHelmet: the Walrider soldiers' ballistic helmet, cut high at the brow and the ears, rails, a mount, a strap.
- SceneVest: their plate carrier with magazine pouches.
- SceneRifle: their carbine.
- SceneCyborgHead: the blade's killer: swept-back white hair with a long tail, and the dark visor across the eyes.
- SceneMurasama, SceneRedBlade: the two katanas of "Let's dance!" (the killer's long one, the victim's red one).
- SceneWarlordHelm, SceneWarlordPlate: the Iron Man scene's warlord's ridged gold helm and chest plate.
- SceneGauntlet: the victim's armoured gauntlet over the right hand, its six stone sockets empty (the game sets each
  stone in, lit, at its moment).
- SceneSpear: the warlord's army's spear.
- SceneArcReactor: the light in the victim's chest in the Iron Man scene: a housing, a ring of ten copper coils over
  a lit ring, a lit core behind a three-spoke lattice (2026-11-10, "more accurate/detailed": it was a plain disc).
  Its lit ring and core are a piece of their own (SceneArcReactor_Light), so the game can dim them out.
- SceneWheelchair: the old man's chair among the soldiers.
Moderation: every piece reads as what it is on its own (no body parts)."""

import math

import bmesh
from mathutils import Vector

import modelkit as mk
import propkit as pk
import props
from common import srgb
from props import prop

HEAD_R = 0.62  # the R6 head's half width (the classic head mesh at 1.25)
HEAD_TOP = 0.62

# The gauntlet's stone sockets, in its own frame before the pivot shift (Blender, studs): five across the knuckles and
# one on the back of the hand. Costumes.luau holds the same points in the arm's frame for the lit stones.
GAUNTLET_SOCKETS = [(-0.36 + 0.18 * k, -0.6, -0.88) for k in range(5)] + [(0.0, -0.57, -0.44)]


def _shell(name, outer, thickness, mat, segments=48, front_cut=None, ear_cut=None):
    """A thin shell spun round Z from its outside profile [(r, z) top down], `thickness` thick; front_cut raises its rim at
    the front (-Y) to that height, ear_cut raises it over the ears (+-X) to that height."""
    inner = [(max(0.0, r - thickness), z - thickness * 0.6) for r, z in reversed(outer)]
    rim = [(outer[-1][0] - thickness * 0.5, outer[-1][1] - thickness * 0.3)]
    obj = mk.lathe(name, outer + rim + inner, mat=mat, segments=segments, caps=False)
    if front_cut is not None or ear_cut is not None:
        bm = bmesh.new()
        bm.from_mesh(obj.data)
        for v in bm.verts:
            r = math.hypot(v.co.x, v.co.y) or 1.0
            front = max(0.0, -v.co.y / r) ** 2.2
            side = max(0.0, abs(v.co.x) / r - 0.55) / 0.45
            floor = -10.0
            if front_cut is not None:
                floor = max(floor, front_cut * front + (outer[-1][1] - 1) * (1 - front))
            if ear_cut is not None:
                floor = max(floor, ear_cut * min(1.0, side) ** 1.5 + (outer[-1][1] - 1) * (1 - min(1.0, side)))
            if v.co.z < floor:
                v.co.z = floor + (v.co.z - outer[-1][1]) * 0.05
        bm.to_mesh(obj.data)
        bm.free()
    return obj


@prop("SceneHelmet", pivot="centre", material="SmoothPlastic", collide=False, texture=512)
def scene_helmet():
    """A ballistic helmet in matte black fibre, cut high over the brow and over the ears, its rim edged in rubber; a rail
    down each side, the night vision mount's shroud at the front, a hook-and-loop patch on top, the chin strap's two
    webbing straps. Built round an R6 head (its middle at the origin), front to -Y."""
    shell_m = mk.noisy("SH_Shell", srgb(20, 21, 20), srgb(44, 45, 42), scale=16, roughness=0.82, kind="plastic")
    trim_m = pk.rubber("SH_Rubber")
    rail_m = pk.metal("SH_Rail", (26, 27, 29), (60, 62, 66), rough=0.45, metallic=0.7)
    strap_m = mk.noisy("SH_Webbing", srgb(16, 16, 15), srgb(40, 40, 37), scale=60, roughness=0.92, kind="cloth")
    patch_m = mk.noisy("SH_Patch", srgb(30, 31, 28), srgb(52, 53, 48), scale=90, roughness=0.95, kind="cloth")
    r = HEAD_R + 0.09
    outer = [(0.0, 0.84), (0.26, 0.82), (0.47, 0.75), (0.61, 0.6), (r - 0.01, 0.4), (r + 0.01, 0.18), (r, 0.0),
             (r - 0.02, -0.14)]
    shell = _shell("Shell", outer, 0.06, shell_m, front_cut=0.26, ear_cut=0.02)
    parts = [shell]
    # the rubber edge along the cut rim: a band hugging the shell just above where the cut runs
    edge = []
    for k in range(65):
        a = 2 * math.pi * k / 64
        x, y = math.cos(a), math.sin(a)
        front = max(0.0, -y) ** 2.2
        side = max(0.0, abs(x) - 0.55) / 0.45
        z = max(-0.12, 0.26 * front + -0.14 * (1 - front), 0.02 * min(1.0, side) ** 1.5 + -0.14 * (1 - min(1.0, side)))
        rr = r - 0.005 + (0.012 if z > 0.15 else 0.0)
        edge.append((x * rr, y * rr, z + 0.012))
    parts.append(pk.sweep("Edge", edge, 0.028, trim_m, sides=6, caps=False))
    for side in (-1, 1):
        # the side rails, along the shell over the ear cut
        rail = mk.box("Rail", (0.06, 0.62, 0.09), (side * (r + 0.02), 0.05, 0.16), mat=rail_m, bevel=0.015)
        rail.rotation_euler = (math.radians(-4), 0, 0)
        parts.append(rail)
        for y in (-0.16, 0.06, 0.28):
            parts.append(mk.box("RailSlot", (0.065, 0.06, 0.02), (side * (r + 0.025), y, 0.16), mat=shell_m))
        # the strap from the rail's end, under the ear, to the chin
        strap = [(side * (r - 0.02), 0.16, 0.06), (side * (r - 0.04), 0.06, -0.2), (side * (r - 0.12), -0.12, -0.46),
                 (side * 0.34, -0.38, -0.62), (side * 0.12, -0.5, -0.68), (0.0, -0.52, -0.69)]
        parts.append(pk.sweep("Strap", strap, 0.03, strap_m, sides=6))
    # the buckle under the chin
    parts.append(mk.box("Buckle", (0.16, 0.06, 0.08), (0.0, -0.52, -0.69), mat=rail_m, bevel=0.015))
    # the mount's shroud on the front, standing a little off the shell, and its bolts
    shroud = pk.rounded("Shroud", (0.34, 0.08, 0.2), (0.0, -(r - 0.02) * math.cos(math.radians(28)), 0.44), rail_m,
                        r=0.03)
    shroud.rotation_euler = (math.radians(-28), 0, 0)
    parts.append(shroud)
    parts.append(mk.box("ShroudPlate", (0.18, 0.04, 0.12), (0.0, -(r + 0.025) * math.cos(math.radians(28)), 0.45),
                        rot=(-28, 0, 0), mat=shell_m, bevel=0.01))
    # the patch on top, a little back
    patch = mk.box("Patch", (0.34, 0.28, 0.02), (0.0, 0.16, 0.81), rot=(10, 0, 0), mat=patch_m, bevel=0.008)
    parts.append(patch)
    return parts, []


@prop("SceneVest", pivot="centre", material="Fabric", collide=False, texture=512)
def scene_vest():
    """A plate carrier over the chest and back in black cordura: the front and back plates' bags joined by shoulder
    straps and side cummerbunds, three rifle magazine pouches across the front with their flaps, a radio pouch at the
    left. Round an R6 torso (2 x 2 x 1, its middle at the origin), front to -Y."""
    cloth = mk.noisy("SV_Cordura", srgb(18, 18, 17), srgb(42, 42, 39), scale=70, roughness=0.92, kind="cloth")
    web = mk.noisy("SV_Webbing", srgb(26, 26, 24), srgb(50, 50, 46), scale=90, roughness=0.95, kind="cloth")
    clip = pk.metal("SV_Clip", (22, 22, 24), (52, 54, 58), rough=0.5, metallic=0.5)
    parts = []
    for side, y in ((-1, -0.56), (1, 0.56)):
        # the plate bags, standing off the chest and back
        parts.append(pk.rounded("Plate", (1.62, 0.16, 1.38), (0.0, y, 0.12), cloth, r=0.06))
    for x in (-0.62, 0.62):
        # shoulder straps over the top, padded
        parts.append(pk.sweep("Shoulder", [(x, -0.62, 0.74), (x, -0.44, 1.02), (x, 0.0, 1.08), (x, 0.44, 1.02),
                                           (x, 0.62, 0.74)], 0.1, web, sides=8))
    for side in (-1, 1):
        # the cummerbund round each side
        parts.append(pk.rounded("Cummerbund", (0.14, 1.18, 0.62), (side * 1.06, 0.0, -0.24), web, r=0.05))
    for k, x in enumerate((-0.46, 0.0, 0.46)):
        # magazine pouches, each with its flap and a pull tab
        parts.append(pk.rounded("Pouch", (0.38, 0.22, 0.6), (x, -0.74, -0.08), cloth, r=0.05))
        parts.append(pk.rounded("Flap", (0.4, 0.24, 0.12), (x, -0.75, 0.24), web, r=0.03))
        parts.append(mk.box("Tab", (0.1, 0.03, 0.12), (x, -0.87, 0.18), mat=web, bevel=0.01))
    # a radio pouch high on the left chest and its antenna stub
    parts.append(pk.rounded("Radio", (0.3, 0.2, 0.38), (0.56, -0.72, 0.56), cloth, r=0.05))
    parts.append(mk.cylinder("Antenna", 0.025, 0.4, (0.64, -0.7, 0.92), mat=clip, verts=8))
    # buckles at the cummerbund's front
    for side in (-1, 1):
        parts.append(mk.box("Buckle", (0.1, 0.06, 0.16), (side * 0.86, -0.62, -0.26), mat=clip, bevel=0.01))
    return parts, []


@prop("SceneRifle", pivot="centre", material="Metal", collide=False, texture=512)
def scene_rifle():
    """A short carbine in black: the receiver, a free-floating rail guard, the barrel and its flash hider, a curved
    magazine, the pistol grip, an adjustable stock on its buffer tube, a small sight on top. Along Y, the muzzle to -Y,
    the grip down."""
    black = pk.metal("SR_Black", (16, 17, 19), (40, 42, 46), rough=0.5, metallic=0.6, scale=30)
    poly = mk.noisy("SR_Polymer", srgb(18, 18, 18), srgb(34, 34, 33), scale=40, roughness=0.75, kind="plastic")
    steel = pk.metal("SR_Steel", (40, 42, 46), (80, 84, 90), rough=0.3, metallic=0.9)
    glass = pk.dark_glass("SR_Lens", tint=(20, 30, 40))
    parts = [
        pk.rounded("Receiver", (0.2, 0.92, 0.3), (0.0, 0.1, 0.0), black, r=0.03),
        pk.rounded("Guard", (0.19, 0.86, 0.22), (0.0, -0.78, 0.03), black, r=0.04),
        mk.box("GuardRail", (0.1, 0.84, 0.04), (0.0, -0.78, 0.16), mat=steel, bevel=0.008),
        mk.cylinder("Barrel", 0.045, 0.62, (0.0, -1.48, 0.04), rot=(90, 0, 0), mat=steel, verts=16),
        mk.cylinder("Hider", 0.06, 0.18, (0.0, -1.84, 0.04), rot=(90, 0, 0), mat=black, verts=16, bevel=0.01),
        mk.box("TopRail", (0.1, 0.88, 0.04), (0.0, 0.08, 0.17), mat=steel, bevel=0.008),
        mk.cylinder("Buffer", 0.06, 0.62, (0.0, 0.84, 0.02), rot=(90, 0, 0), mat=black, verts=16),
        pk.rounded("Stock", (0.16, 0.4, 0.3), (0.0, 1.12, -0.02), poly, r=0.05),
        pk.rounded("ButtPad", (0.17, 0.05, 0.34), (0.0, 1.33, -0.04), pk.rubber("SR_Rubber"), r=0.02),
    ]
    # the magazine: a curved box under the receiver, front edge forward
    mag = mk.box("Magazine", (0.14, 0.24, 0.52), (0.0, -0.12, -0.36), mat=poly, bevel=0.02)
    bm = bmesh.new()
    bm.from_mesh(mag.data)
    for v in bm.verts:
        v.co.y -= 0.3 * max(0.0, -v.co.z) ** 2
    bm.to_mesh(mag.data)
    bm.free()
    mag.rotation_euler = (math.radians(8), 0, 0)
    parts.append(mag)
    grip = pk.rounded("Grip", (0.14, 0.18, 0.4), (0.0, 0.32, -0.3), poly, r=0.04)
    grip.rotation_euler = (math.radians(-18), 0, 0)
    parts.append(grip)
    parts.append(mk.torus("TriggerGuard", 0.1, 0.018, (0.0, 0.16, -0.2), rot=(0, 90, 0), mat=black,
                          major_segments=16, minor_segments=6))
    # the sight: a short tube on its mount, lens front and back
    parts.append(mk.box("SightMount", (0.08, 0.16, 0.06), (0.0, 0.02, 0.22), mat=black, bevel=0.01))
    parts.append(mk.cylinder("Sight", 0.07, 0.3, (0.0, 0.02, 0.3), rot=(90, 0, 0), mat=black, verts=20, bevel=0.01))
    for y in (-0.135, 0.135):
        parts.append(mk.cylinder("SightLens", 0.055, 0.01, (0.0, 0.02 + y, 0.3), rot=(90, 0, 0), mat=glass, verts=20))
    return parts, []


@prop("SceneCyborgHead", pivot="centre", material="SmoothPlastic", collide=False, texture=512)
def scene_cyborg_head():
    """The blade's killer's head: white hair swept straight back off the brow in thick locks, gathered at the back of
    the head into a long tail falling down the back; a dark visor band across the eyes from temple to temple, a thin
    red line along it. Round an R6 head (its middle at the origin), front to -Y."""
    hair_m = mk.noisy("CH_Hair", srgb(206, 206, 210), srgb(244, 244, 246), scale=30, roughness=0.55,
                      stretch=(1, 4, 1), kind="cloth")
    visor_m = pk.dark_glass("CH_Visor", tint=(16, 18, 24))
    line_m = pk.glow("CH_Line", (230, 40, 40), strength=3.0)
    frame_m = pk.metal("CH_Frame", (60, 62, 68), (110, 114, 122), rough=0.35, metallic=0.85)
    r = HEAD_R + 0.04
    # the cap of hair over the top of the head, swept back: a shell cut at the brow, longer at the back, its back edge
    # breaking into points where the hair falls
    outer = [(0.0, 0.76), (0.3, 0.74), (0.5, 0.64), (0.62, 0.46), (r, 0.24), (r - 0.01, 0.02), (r - 0.04, -0.22)]
    cap = _shell("Cap", outer, 0.05, hair_m, front_cut=0.38, ear_cut=0.16)
    bm = bmesh.new()
    bm.from_mesh(cap.data)
    for v in bm.verts:
        a = math.atan2(v.co.y, v.co.x)
        back = max(0.0, math.sin(a))  # 1 at the back (+Y)
        # the hair swept back: the cap fuller over the crown and behind, flat at the brow
        v.co.y += 0.06 * back * max(0.0, v.co.z + 0.2)
        if v.co.z < 0.0:
            # points along the back edge: the locks' ends
            v.co.z -= 0.12 * back * (0.5 + 0.5 * math.cos(a * 9))
    bm.to_mesh(cap.data)
    bm.free()
    parts = [cap]
    # a few thick locks swept from the brow back over the crown, lying on the cap (each just over its surface)
    def over_cap(x, y):
        rr = math.hypot(x, y)
        if rr >= r:
            return 0.24
        # (the cap's outside height at that distance from the middle, from its profile)
        pts = list(reversed(outer[:5]))
        for (r0, z0), (r1, z1) in zip(pts, pts[1:]):
            if r1 <= rr <= r0:
                u = (rr - r1) / max(1e-6, r0 - r1)
                return z1 + (z0 - z1) * u
        return outer[0][1]

    for k, x in enumerate((-0.36, -0.18, 0.0, 0.18, 0.36)):
        pts = []
        for s in range(8):
            u = s / 7
            y = -0.42 + u * 0.98
            xx = x * (1.0 + 0.25 * u)
            pts.append((xx, y + 0.06 * u * u, over_cap(xx, y) + 0.04 - 0.02 * u))
        parts.append(pk.sweep("Lock", pts, [0.075 - 0.04 * (s / 7) for s in range(8)], hair_m, sides=6))
    # the tail: gathered at the back, a band, then falling down the back in a long taper
    tail = [(0.0, 0.62, 0.1), (0.0, 0.74, -0.1), (0.0, 0.82, -0.45), (0.0, 0.84, -0.85), (0.02, 0.82, -1.25),
            (0.04, 0.78, -1.6)]
    parts.append(pk.sweep("Tail", tail, [0.16, 0.15, 0.13, 0.11, 0.08, 0.03], hair_m, sides=10))
    parts.append(mk.torus("TailBand", 0.15, 0.03, (0.0, 0.7, -0.02), rot=(78, 0, 0), mat=frame_m, major_segments=20,
                          minor_segments=6))
    # the visor: a band of dark glass curving round the front of the head at the eyes, its frame ends at the temples
    visor = []
    for k in range(25):
        a = math.radians(-160 + 140 * k / 24)
        visor.append((math.cos(a) * (r + 0.02), math.sin(a) * (r + 0.02), 0.1))
    parts.append(pk.sweep("Visor", visor, 0.09, visor_m, sides=8))
    line = [(x, y, z + 0.075) for x, y, z in visor]
    parts.append(pk.sweep("VisorLine", line, 0.012, line_m, sides=4))
    for side in (-1, 1):
        parts.append(mk.cylinder("Temple", 0.08, 0.08, (side * (r + 0.03), -0.18, 0.1), rot=(0, 90, 0), mat=frame_m,
                                 verts=16, bevel=0.01))
    return parts, []


def _katana(name, length, blade_m, edge_m, guard_m, wrap_m, tip_glow=None):
    """A katana along -Y from the grip's end: the wrapped handle, the guard, a long curved blade, its edge along the
    curve's inside; the grip at the origin end."""
    handle = 0.62
    parts = [mk.cylinder(name + "Handle", 0.06, handle, (0.0, -handle / 2, 0.0), rot=(90, 0, 0), mat=wrap_m, verts=12)]
    for k in range(6):
        parts.append(mk.torus(name + "Wrap", 0.062, 0.012, (0.0, -0.06 - k * 0.1, 0.0), rot=(90, 0, 0), mat=guard_m,
                              major_segments=12, minor_segments=4))
    parts.append(mk.cylinder(name + "Pommel", 0.07, 0.05, (0.0, 0.0, 0.0), rot=(90, 0, 0), mat=guard_m, verts=16,
                             bevel=0.01))
    guard = mk.cylinder(name + "Guard", 0.16, 0.04, (0.0, -handle - 0.02, 0.0), rot=(90, 0, 0), mat=guard_m, verts=8,
                        bevel=0.01)
    guard.scale = (0.8, 1.0, 1.1)
    parts.append(guard)
    # the blade: a thin lens section drawn along a gentle curve (the back up, +Z), tapering to the point
    bm = bmesh.new()
    steps = 24
    rings = []
    for s in range(steps + 1):
        u = s / steps
        y = -handle - 0.06 - u * length
        z = 0.12 * u * u
        width = 0.09 * (1 - 0.35 * u) if u < 0.94 else 0.09 * 0.65 * (1 - (u - 0.94) / 0.06)
        thick = 0.018 * (1 - 0.5 * u)
        ring = [bm.verts.new((0.0, y, z + width)), bm.verts.new((thick, y, z + width * 0.2)),
                bm.verts.new((0.0, y, z - width)), bm.verts.new((-thick, y, z + width * 0.2))]
        rings.append(ring)
    for s in range(steps):
        for j in range(4):
            bm.faces.new((rings[s][j], rings[s + 1][j], rings[s + 1][(j + 1) % 4], rings[s][(j + 1) % 4]))
    bm.faces.new(list(reversed(rings[0])))
    bm.faces.new(rings[-1])
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    blade = mk._obj_from_bm(name + "Blade", bm, blade_m)
    parts.append(blade)
    # the edge: a thin bright line along the underside of the curve
    edge = []
    for s in range(steps + 1):
        u = s / steps
        width = 0.09 * (1 - 0.35 * u) if u < 0.94 else 0.09 * 0.65 * (1 - (u - 0.94) / 0.06)
        edge.append((0.0, -handle - 0.06 - u * length, 0.12 * u * u - width * 0.92))
    parts.append(pk.sweep(name + "Edge", edge, [0.012] * (steps + 1), edge_m, sides=4))
    return parts


@prop("SceneMurasama", pivot="centre", material="Metal", collide=False, texture=512)
def scene_murasama():
    """The killer's long katana: a bright steel blade with a red glow along its edge, a black wrapped handle, a dark
    guard. Along -Y from the grip's end."""
    blade = pk.metal("SM_Blade", (150, 154, 162), (214, 218, 226), rough=0.18, metallic=0.95, scale=40)
    edge = pk.glow("SM_Edge", (255, 40, 30), strength=4.0)
    guard = pk.metal("SM_Guard", (24, 22, 22), (60, 56, 54), rough=0.4, metallic=0.8)
    wrap = mk.noisy("SM_Wrap", srgb(14, 14, 16), srgb(34, 30, 32), scale=60, roughness=0.9, kind="cloth")
    return _katana("M", 3.4, blade, edge, guard, wrap), []


@prop("SceneRedBlade", pivot="centre", material="Metal", collide=False, texture=512)
def scene_red_blade():
    """The victim's sword in "Let's dance!": a katana with a deep red blade and a bright red edge, a red wrapped handle
    and a black guard. Along -Y from the grip's end."""
    blade = pk.metal("SB_Blade", (90, 14, 18), (150, 30, 34), rough=0.25, metallic=0.85, scale=40)
    edge = pk.glow("SB_Edge", (255, 70, 60), strength=2.0)
    guard = pk.metal("SB_Guard", (20, 18, 18), (50, 46, 44), rough=0.4, metallic=0.8)
    wrap = mk.noisy("SB_Wrap", srgb(90, 14, 16), srgb(140, 26, 28), scale=60, roughness=0.85, kind="cloth")
    return _katana("R", 2.8, blade, edge, guard, wrap), []


@prop("SceneWarlordHelm", pivot="centre", material="Metal", collide=False, texture=512)
def scene_warlord_helm():
    """The warlord's helm in tarnished gold: a closed crown over the head, a raised ridge from the brow over the top, a
    flared crest at each side like folded wings, the brow band low over the eyes, the cheeks guarded down to the jaw.
    Round an R6 head (its middle at the origin), front to -Y."""
    gold = pk.metal("WH_Gold", (140, 104, 40), (210, 166, 80), rough=0.35, metallic=0.9, scale=22)
    dark = pk.metal("WH_Dark", (60, 44, 22), (100, 76, 40), rough=0.45, metallic=0.85, scale=22)
    r = HEAD_R + 0.07
    outer = [(0.0, 0.86), (0.3, 0.83), (0.5, 0.72), (0.63, 0.52), (r, 0.28), (r + 0.02, 0.0), (r, -0.3),
             (r - 0.06, -0.52)]
    crown = _shell("Crown", outer, 0.06, gold, front_cut=0.16)
    parts = [crown]
    # the ridge over the top from the brow to the nape, in the middle, standing on the shell
    ridge = []
    for k in range(15):
        a = math.radians(15 + 150 * k / 14)  # from the brow (front, -Y) over the top to the nape
        ridge.append((0.0, -math.cos(a) * (r + 0.03), 0.28 + math.sin(a) * (0.86 - 0.28 + 0.03)))
    parts.append(pk.sweep("Ridge", ridge, [0.05 + 0.04 * math.sin(math.pi * k / 14) for k in range(15)], dark,
                          sides=6))
    # the brow band, low over the eyes
    band = []
    for k in range(25):
        a = math.radians(-170 + 160 * k / 24)
        band.append((math.cos(a) * (r + 0.02), math.sin(a) * (r + 0.02), 0.2))
    parts.append(pk.sweep("Brow", band, 0.05, dark, sides=6))
    for side in (-1, 1):
        # the crests: three blades fanning up and back from the temple
        for k, (lift, back, length) in enumerate(((0.15, 0.0, 0.62), (0.3, 0.12, 0.52), (0.45, 0.22, 0.4))):
            base = Vector((side * (r + 0.02), -0.05 + back, 0.3 + lift * 0.4))
            tip = base + Vector((side * 0.28, 0.28 + back, length))
            parts.append(pk.sweep("Crest", [tuple(base), tuple(base.lerp(tip, 0.5) + Vector((side * 0.04, 0, 0))),
                                            tuple(tip)], [0.06, 0.045, 0.012], gold, sides=4))
        # the cheek guard down to the jaw
        parts.append(pk.rounded("Cheek", (0.08, 0.42, 0.5), (side * (r - 0.02), -0.22, -0.32), dark, r=0.03))
    return parts, []


@prop("SceneWarlordPlate", pivot="centre", material="Metal", collide=False, texture=512)
def scene_warlord_plate():
    """The warlord's chest plate in tarnished gold over a dark collar: a breastplate with a ridge down the middle, a
    pauldron rounded over each shoulder in three lames. Round an R6 torso (2 x 2 x 1, its middle at the origin)."""
    gold = pk.metal("WP_Gold", (140, 104, 40), (210, 166, 80), rough=0.35, metallic=0.9, scale=22)
    dark = pk.metal("WP_Dark", (52, 38, 20), (96, 72, 38), rough=0.45, metallic=0.85, scale=22)
    parts = [pk.rounded("Breast", (1.9, 0.18, 1.3), (0.0, -0.56, 0.3), gold, r=0.08),
             pk.rounded("Back", (1.9, 0.14, 1.3), (0.0, 0.56, 0.3), dark, r=0.06),
             mk.box("Ridge", (0.08, 0.08, 1.2), (0.0, -0.68, 0.3), mat=dark, bevel=0.02),
             pk.rounded("Collar", (1.2, 1.2, 0.18), (0.0, 0.0, 1.02), dark, r=0.08)]
    for side in (-1, 1):
        # (over the arm's shoulder: the R6 arm hangs 1.0-2.0 out from the middle)
        for k in range(3):
            pauldron = mk.sphere("Pauldron", 0.6 - 0.07 * k, (side * (1.42 + 0.05 * k), 0.0, 0.92 - 0.2 * k),
                                 scale=(1.0, 1.0, 0.55), mat=gold if k % 2 == 0 else dark, segments=24, rings=12)
            parts.append(pauldron)
    return parts, []


@prop("SceneGauntlet", pivot="centre", material="Metal", collide=False, texture=512)
def scene_gauntlet():
    """An armoured gauntlet over the right hand and forearm in red and gold: a gold cuff, red plates down the back of the
    hand, gold knuckle caps; six empty round sockets (five across the knuckles, one on the back of the hand) for the
    stones the game sets in. Round the lower half of an R6 arm (1 x 2 x 1, the arm's middle at the origin, its hand
    end down at -1), the back of the hand to -Y."""
    red = pk.paint("SG_Red", (150, 22, 26), rough=0.35, wear=10)
    gold = pk.metal("SG_Gold", (168, 126, 50), (226, 186, 96), rough=0.3, metallic=0.9, scale=22)
    socket = pk.metal("SG_Socket", (40, 30, 16), (80, 62, 32), rough=0.5, metallic=0.8)
    parts = [pk.rounded("Cuff", (1.1, 1.1, 0.34), (0.0, 0.0, -0.1), gold, r=0.08),
             pk.rounded("Forearm", (1.06, 1.06, 0.5), (0.0, 0.0, -0.48), red, r=0.1),
             pk.rounded("Hand", (1.08, 1.08, 0.4), (0.0, 0.0, -0.84), red, r=0.1)]
    for k in range(5):
        x, sy, sz = GAUNTLET_SOCKETS[k]
        # a gold cap over each knuckle, the socket set in its face
        parts.append(pk.rounded("Knuckle", (0.16, 0.1, 0.16), (x, -0.55, sz), gold, r=0.035))
        parts.append(mk.cylinder("Socket", 0.055, 0.03, (x, sy + 0.005, sz), rot=(90, 0, 0), mat=socket, verts=16))
    parts.append(mk.cylinder("BackSocketRim", 0.11, 0.05, (0.0, -0.53, -0.44), rot=(90, 0, 0), mat=gold, verts=24,
                             bevel=0.01))
    parts.append(mk.cylinder("BackSocket", 0.08, 0.06, GAUNTLET_SOCKETS[5], rot=(90, 0, 0), mat=socket, verts=24))
    # gold ribs along the back of the forearm
    for x in (-0.3, 0.3):
        parts.append(pk.rounded("Rib", (0.08, 0.06, 0.5), (x, -0.54, -0.5), gold, r=0.02))
    return parts, []


@prop("SceneSpear", pivot="centre", material="Metal", collide=False, texture=256)
def scene_spear():
    """The army's spear: a dark iron head with a long leaf blade and a cross bar under it, on a long black shaft bound
    with cord where the hand holds it. Along Z, the point up."""
    iron = pk.metal("SS_Iron", (40, 40, 44), (86, 86, 92), rough=0.35, metallic=0.85)
    shaft_m = mk.noisy("SS_Shaft", srgb(22, 18, 16), srgb(44, 36, 30), scale=30, roughness=0.7, kind="wood")
    cord = mk.noisy("SS_Cord", srgb(50, 30, 22), srgb(86, 56, 40), scale=80, roughness=0.9, kind="cloth")
    parts = [mk.cylinder("Shaft", 0.05, 5.2, (0.0, 0.0, 0.0), mat=shaft_m, verts=10),
             mk.cylinder("Grip", 0.065, 0.7, (0.0, 0.0, -0.4), mat=cord, verts=10),
             mk.cylinder("Socket", 0.07, 0.3, (0.0, 0.0, 2.7), mat=iron, verts=10, radius2=0.05),
             mk.box("Cross", (0.5, 0.06, 0.06), (0.0, 0.0, 2.88), mat=iron, bevel=0.015)]
    leaf = mk.extrude_shape("Blade", [(0.0, 0.0), (0.13, 0.25), (0.11, 0.6), (0.0, 0.9), (-0.11, 0.6), (-0.13, 0.25)],
                            0.035, (0.0, 0.017, 2.9), rot=(90, 0, 0), mat=iron, bevel=0.01)
    parts.append(leaf)
    parts.append(mk.cylinder("Butt", 0.06, 0.15, (0.0, 0.0, -2.6), mat=iron, verts=10))
    return parts, []


@prop("SceneWheelchair", pivot="bottom", material="Metal", collide=False, texture=512)
def scene_wheelchair():
    """An old steel hospital wheelchair: a tube frame, a sagging black seat and back, two large spoked wheels with
    push rims, two small castors in front, footrests. Seat at about 1.9 studs (an R6 body sits on it), facing -Y."""
    steel = pk.metal("WC_Steel", (120, 124, 130), (180, 184, 190), rough=0.3, metallic=0.9)
    vinyl = mk.noisy("WC_Vinyl", srgb(16, 16, 18), srgb(36, 36, 38), scale=20, roughness=0.6, kind="leather")
    tyre = pk.rubber("WC_Tyre")
    parts = [pk.rounded("Seat", (1.9, 1.7, 0.12), (0.0, 0.0, 1.9), vinyl, r=0.04),
             pk.rounded("Back", (1.9, 0.1, 1.4), (0.0, 0.9, 2.7), vinyl, r=0.04)]
    for side in (-1, 1):
        x = side * 1.02
        frame = [(x, -0.8, 1.86), (x, 0.88, 1.86), (x, 0.96, 3.5), (x, 1.2, 3.62)]
        parts.append(pk.sweep("Frame", frame, 0.045, steel, sides=8))
        parts.append(pk.sweep("Leg", [(x, -0.8, 1.86), (x, -0.95, 0.5), (x, -1.2, 0.36)], 0.04, steel, sides=8))
        parts.append(mk.box("Footrest", (0.6, 0.4, 0.05), (side * 0.5, -1.3, 0.38), mat=steel, bevel=0.01))
        # the big wheel at the back, its push rim, spokes
        wy, wz, wr = 0.35, 1.05, 1.05
        parts.append(mk.torus("Tyre", wr, 0.06, (side * 1.15, wy, wz), rot=(0, 90, 0), mat=tyre, major_segments=36,
                              minor_segments=8))
        parts.append(mk.torus("PushRim", wr - 0.12, 0.025, (side * 1.24, wy, wz), rot=(0, 90, 0), mat=steel,
                              major_segments=36, minor_segments=6))
        for k in range(12):
            a = 2 * math.pi * k / 12
            parts.append(mk.tube("Spoke", (side * 1.15, wy, wz),
                                 (side * 1.15, wy + math.cos(a) * (wr - 0.05), wz + math.sin(a) * (wr - 0.05)), 0.008,
                                 mat=steel, verts=4))
        parts.append(mk.cylinder("Hub", 0.08, 0.16, (side * 1.15, wy, wz), rot=(0, 90, 0), mat=steel, verts=12))
        # the castor in front
        parts.append(mk.torus("Castor", 0.22, 0.05, (x, -1.2, 0.27), rot=(0, 90, 0), mat=tyre, major_segments=20,
                              minor_segments=6))
    parts.append(pk.sweep("Cross", [(-1.02, 0.2, 1.86), (1.02, 0.2, 1.86)], 0.04, steel, sides=8))
    return parts, []


@prop("SceneArcReactor", pivot="centre", material="Metal", collide=False, texture=256)
def scene_arc_reactor():
    """The chest light of the Iron Man scene, on the front of an R6 torso (2 x 2 x 1, its middle at the origin, its
    front face at y -0.5), front to -Y: a dark round housing with three bolted lugs, a steel bezel, a LIT RING under
    ten copper coils set round it like a clock's hours, a steel inner ring, a LIT CORE behind a three-spoke lattice
    with a hub. The lit ring and core are the piece "Light" (unbaked: the game makes it neon and dims it out)."""
    steel = pk.metal("AR_Steel", (120, 126, 134), (186, 192, 200), rough=0.3, metallic=0.9, scale=26)
    dark = pk.metal("AR_Dark", (30, 32, 38), (58, 62, 70), rough=0.45, metallic=0.85, scale=26)
    copper = pk.metal("AR_Copper", (150, 84, 40), (214, 138, 78), rough=0.35, metallic=0.9, scale=30)
    lit = pk.glow("AR_Lit", (170, 228, 255), 5.0)
    z0 = 0.35  # the reactor's middle, up the chest
    face = -0.5

    def y(depth):
        return face - depth

    parts = [mk.cylinder("Housing", 0.3, 0.07, (0.0, y(0.035), z0), rot=(90, 0, 0), mat=dark, verts=40, bevel=0.012),
             mk.torus("Bezel", 0.275, 0.026, (0.0, y(0.07), z0), rot=(90, 0, 0), mat=steel, major_segments=40,
                      minor_segments=8),
             mk.torus("Inner", 0.112, 0.018, (0.0, y(0.085), z0), rot=(90, 0, 0), mat=steel, major_segments=32,
                      minor_segments=8),
             mk.cylinder("Hub", 0.032, 0.03, (0.0, y(0.1), z0), rot=(90, 0, 0), mat=steel, verts=16, bevel=0.006)]
    light = [mk.torus("Ring", 0.196, 0.036, (0.0, y(0.066), z0), rot=(90, 0, 0), mat=lit, major_segments=40,
                      minor_segments=8),
             mk.cylinder("Core", 0.1, 0.02, (0.0, y(0.076), z0), rot=(90, 0, 0), mat=lit, verts=32)]
    # ten coils over the lit ring: a copper winding with a dark clamp across its middle
    for k in range(10):
        a = math.radians(36 * k + 18)
        c, sn = math.cos(a), math.sin(a)
        at = (c * 0.196, y(0.078), z0 + sn * 0.196)
        turn = (0, -math.degrees(a), 0)
        parts.append(pk.rounded("Coil", (0.1, 0.052, 0.062), at, copper, r=0.016, rot=turn))
        parts.append(mk.box("Clamp", (0.022, 0.058, 0.07), at, rot=turn, mat=dark, bevel=0.004))
    # the lattice over the core: three spokes from the hub to the inner ring
    for k in range(3):
        a = math.radians(120 * k + 90)
        c, sn = math.cos(a), math.sin(a)
        parts.append(mk.box("Spoke", (0.1, 0.014, 0.018), (c * 0.062, y(0.096), z0 + sn * 0.062),
                            rot=(0, -math.degrees(a), 0), mat=steel, bevel=0.003))
    # three lugs bolting the housing down
    for k in range(3):
        a = math.radians(120 * k + 30)
        c, sn = math.cos(a), math.sin(a)
        parts.append(pk.rounded("Lug", (0.09, 0.03, 0.07), (c * 0.31, y(0.02), z0 + sn * 0.31), dark, r=0.012,
                                rot=(0, -math.degrees(a), 0)))
        parts.append(mk.cylinder("Bolt", 0.016, 0.02, (c * 0.325, y(0.04), z0 + sn * 0.325), rot=(90, 0, 0),
                                 mat=steel, verts=6))
    return parts, [], {"pieces": {"Light": props.piece(light, bake=False)}}
