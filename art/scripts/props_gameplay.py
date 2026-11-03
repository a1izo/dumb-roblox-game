"""Gameplay objects (see props.py). These dress existing gameplay parts, which keep their tags,
prompts and collisions: the part turns invisible and the mesh sits exactly where it was."""

import math
import random

import bmesh
import bpy
from mathutils import Vector

import modelkit as mk
import propkit as pk
from common import srgb
import props
from props import PAPER_A, PAPER_B, RED, prop
from props_world import dark_wood


@prop("Station", pivot="bottom", material="Metal", collide=False, texture=1024)
def station():
    """A case-file console, the standard station: a grey steel desk with its drawer pedestal, the
    terminal's processor unit on it (two disk slots, its lamps, a vent), the deep CRT housing round
    the game's screen part (which stands 4.4 by 2.6 at the console's middle, 0.8 back), a keyboard,
    a desk phone, a tray of case folders and a cup of pens. It is placed by its footprint's middle,
    so it stays as deep in front as behind (a foot rail at the front, the cable tray at the back)."""
    import stationkit as sk

    rng = random.Random(11)
    steel = pk.paint("Stat_Steel", (88, 90, 96), rough=0.45)
    top = pk.plastic("Stat_Resin", (60, 62, 66), rough=0.5)
    trim = pk.metal("Stat_Trim", (30, 30, 34), (48, 48, 52), rough=0.4, metallic=0.5)
    beige = pk.plastic("Stat_Plastic", (182, 174, 156))
    bezel = pk.plastic("Stat_Bezel", (66, 64, 60))
    dark = pk.plastic("Stat_Dark", (22, 22, 24))
    key = pk.plastic("Stat_Button", (210, 204, 188))
    paper = mk.noisy("Stat_Paper", PAPER_B, PAPER_A, scale=30, roughness=0.9)
    folder = mk.noisy("Stat_Folder", srgb(168, 136, 86), srgb(196, 164, 110), roughness=0.8)
    label = mk.noisy("Stat_Label", PAPER_B, PAPER_A, scale=30, roughness=0.9)
    ink = mk.flat("Stat_Ink", srgb(26, 24, 30), 0.6)
    parts = sk.steel_desk("Stat_", top, steel, trim, w=5.2, d=2.6, h=2.95, pedestal=1.5)
    parts += [mk.tube("FootRail", (-2.45, -1.58, 0.3), (2.45, -1.58, 0.3), 0.045, mat=trim, verts=10),
              mk.box("CableTray", (4.6, 0.05, 0.5), (0, 1.6, 2.4), mat=trim),
              mk.box("TrayLip", (4.6, 0.3, 0.04), (0, 1.47, 2.17), mat=trim)]
    for sx in (-1, 1):
        parts.append(mk.box("RailStay", (0.08, 0.3, 0.08), (sx * 2.45, -1.45, 0.3), mat=trim))
    # The processor unit under the monitor.
    parts += [pk.rounded("Unit", (3.6, 1.2, 0.6), (0, 1.0, 3.25), beige, r=0.05),
              mk.box("Drive", (0.9, 0.02, 0.16), (-1.0, 0.395, 3.3), mat=dark),
              mk.box("Drive", (0.9, 0.02, 0.16), (0.1, 0.395, 3.3), mat=dark),
              mk.box("DriveLatch", (0.12, 0.03, 0.06), (-0.45, 0.385, 3.22), mat=key),
              mk.box("DriveLatch", (0.12, 0.03, 0.06), (0.65, 0.385, 3.22), mat=key)]
    parts += pk.louvres("UnitVent", 1.3, 0.395, 3.25, 0.7, 0.36, bezel, count=5)
    glows = [mk.box("Power", (0.08, 0.02, 0.05), (-1.5, 0.39, 3.1), mat=mk.emissive("Stat_Led", srgb(80, 255, 140), 5)),
             mk.box("DiskLed", (0.06, 0.02, 0.04), (-0.2, 0.39, 3.1), mat=mk.emissive("Stat_Disk", srgb(255, 170, 60), 4))]
    # The CRT housing round the game's screen (a 0.3-deep part, its face 0.65 back).
    term, led = sk.crt("Term_", (0, 0.75, 5.4, 4.4, 2.6, 0), beige, bezel, dark, depth=0.7, base_to=3.55, border=0.25, chin=0.14)
    parts += term
    glows += led
    parts += pk.label("Badge", "警視庁 記録照会", 0.07, (-1.6, 0.592, 3.94), ink)
    parts.append(sk.cable("UnitCable", [(1.6, 1.55, 3.2), (1.9, 1.58, 2.8), (2.0, 1.58, 0.5)], dark, r=0.04))
    # Keyboard, phone, folders, pens, a label on the pedestal.
    parts += sk.keyboard("Kb_", -0.2, -0.75, 2.95, beige, key, w=2.2, d=0.72)
    ph, lines = sk.desk_phone("Ph_", 1.8, -0.5, 2.95, dark, key, dark, yaw=-12, lines=3)
    parts += ph
    glows += lines
    parts += [mk.box("Tray", (1.0, 1.3, 0.05), (-2.0, -0.35, 2.975), mat=trim, bevel=0.01)]
    for sx in (-1, 1):
        parts.append(mk.box("TrayWall", (0.04, 1.3, 0.2), (-2.0 + sx * 0.48, -0.35, 3.07), mat=trim))
    for k in range(3):
        parts += sk.folder(f"Case{k}_", -2.0, -0.35, 3.0 + k * 0.09, folder, paper, yaw=rng.uniform(-4, 4), w=0.88, d=1.2,
                           tab=mk.flat(f"Stat_Tab{k}", (RED, srgb(40, 90, 160), srgb(220, 180, 60))[k], 0.5))
    parts += [mk.lathe("PenCup", [(0.0, 0.0), (0.13, 0.0), (0.13, 0.35), (0.11, 0.35), (0.11, 0.03), (0.0, 0.03)], (2.25, 0.25, 2.95),
                       mat=trim, segments=12)]
    for k in range(3):
        parts += sk.pen(f"CupPen{k}", (2.25 + (k - 1) * 0.04, 0.25, 3.0), (2.25 + (k - 1) * 0.12, 0.25 + (k - 1) * 0.05, 3.5), ink)
    parts.append(mk.box("Label", (0.26, 0.01, 0.1), (1.79, -1.2, 2.19), mat=label))
    return parts, glows


@prop("EvidenceBoard", pivot="centre", material="Wood", collide=False, texture=1024)
def evidence_board():
    """A detective's cork board: frame, cork, a big pinned sheet in the middle (the game writes
    the log onto it), photos around it and red string between the pins."""
    frame = dark_wood("Board_Frame")
    cork = mk.noisy("Board_Cork", srgb(120, 84, 50), srgb(160, 120, 76), scale=40, detail=10, roughness=0.95)
    paper = mk.noisy("Board_Paper", PAPER_B, PAPER_A, scale=30, roughness=0.9)
    photo = mk.noisy("Board_Photo", srgb(60, 60, 60), srgb(150, 150, 146), scale=8, detail=6, roughness=0.6)
    border = mk.flat("Board_PhotoBorder", srgb(236, 232, 222), 0.8)
    pin = mk.flat("Board_Pin", RED, 0.3)
    string = mk.flat("Board_String", srgb(170, 20, 30), 0.8)
    w, h = 12.0, 7.0
    parts = [
        mk.box("Cork", (w, 0.2, h), (0, 0.1, 0), mat=cork),
        mk.box("FrameTop", (w + 0.6, 0.45, 0.3), (0, 0, h / 2 + 0.15), mat=frame, bevel=0.05),
        mk.box("FrameBottom", (w + 0.6, 0.45, 0.3), (0, 0, -h / 2 - 0.15), mat=frame, bevel=0.05),
        mk.box("FrameLeft", (0.3, 0.45, h), (-w / 2 - 0.15, 0, 0), mat=frame, bevel=0.05),
        mk.box("FrameRight", (0.3, 0.45, h), (w / 2 + 0.15, 0, 0), mat=frame, bevel=0.05),
        mk.box("Sheet", (w * 0.66, 0.03, h * 0.74), (0, -0.02, -0.1), mat=paper),
    ]
    rng = random.Random(21)
    photo_spots = [(-5.0, 2.4), (-5.1, 0.3), (-4.9, -2.2), (5.0, 2.3), (5.1, 0.1), (4.9, -2.3), (-2.2, 3.05),
                   (2.4, 3.05)]
    pins = []
    for x, z in photo_spots:
        tilt = rng.uniform(-10, 10)
        parts.append(mk.box("PhotoBorder", (1.3, 0.03, 1.5), (x, -0.03, z), rot=(0, tilt, 0), mat=border))
        parts.append(mk.box("Photo", (1.1, 0.03, 1.1), (x, -0.05, z + 0.12), rot=(0, tilt, 0), mat=photo))
        pins.append(Vector((x, -0.12, z + 0.6)))
        parts.append(mk.sphere("Pin", 0.1, (x, -0.12, z + 0.6), mat=pin, segments=10, rings=6))
    # Red string zig-zagging between the pins.
    order = [0, 6, 3, 4, 1, 5, 2, 7, 0]
    for a, b in zip(order, order[1:]):
        parts.append(mk.tube("String", pins[a] + Vector((0, -0.02, 0)), pins[b] + Vector((0, -0.02, 0)), 0.025,
                             mat=string, verts=6))
    return parts, []


def _paper_sheet(name, mat, curl=0.08):
    """A sheet of paper with slightly curled corners (1.1 x 1.5 studs, like the game's sheets)."""
    bm = bmesh.new()
    bmesh.ops.create_grid(bm, x_segments=6, y_segments=8, size=0.5)
    for v in bm.verts:
        v.co.x *= 1.1
        v.co.y *= 1.5
        v.co.z = curl * ((abs(v.co.x) / 0.55) ** 2 + (abs(v.co.y) / 0.75) ** 3) * 0.5
    mesh = bpy.data.meshes.new(name)
    bm.to_mesh(mesh)
    bm.free()
    obj = bpy.data.objects.new(name, mesh)
    mesh.materials.append(mat)
    mk._link(obj)
    solid = obj.modifiers.new("Solidify", "SOLIDIFY")
    solid.thickness = 0.02
    return obj


@prop("PaperSheet", pivot="bottom", material="SmoothPlastic", collide=False, texture=256)
def paper_sheet():
    paper = mk.banded("Paper_Lined", srgb(214, 206, 186), srgb(236, 230, 214), frequency=24, axis="Y")
    return [_paper_sheet("Sheet", paper)], []


@prop("PaperNote", pivot="bottom", material="SmoothPlastic", collide=False, texture=256)
def paper_note():
    """A note with a few lines of ink on it."""
    paper = mk.noisy("Note_Paper", srgb(210, 200, 176), srgb(232, 224, 204), scale=30, roughness=0.9)
    ink = mk.flat("Note_Ink", srgb(20, 18, 24), 0.4)
    parts = [_paper_sheet("Note", paper, curl=0.12)]
    for i in range(5):
        width = 0.45 if i == 4 else 0.7
        parts.append(mk.box("Line", (width, 0.035, 0.008), (-0.05 - (0.7 - width) / 2, 0.45 - i * 0.2, 0.05),
                            mat=ink))
    return parts, []


def _hood_shell(name, mat):
    """A cowl: the back and sides of a sphere, open at the face, falling onto the shoulders."""
    bm = bmesh.new()
    bmesh.ops.create_uvsphere(bm, u_segments=28, v_segments=16, radius=1.0)
    faces = [f for f in bm.faces if f.calc_center_median().y < -0.15 and -0.75 < f.calc_center_median().z < 0.7]
    bmesh.ops.delete(bm, geom=faces, context="FACES")
    bmesh.ops.subdivide_edges(bm, edges=bm.edges[:], cuts=1, use_grid_fill=True)
    for v in bm.verts:
        if v.co.z < -0.2:
            spread = -0.2 - v.co.z
            v.co.x *= 1.0 + spread * 0.9
            v.co.y *= 1.0 + spread * 0.5
            v.co.z -= spread * 1.1
        if v.co.z > 0.8:
            v.co.y += (v.co.z - 0.8) * 0.8
            v.co.z += (v.co.z - 0.8) * 0.5
        # (folds of cloth falling from the crown, deeper as they fall; the hem in waves)
        a = math.atan2(v.co.y, v.co.x)
        if v.co.z < 0.4:
            k = min(1.0, (0.4 - v.co.z) / 1.4)
            v.co.x *= 1.0 + 0.05 * k * math.sin(a * 9)
            v.co.y *= 1.0 + 0.05 * k * math.sin(a * 9)
        if v.co.z < -1.0:
            v.co.z += 0.06 * math.sin(a * 5)
    loop = pk.boundary_loop(bm, lambda co: co.z > -1.3)  # (the opening's sides and brow, not across the chin)
    mesh = bpy.data.meshes.new(name)
    bm.to_mesh(mesh)
    bm.free()
    obj = bpy.data.objects.new(name, mesh)
    mesh.materials.append(mat)
    mk._link(obj)
    mk.smooth(obj)
    solid = obj.modifiers.new("Solidify", "SOLIDIFY")
    solid.thickness = 0.08
    if len(loop) > 4:
        # The face's opening edged with a thick rolled band, as one with the shell.
        band = pk.sweep(name + "Band", loop, 0.07, mat, sides=8)
        return mk.merge([obj, band], name)
    return obj


def _suit_wool():
    # (a deep charcoal, not black: in a dark room the old near-black wool read as a black box, 2026-10-27)
    return mk.noisy("Suit_Wool", srgb(42, 42, 47), srgb(58, 58, 64), roughness=0.85, kind="wool")


def _suit_satin():
    """The lapels' satin facing: a shade lighter than the wool and smooth, so it catches the light."""
    return mk.flat("Suit_Satin", srgb(64, 64, 72), 0.22, kind="plastic")


def _shirt():
    return mk.flat("Suit_Shirt", srgb(234, 232, 226), 0.7, kind="plastic")


def _proud(name, outline, out, mat, back=False):
    """A flat piece laid on a shell's front face (or its back), standing `out` proud of it: `outline` [(x, z)]."""
    y = (0.5 + out / 2 - 0.005) * (1 if back else -1)
    return mk.extrude_shape(name, outline, out + 0.01, loc=(0, y, 0), rot=(90, 0, 0), mat=mat)


# How far the shells' details stand off their base boxes, at most (CharacterService sizes each base box to its body
# part; what stands off it keeps its depth). Each shell carries as much at its back as at its front, so the box stays
# in the middle of the mesh.
JACKET_OUT = 0.045
LIMB_OUT = 0.012
# How far the shirt front stands off the jacket (Shared/Suit.SHIRT_OUT: the tie lies on it), the collar's points a
# little more, the lapels over both.
SHIRT_OUT = 0.012
COLLAR_OUT = 0.02
LAPEL_OUT = 0.03
# The base box's edges rounded this much, no more: the shell stands only a few hundredths off the body (Shared/Suit
# PAD), and a rounder edge cut the margin away, so the body's own edges showed through the cloth's.
CLOTH_BEVEL = 0.02


@prop("SuitTorso", pivot="centre", material="Fabric", collide=False, texture=256)
def suit_torso():
    """The match suit's jacket over an R6 torso, a shell the game sizes to each body (CharacterService.dressNoir): the
    notched lapels in satin, framing the white shirt front and its collar (the tie lies on the shirt: SuitTie), the
    front closing below them on two horn buttons, a welt pocket on the left breast and flapped pockets at the hips,
    the seam down the back, the collar's band rising round the neck and the jacket's hem as far below."""
    wool = _suit_wool()
    satin = _suit_satin()
    shirt = _shirt()
    horn = mk.flat("Suit_Horn", srgb(14, 13, 12), 0.3)
    seam = mk.flat("Suit_Seam", srgb(30, 30, 34), 0.9)
    parts = [mk.box("Cloth", (2.0, 1.0, 2.0), (0, 0, 0), mat=wool, bevel=CLOTH_BEVEL)]
    # the shirt front in the V between the lapels, the collar's points over it, the band round the neck
    parts.append(_proud("ShirtFront", [(-0.3, 0.995), (0.3, 0.995), (0.0, -0.22)], SHIRT_OUT, shirt))
    for sx in (-1, 1):
        point = [(sx * 0.03, 0.995), (sx * 0.29, 0.995), (sx * 0.13, 0.76)]
        parts.append(_proud("CollarPoint", point, COLLAR_OUT, shirt))
    parts.append(mk.box("CollarBand", (0.66, 0.12, 0.05), (0, -0.44, 1.02), mat=shirt, bevel=0.01))
    parts.append(mk.box("Hem", (2.0, 1.0, 0.05), (0, 0, -1.02), mat=wool, bevel=0.01))
    for sx in (-1, 1):
        lapel = [(0.27, 0.99), (0.62, 0.93), (0.5, 0.7), (0.59, 0.62), (0.07, -0.24), (0.02, -0.18)]
        parts.append(_proud("Lapel", [(sx * x, z) for x, z in lapel], LAPEL_OUT, satin))
        # the pockets: flaps at the hips, over a seam
        parts.append(_proud("HipFlap", [(sx * 0.32, -0.5), (sx * 0.8, -0.5), (sx * 0.8, -0.62), (sx * 0.32, -0.63)], 0.022,
                            wool))
    parts += [_proud("Welt", [(-0.82, 0.42), (-0.46, 0.45), (-0.46, 0.38), (-0.82, 0.35)], 0.018, wool),
              _proud("Closing", [(-0.005, -0.24), (0.025, -0.24), (0.045, -1.0), (0.015, -1.0)], 0.008, seam),
              _proud("BackSeam", [(-0.018, 1.0), (0.018, 1.0), (0.018, -1.0), (-0.018, -1.0)], JACKET_OUT, seam, back=True)]
    for z in (-0.4, -0.68):
        parts.append(mk.cylinder("Button", 0.05, JACKET_OUT + 0.01, (0.03, -0.5 - JACKET_OUT / 2 + 0.005, z),
                                 rot=(90, 0, 0), mat=horn, verts=12))
    return parts, []


@prop("SuitLimb", pivot="centre", material="Fabric", collide=False, texture=256)
def suit_limb():
    """The same cloth over an arm or a leg (the trousers' tinted a shade darker by the game): a pressed crease down its
    front and its back, a seam down each side, the hem turned at its foot (over the shirt's cuff on an arm), a few
    soft folds at the elbow or the knee."""
    wool = _suit_wool()
    seam = mk.flat("Suit_Seam", srgb(30, 30, 34), 0.9)
    parts = [mk.box("Cloth", (1.0, 1.0, 2.0), (0, 0, 0), mat=wool, bevel=CLOTH_BEVEL)]
    strip = [(-0.012, 1.0), (0.012, 1.0), (0.012, -1.0), (-0.012, -1.0)]
    parts += [_proud("Crease", strip, LIMB_OUT, wool), _proud("CreaseBack", strip, LIMB_OUT, wool, back=True)]
    for sx in (-1, 1):  # the side seams
        parts.append(mk.box("SideSeam", (LIMB_OUT + 0.01, 0.02, 2.0), (sx * (0.5 + LIMB_OUT / 2 - 0.005), 0, 0), mat=seam))
    parts.append(mk.box("Hem", (1.0 + 2 * LIMB_OUT, 1.0 + 2 * LIMB_OUT, 0.07), (0, 0, -0.965), mat=wool, bevel=0.01))
    for k, (z, tilt) in enumerate(((-0.02, 7), (-0.12, -5), (-0.2, 4))):  # the folds at the joint
        w = (0.5, 0.36, 0.44)[k]
        fold = _proud("Fold", [(-w / 2, 0.012), (w / 2, 0.012), (w / 2, -0.012), (-w / 2, -0.012)], LIMB_OUT * 0.6, wool)
        fold.location.z = z
        fold.rotation_euler.y = math.radians(tilt)
        parts.append(fold)
    return parts, []


def _clip_to(polygon, a, b, lo, hi):
    """The part of a convex polygon [(x, y)] where lo <= a * x + b * y <= hi (Sutherland-Hodgman, two half-planes)."""

    def cut(points, keep, edge):
        out = []
        for i, p in enumerate(points):
            q = points[(i + 1) % len(points)]
            p_in, q_in = keep(p), keep(q)
            if p_in:
                out.append(p)
            if p_in != q_in:
                vp, vq = a * p[0] + b * p[1], a * q[0] + b * q[1]
                k = (edge - vp) / (vq - vp)
                out.append((p[0] + (q[0] - p[0]) * k, p[1] + (q[1] - p[1]) * k))
        return out

    points = cut(polygon, lambda p: a * p[0] + b * p[1] >= lo, lo)
    return cut(points, lambda p: a * p[0] + b * p[1] <= hi, hi) if points else []


# The tie, made pale: the game dyes it in each look's colour (its surface's tint, Shared/Suit.tie), the stripes and the
# dimple's shadow staying darker than the silk round them; the clip is a piece of its own, which is never dyed.
TIE_BLADE = [(-0.075, -0.17), (0.075, -0.17), (0.14, -0.92), (0.0, -1.04), (-0.14, -0.92)]
TIE_TILT = 87  # (the blade stands off the shirt toward its tip, the knot holding its top close)
TIE_BLADE_DEPTH = 0.03
TIE_CLIP_Z = -0.62


@prop("SuitTie", pivot="centre", material="Fabric", collide=False, texture=256)
def suit_tie():
    """The match suit's tie, dressed on the shirt front (Shared/Suit.tie): a full Windsor knot, broad and triangular,
    the dimple pinched under it, the blade a little raised off the shirt and tapering to its point, fine diagonal
    stripes woven darker in the satin; a thin silver clip across the blade."""
    silk = mk.flat("Tie_Satin", srgb(238, 236, 236), 0.28, kind="plastic")
    stripe = mk.flat("Tie_Stripe", srgb(150, 148, 150), 0.32, kind="plastic")
    shade = mk.flat("Tie_Dimple", srgb(112, 110, 112), 0.5, kind="plastic")
    steel = mk.flat("Clip_Steel", srgb(204, 206, 212), 0.22, metallic=0.9)
    knot = mk.extrude_shape("Knot", [(-0.13, 0.0), (0.13, 0.0), (0.075, -0.19), (-0.075, -0.19)], 0.1,
                            loc=(0, -0.05, 0), rot=(90, 0, 0), mat=silk, bevel=0.025)
    parts = [knot, mk.extrude_shape("Blade", TIE_BLADE, TIE_BLADE_DEPTH, loc=(0, -0.035, 0), rot=(TIE_TILT, 0, 0),
                                    mat=silk, bevel=0.008)]
    # the dimple: a soft crease pinched into the blade just under the knot
    parts.append(mk.extrude_shape("Dimple", [(-0.02, -0.18), (0.02, -0.18), (0.0, -0.34)], TIE_BLADE_DEPTH + 0.006,
                                  loc=(0, -0.035, 0), rot=(TIE_TILT, 0, 0), mat=shade))
    # the stripes, rising to the right, cut to the blade's outline
    for k in range(-6, 7):
        lo = -0.9 + k * 0.15
        band = _clip_to(TIE_BLADE, 1.0, 1.0, lo, lo + 0.035)
        # (none through the dimple, none so small it is a speck)
        if len(band) >= 3 and max(y for _, y in band) < -0.36:
            parts.append(mk.extrude_shape("Stripe", band, TIE_BLADE_DEPTH + 0.004, loc=(0, -0.035, 0),
                                          rot=(TIE_TILT, 0, 0), mat=stripe))
    # the clip across the blade's front, two thirds of the way down
    lean = math.cos(math.radians(TIE_TILT)) * TIE_CLIP_Z  # (how far forward the tilted blade has come there)
    front = -0.035 + lean - TIE_BLADE_DEPTH / 2
    clip = mk.box("Clip", (0.3, 0.02, 0.035), (0, front - 0.012, TIE_CLIP_Z), mat=steel, bevel=0.008)
    more = {"into": (0.0, 0.0, 0.82, 1.0), "pieces": {"Clip": props.piece([clip], into=(0.84, 0.0, 1.0, 0.4))}}
    return parts, [], more


@prop("Hood", pivot="centre", material="Fabric", collide=False, texture=512)
def hood():
    """The hood worn over the head (the game scales it to each head)."""
    cloth = mk.noisy("Hood_Cloth", srgb(22, 20, 26), srgb(44, 40, 50), scale=10, detail=12, roughness=0.95)
    shell = _hood_shell("Shell", cloth)
    shell.scale = (0.78, 0.8, 0.72)
    return [shell], []

